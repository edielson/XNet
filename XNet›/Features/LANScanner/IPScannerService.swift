import Foundation
import Network
import Darwin

class IPScannerService {
    struct ICMPHeader {
        var type: UInt8
        var code: UInt8
        var checksum: UInt16
        var identifier: UInt16
        var sequence: UInt16
    }
    
    func scan(subnet: String) -> AsyncStream<ScannedDevice> {
        let targets = IPScannerService.parseInput(subnet)
        
        return AsyncStream { continuation in
            let sockID = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
            if sockID < 0 {
                continuation.finish()
                return
            }
            
            var localAddr = sockaddr_in()
            localAddr.sin_family = sa_family_t(AF_INET)
            localAddr.sin_addr.s_addr = INADDR_ANY.bigEndian
            localAddr.sin_port = 0
            
            _ = withUnsafePointer(to: &localAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.bind(sockID, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            
            var nameAddr = sockaddr_in()
            var nameLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            _ = withUnsafeMutablePointer(to: &nameAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.getsockname(sockID, $0, &nameLen)
                }
            }
            let identifier = nameAddr.sin_port
            
            var rcvBuf: Int32 = 1024 * 1024 // 1MB Buffer
            Darwin.setsockopt(sockID, SOL_SOCKET, SO_RCVBUF, &rcvBuf, socklen_t(MemoryLayout<Int32>.size))
            
            // Usamos timeout curto no receptor
            var timeout = timeval(tv_sec: 0, tv_usec: 10000)
            Darwin.setsockopt(sockID, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            
            let cancelFlag = CancelFlag()
            
            let listenQueue = DispatchQueue(label: "com.xnet.scanner.listen", qos: .userInteractive)
            listenQueue.async {
                var buffer = [UInt8](repeating: 0, count: 1024)
                var scannedIPs = Set<String>()
                scannedIPs.reserveCapacity(256)
                
                while !cancelFlag.isCancelled {
                    var fromAddr = sockaddr_in()
                    var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                    
                    let recvSize = withUnsafeMutablePointer(to: &fromAddr) { ptr in
                        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                            Darwin.recvfrom(sockID, &buffer, buffer.count, 0, saPtr, &fromLen)
                        }
                    }
                    
                    guard recvSize >= 8 else { continue }
                    
                    var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    inet_ntop(AF_INET, &fromAddr.sin_addr, &ipBuffer, socklen_t(INET_ADDRSTRLEN))
                    let responseIP = String(cString: ipBuffer)
                    
                    if scannedIPs.contains(responseIP) { continue }
                    
                    var icmpOffset = 0
                    if (buffer[0] & 0xF0) == 0x40 { icmpOffset = Int((buffer[0] & 0x0F) * 4) }
                    
                    if recvSize >= icmpOffset + 8 {
                        let type = buffer[icmpOffset]
                        let respIdent = UInt16(buffer[icmpOffset + 4]) << 8 | UInt16(buffer[icmpOffset + 5])
                        
                        if type == 0 && respIdent == identifier.bigEndian {
                            scannedIPs.insert(responseIP)
                            
                            // DISPATCH ASSÍNCRONO PARA NÃO TRAVAR O SOCKET!
                            Task {
                                let mac = IPScannerService.getMACAddress(for: responseIP)
                                let vendor = await MACVendorService.shared.lookup(mac: mac)
                                continuation.yield(ScannedDevice(ip: responseIP, mac: mac, hostname: "Unknown", vendor: vendor))
                            }
                        }
                    } 
                }
            }
            
            Task.detached {
                // Fazer disparo dos pings UDP encapsulados em ICMP
                for (index, target) in targets.enumerated() {
                    if cancelFlag.isCancelled { break }
                    
                    var destAddr = sockaddr_in()
                    destAddr.sin_family = sa_family_t(AF_INET)
                    destAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                    inet_pton(AF_INET, target, &destAddr.sin_addr)
                    
                    var header = ICMPHeader(
                        type: 8, code: 0, checksum: 0,
                        identifier: identifier, 
                        sequence: UInt16(index + 1).bigEndian
                    )
                    
                    let payloadData = "XNet-V3-Engine".data(using: .utf8)!
                    var packet = Data(count: MemoryLayout<ICMPHeader>.size + payloadData.count)
                    packet.withUnsafeMutableBytes { bytes in
                        bytes.bindMemory(to: ICMPHeader.self).baseAddress!.pointee = header
                    }
                    packet.replaceSubrange(MemoryLayout<ICMPHeader>.size..<packet.count, with: payloadData)
                    
                    let cksum = IPScannerService.calculateChecksum(data: packet)
                    packet.withUnsafeMutableBytes { bytes in
                        bytes.bindMemory(to: ICMPHeader.self).baseAddress!.pointee.checksum = cksum
                    }
                    
                    _ = withUnsafePointer(to: &destAddr) { ptr in
                        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                            packet.withUnsafeBytes { pktPtr in
                                Darwin.sendto(sockID, pktPtr.baseAddress, packet.count, 0, saPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                            }
                        }
                    }
                    
                    try? await Task.sleep(nanoseconds: 2_000_000) // 2ms para aliviar buffer kernel
                }
                
                try? await Task.sleep(nanoseconds: 2_500_000_000) // Espera 2.5s para os atrasados
                
                cancelFlag.isCancelled = true
                Darwin.close(sockID)
                continuation.finish()
            }
            
            continuation.onTermination = { @Sendable _ in
                cancelFlag.isCancelled = true
                Darwin.close(sockID)
            }
        }
    }
    
    nonisolated private static func calculateChecksum(data: Data) -> UInt16 {
        let count = data.count
        var checksum: UInt32 = 0
        var i = 0
        
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            guard let ptr = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            
            while i < count - 1 {
                let word = UInt32(ptr[i]) << 8 | UInt32(ptr[i+1])
                checksum += word
                i += 2
            }
            
            if i == count - 1 {
                checksum += UInt32(ptr[i]) << 8
            }
        }
        
        while (checksum >> 16) != 0 {
            checksum = (checksum & 0xFFFF) + (checksum >> 16)
        }
        
        return UInt16(truncatingIfNeeded: ~checksum).bigEndian
    }
    
