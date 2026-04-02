//
//  TracerouteService.swift
//  XNet›
//

import Foundation
import Darwin

class TracerouteService {
    
    struct ICMPHeader {
        var type: UInt8
        var code: UInt8
        var checksum: UInt16
        var identifier: UInt16
        var sequence: UInt16
    }
    
    func trace(host: String) -> AsyncStream<TracerouteHop> {
        let address = self.getIPv4Address(host)
        
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
            
            // Bind the socket to port 0 to get an assigned ICMP identifier (mandatory for macOS)
            var localAddr = sockaddr_in()
            localAddr.sin_family = sa_family_t(AF_INET)
            localAddr.sin_port = 0
            localAddr.sin_addr.s_addr = INADDR_ANY
            
            _ = withUnsafePointer(to: &localAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.bind(sockID, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            
            var boundAddr = sockaddr_in()
            var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            _ = withUnsafeMutablePointer(to: &boundAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.getsockname(sockID, $0, &addrLen)
                }
            }
            let identifier = UInt16(bigEndian: boundAddr.sin_port)
            
            let task = Task {
                for ttl in 1...30 {
                    if Task.isCancelled { break }
                    
                    var currentTTL: Int32 = Int32(ttl)
                    Darwin.setsockopt(sockID, IPPROTO_IP, IP_TTL, &currentTTL, socklen_t(MemoryLayout<Int32>.size))
                    
                    var times: [String] = []
                    var hopIP = "*"
                    
                    for _ in 1...3 {
                        if Task.isCancelled { break }
                        let startTime = Date()
                        
                        var header = ICMPHeader(
                            type: 8,
                            code: 0,
                            checksum: 0,
                            identifier: identifier.bigEndian,
                            sequence: UInt16(ttl).bigEndian
                        )
                        
                        var packet = Data(count: MemoryLayout<ICMPHeader>.size)
                        packet.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) in
                            bytes.bindMemory(to: ICMPHeader.self).baseAddress!.pointee = header
                        }
                        
                        let cksum = TracerouteService.calculateChecksum(data: packet)
                        packet.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) in
                            bytes.bindMemory(to: ICMPHeader.self).baseAddress!.pointee.checksum = cksum.bigEndian
                        }
                        
                        var addr = sockaddr_in()
                        addr.sin_family = sa_family_t(AF_INET)
                        addr.sin_addr.s_addr = resolvedAddress
                        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                        
                        let sent = withUnsafePointer(to: &addr) {
                            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                                Darwin.sendto(sockID, (packet as Data).withUnsafeBytes { $0.baseAddress! }, packet.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                            }
                        }
                        
                        if sent >= 0 {
                            var buffer = [UInt8](repeating: 0, count: 1024)
                            var fromAddr = sockaddr_in()
                            var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                            var tv = timeval(tv_sec: 1, tv_usec: 500000) // 1.5s timeout
                            Darwin.setsockopt(sockID, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
                            
                            let res = withUnsafeMutablePointer(to: &fromAddr) { ptr -> Int in
                                return ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                                    Darwin.recvfrom(sockID, &buffer, buffer.count, 0, $0, &fromLen)
                                }
                            }
                            
                            if res >= 0 {
                                let duration = Date().timeIntervalSince(startTime) * 1000
                                times.append(String(format: "%.2fms", duration))
                                
                                var hostBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                                var sinAddr = fromAddr.sin_addr
                                inet_ntop(AF_INET, &sinAddr, &hostBuf, socklen_t(INET_ADDRSTRLEN))
                                hopIP = String(cString: hostBuf)
                            } else {
                                times.append("*")
                            }
                        } else {
                            times.append("*")
                        }
                        
                        // Pequeno delay entre tentativas de um mesmo hop
                        try? await Task.sleep(nanoseconds: 50_000_000)
                    }
                    
                    continuation.yield(TracerouteHop(
                        id: ttl,
                        host: hopIP == "*" ? "???" : hopIP,
                        ip: hopIP,
                        time1: times.count > 0 ? times[0] : "*",
                        time2: times.count > 1 ? times[1] : "*",
                        time3: times.count > 2 ? times[2] : "*"
                    ))
                    
                    if hopIP != "*" && hopIP == hostIPString(resolvedAddress) { break }
                }
                Darwin.close(sockID)
                continuation.finish()
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
                Darwin.close(sockID)
            }
        }
    }
    
    private func hostIPString(_ addr: in_addr_t) -> String {
        var a = addr
        var hostBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &a, &hostBuf, socklen_t(INET_ADDRSTRLEN))
        return String(cString: hostBuf)
    }
    
    private func getIPv4Address(_ host: String) -> in_addr_t? {
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_DGRAM
        
        var res: UnsafeMutablePointer<addrinfo>?
        if getaddrinfo(host, nil, &hints, &res) == 0, let firstAddr = res?.pointee.ai_addr {
            let addrIn = firstAddr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
            freeaddrinfo(res)
            return addrIn.sin_addr.s_addr
        }
        return nil
    }
    
    private static func calculateChecksum(data: Data) -> UInt16 {
        let count = data.count
        var checksum: UInt32 = 0
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            let ptr = bytes.bindMemory(to: UInt16.self)
            for i in 0..<count/2 {
                checksum += UInt32(ptr[i])
            }
            if count % 2 == 1 {
                checksum += UInt32(data[count - 1])
            }
        }
        while (checksum >> 16) != 0 {
            checksum = (checksum & 0xFFFF) + (checksum >> 16)
        }
        return UInt16(truncatingIfNeeded: ~checksum)
    }
}
