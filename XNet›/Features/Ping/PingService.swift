//
//  PingService.swift
//  XNet›
//

import Foundation
import Darwin

class PingService {
    
    // ICMP structure for manual packet construction
    struct ICMPHeader {
        var type: UInt8
        var code: UInt8
        var checksum: UInt16
        var identifier: UInt16
        var sequence: UInt16
    }
    
    func ping(host: String) -> AsyncStream<PingResult> {
        let address = self.resolve(host: host)
        let cancelFlag = CancelFlag()
        
        return AsyncStream { continuation in
            guard let resolvedAddress = address else {
                continuation.finish()
                return
            }
            
            let sockID = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
            if sockID < 0 {
                continuation.finish()
                return
            }
            
            // Garantir que o socket seja vinculado a uma porta local. 
            // No macOS SOCK_DGRAM, essa porta == Identificador ICMP.
            var localAddr = sockaddr_in()
            localAddr.sin_family = sa_family_t(AF_INET)
            localAddr.sin_addr.s_addr = INADDR_ANY.bigEndian
            localAddr.sin_port = 0
            
            let bindRes = withUnsafePointer(to: &localAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.bind(sockID, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            
            if bindRes < 0 {
                Darwin.close(sockID)
                continuation.finish()
                return
            }
            
            // Descobrir qual porta o Kernel nos deu
            var nameAddr = sockaddr_in()
            var nameLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            _ = withUnsafeMutablePointer(to: &nameAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.getsockname(sockID, $0, &nameLen)
                }
            }
            let identifier = nameAddr.sin_port // Já está em BigEndian do Kernel
            
            // Timeout de recebimento
            var timeoutValue = timeval(tv_sec: 2, tv_usec: 0)
            Darwin.setsockopt(sockID, SOL_SOCKET, SO_RCVTIMEO, &timeoutValue, socklen_t(MemoryLayout<timeval>.size))
            
            let queue = DispatchQueue(label: "com.xnet.ping", qos: .utility)
            queue.async {
                var sequence: UInt16 = 0
                while !cancelFlag.isCancelled {
                    let startTime = CFAbsoluteTimeGetCurrent()
                    sequence += 1
                    
                    let header = ICMPHeader(
                        type: 8, code: 0, checksum: 0,
                        identifier: identifier,
                        sequence: sequence.bigEndian
                    )
                    
                    let payloadData = "XNet-v2-Stabilized-Ping-Payload-Data-64B".data(using: .utf8)!
                    let packetSize = MemoryLayout<ICMPHeader>.size + payloadData.count
                    var packet = Data(count: packetSize)
                    packet.withUnsafeMutableBytes { bytes in
                        if let headerPointer = bytes.bindMemory(to: ICMPHeader.self).baseAddress {
                            headerPointer.pointee = header
                        }
                    }
                    packet.replaceSubrange(MemoryLayout<ICMPHeader>.size..<packetSize, with: payloadData)
                    
                    // CÁLCULO DE CHECKSUM MANUAL (Exigido em algumas versões do macOS para SOCK_DGRAM)
                    let cksum = PingService.calculateChecksum(data: packet)
                    packet.withUnsafeMutableBytes { bytes in
                        if let headerPointer = bytes.bindMemory(to: ICMPHeader.self).baseAddress {
                            headerPointer.pointee.checksum = cksum
                        }
                    }
                    
                    var destAddr = sockaddr_in()
                    destAddr.sin_family = sa_family_t(AF_INET)
                    destAddr.sin_addr.s_addr = resolvedAddress
                    destAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                    
                    let sentRes = withUnsafePointer(to: &destAddr) { ptr in
                        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                            packet.withUnsafeBytes { pktPtr in
                                Darwin.sendto(sockID, pktPtr.baseAddress, packet.count, 0, saPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                            }
                        }
                    }
                    
                    if sentRes >= 0 {
                        var buffer = [UInt8](repeating: 0, count: 512)
                        var fromAddr = sockaddr()
                        var fromLen = socklen_t(MemoryLayout<sockaddr>.size)
                        let recvSize = Darwin.recvfrom(sockID, &buffer, buffer.count, 0, &fromAddr, &fromLen)
                        
                        if recvSize >= 8 {
                            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                            
                            // Tentar encontrar o Header ICMP (pode estar no offset 0 ou 20 se o IP Header vier junto)
                            var icmpOffset = 0
                            if recvSize >= 28 && (buffer[0] & 0xF0) == 0x40 { // IPv4 detected
                                icmpOffset = Int((buffer[0] & 0x0F) * 4)
                            }
                            
                            if recvSize >= icmpOffset + 8 {
                                let type = buffer[icmpOffset]
                                // LEITURA MANUAL BIG-ENDIAN (Crucial para Apple Silicon)
                                let respIdent = UInt16(buffer[icmpOffset + 4]) << 8 | UInt16(buffer[icmpOffset + 5])
                                
                                // No macOS, o identifier retornado deve bater com o que enviamos (Porta)
                                if type == 0 && respIdent == identifier.bigEndian {
                                    continuation.yield(PingResult(
                                        sequence: Int(sequence),
                                        ip: host,
                                        bytes: recvSize,
                                        ttl: 64,
                                        time: duration
                                    ))
                                } else {
                                    continuation.yield(PingResult(sequence: Int(sequence), ip: "Request Timed Out", bytes: 0, ttl: 0, time: 0))
                                }
                            }
                        } else {
                            continuation.yield(PingResult(sequence: Int(sequence), ip: "Request Timed Out", bytes: 0, ttl: 0, time: 0))
                        }
                    } else {
                        continuation.yield(PingResult(sequence: Int(sequence), ip: "Send Error", bytes: 0, ttl: 0, time: 0))
                    }
                    
                    if cancelFlag.isCancelled { break }
                    Thread.sleep(forTimeInterval: 1.0)
                }
                Darwin.close(sockID)
                continuation.finish()
            }
            
            continuation.onTermination = { @Sendable _ in
                cancelFlag.isCancelled = true
            }
        }
    }
    
    private func resolve(host: String) -> in_addr_t? {
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_DGRAM
        
        var res: UnsafeMutablePointer<addrinfo>?
        if getaddrinfo(host, nil, &hints, &res) == 0, let info = res {
            defer { freeaddrinfo(info) }
            guard let aiAddr = info.pointee.ai_addr else { return nil }
            let addr = aiAddr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr }
            return addr
        }
        return nil
    }
    
    private static func calculateChecksum(data: Data) -> UInt16 {
        let count = data.count
        var checksum: UInt32 = 0
        var i = 0
        
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            guard let ptr = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            
            while i < count - 1 {
                // Combina dois bytes em um UInt16 (Network Byte Order não importa na soma se dobrarmos no final)
                let word = UInt32(ptr[i]) << 8 | UInt32(ptr[i+1])
                checksum += word
                i += 2
            }
            
            if i == count - 1 {
                // Último byte residual
                checksum += UInt32(ptr[i]) << 8
            }
        }
        
        while (checksum >> 16) != 0 {
            checksum = (checksum & 0xFFFF) + (checksum >> 16)
        }
        
        return UInt16(truncatingIfNeeded: ~checksum).bigEndian
    }
}