    nonisolated private static func getMACAddress(for ip: String) -> String {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_LLINFO]
        var len: Int = 0
        if sysctl(&mib, UInt32(mib.count), nil, &len, nil, 0) < 0 { return "N/A" }
        if len <= 0 { return "N/A" }
        
        var buffer = [UInt8](repeating: 0, count: len)
        if sysctl(&mib, UInt32(mib.count), &buffer, &len, nil, 0) < 0 { return "N/A" }
        
        var offset = 0
        while offset < len {
            let msgPointer = buffer.withUnsafeBytes { $0.baseAddress!.advanced(by: offset) }
            let rtm = msgPointer.assumingMemoryBound(to: rt_msghdr.self).pointee
            
            if offset + Int(rtm.rtm_msglen) > len { break }
            
            let rtmSize = MemoryLayout<rt_msghdr>.size
            let sinPointer = msgPointer.advanced(by: rtmSize).assumingMemoryBound(to: sockaddr_in.self)
            
            var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            var sin_addr = sinPointer.pointee.sin_addr
            inet_ntop(AF_INET, &sin_addr, &ipBuffer, socklen_t(INET_ADDRSTRLEN))
            let dstIP = String(cString: ipBuffer)
            
            if dstIP == ip {
                // O sockaddr_dl (link address) vem logo após o sockaddr_in
                var sinLen = Int(sinPointer.pointee.sin_len)
                // Alinhamento de memória (tipicamente 4 ou 8 bytes no Darwin)
                sinLen = (sinLen > 0) ? ((sinLen - 1) / 4 + 1) * 4 : 4
                
                let sdlPointer = msgPointer.advanced(by: rtmSize + sinLen).assumingMemoryBound(to: sockaddr_dl.self)
                let sdl = sdlPointer.pointee
                
                if sdl.sdl_family == UInt8(AF_LINK) && sdl.sdl_alen > 0 {
                    let macPtr = sdlPointer.withMemoryRebound(to: UInt8.self, capacity: 1) { ptr -> UnsafePointer<UInt8> in
                        return ptr.advanced(by: MemoryLayout<sockaddr_dl>.offset(of: \sockaddr_dl.sdl_data)! + Int(sdl.sdl_nlen))
                    }
                    
                    let macChars = (0..<Int(sdl.sdl_alen)).map { String(format: "%02X", macPtr[$0]) }
                    return macChars.joined(separator: ":")
                }
            }
            offset += Int(rtm.rtm_msglen)
        }
        return "N/A"
    }

    
    nonisolated private static func getHostname(for ip: String) -> String {
        return "Unknown"
    }
    
    
    nonisolated static func parseInput(_ input: String) -> [String] {
        var targets: [String] = []
        let parts = input.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        for var part in parts {
            if part.isEmpty { continue }
            
            let dotCount = part.filter { $0 == "." }.count
            if dotCount == 2 && !part.contains("/") && !part.contains("-") {
                part = "\(part).0/24"
            }
            
            if part.contains("/") {
                let cidrParts = part.components(separatedBy: "/")
                if cidrParts.count == 2 {
                    var baseIP = cidrParts[0]
                    if baseIP.filter({ $0 == "." }).count == 2 { baseIP += ".0" }
                    targets.append(contentsOf: parseCIDR("\(baseIP)/\(cidrParts[1])"))
                }
            } else if part.contains("-") {
                targets.append(contentsOf: parseRange(part))
            } else {
                targets.append(part)
            }
        }
        return targets
    }
    
    nonisolated private static func parseCIDR(_ cidr: String) -> [String] {
        let parts = cidr.components(separatedBy: "/")
        guard parts.count == 2, let maskBits = Int(parts[1]), maskBits >= 0, maskBits <= 32 else { return [] }
        guard let baseInt = ipToUint32(parts[0]) else { return [] }
        
        let mask: UInt32 = maskBits == 0 ? 0 : (0xFFFFFFFF << (32 - maskBits))
        let start = baseInt & mask
        let end = baseInt | ~mask
        
        var ips: [String] = []
        var current = start
        while true {
            ips.append(uint32ToIP(current))
            if ips.count >= 1024 || current >= end { break }
            current += 1
        }
        return ips
    }
    
    nonisolated private static func parseRange(_ range: String) -> [String] {
        let parts = range.components(separatedBy: "-")
        guard parts.count == 2, let startInt = ipToUint32(parts[0]), let endInt = ipToUint32(parts[1]) else { return [] }
        
        var ips: [String] = []
        var current = startInt
        while true {
            ips.append(uint32ToIP(current))
            if ips.count >= 1024 || current >= endInt { break }
            current += 1
        }
        return ips
    }
    
    nonisolated private static func ipToUint32(_ ip: String) -> UInt32? {
        var addr = in_addr()
        if inet_pton(AF_INET, ip, &addr) == 1 {
            return UInt32(bigEndian: addr.s_addr)
        }
        return nil
    }
    
    nonisolated private static func uint32ToIP(_ val: UInt32) -> String {
        var addr = in_addr(s_addr: val.bigEndian)
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &addr, &buffer, socklen_t(INET_ADDRSTRLEN))
        return String(cString: buffer)
    }
}
