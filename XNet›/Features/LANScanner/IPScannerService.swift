import Foundation
import Network
import Darwin

class IPScannerService {
    private class CancelFlag {
        var isCancelled = false
    }

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
            let queue = DispatchQueue(label: "com.xnet.scan", qos: .utility, attributes: .concurrent)
            let semaphore = DispatchSemaphore(value: 50)
            let group = DispatchGroup()
            let stopSignal = CancelFlag()
            
            Task.detached {
                for target in targets {
                    if stopSignal.isCancelled { break }
                    
                    semaphore.wait()
                    group.enter()
                    
                    Task {
                        defer {
                            group.leave()
                            semaphore.signal()
                        }
                        
                        if let sockID = IPScannerService.createSocket() {
                            defer { Darwin.close(sockID) }
                            if IPScannerService.pingOnceSync(ip: target, socket: sockID) {
                                let mac = IPScannerService.getMACAddress(for: target)
                                let vendor = mac == "N/A" ? "N/A" : await MACVendorService.lookupExtended(mac: mac)
                                continuation.yield(ScannedDevice(ip: target, mac: mac, hostname: "Unknown", vendor: vendor))
                            }
                        }
                    }
                }
                
                group.wait()
                continuation.finish()
            }
            
            continuation.onTermination = { @Sendable _ in
                stopSignal.isCancelled = true
            }
        }
    }
    
    private static func createSocket() -> Int32? {
        let sockID = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        if sockID < 0 { return nil }
        
        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        Darwin.setsockopt(sockID, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        return sockID
    }
    
    private static func pingOnceSync(ip: String, socket: Int32) -> Bool {
        var header = ICMPHeader(
            type: 8, code: 0, checksum: 0, 
            identifier: UInt16.random(in: 0...65535).bigEndian, 
            sequence: UInt16(1).bigEndian
        )
        
        let payload = "PingPayload32BytesStandardCheck!".data(using: .utf8)!
        var packet = Data(bytes: &header, count: MemoryLayout<ICMPHeader>.size)
        packet.append(payload)
        
        header.checksum = calculateChecksum(data: packet).bigEndian
        packet.replaceSubrange(0..<MemoryLayout<ICMPHeader>.size, with: Data(bytes: &header, count: MemoryLayout<ICMPHeader>.size))
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        inet_pton(AF_INET, ip, &addr.sin_addr)
        
        let sent = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.sendto(socket, (packet as NSData).bytes, packet.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        if sent < 0 { return false }
        
        var buffer = [UInt8](repeating: 0, count: 1024)
        let received = Darwin.recv(socket, &buffer, buffer.count, 0)
        
        if received >= 8 {
            // 1. Caso comum do macOS (SOCK_DGRAM): ICMP direto no início buffer[0]
            if buffer[0] == 0 && buffer[1] == 0 {
                return true
            }
            
            // 2. Caso com IP Header presente (20 bytes de offset)
            if received >= 28 && buffer[20] == 0 && buffer[21] == 0 {
                return true
            }
        }
        return false
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
    
    private static func getMACAddress(for ip: String) -> String {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_LLINFO]
        var len: Int = 0
        if sysctl(&mib, UInt32(mib.count), nil, &len, nil, 0) < 0 { return "N/A" }
        
        var data = Data(count: len)
        if data.withUnsafeMutableBytes({ sysctl(&mib, UInt32(mib.count), $0.baseAddress, &len, nil, 0) }) < 0 {
            return "N/A"
        }
        
        var offset = 0
        while offset < data.count {
            let hdr = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: rt_msghdr.self) }
            let rt_m_size = Int(hdr.rtm_msglen)
            
            // Advance offset manually based on rtm_msglen
            let messageEnd = offset + rt_m_size
            
            // Find sockaddrs after rt_msghdr
            // The addresses follow immediately after the rt_msghdr
            // Struct is: [rt_msghdr][sockaddr_in (dst)][sockaddr_dl (gate)]...
            
            var currentPos = offset + MemoryLayout<rt_msghdr>.size
            
            // First is RTA_DST (Destination IP)
            let dst_sin = data.withUnsafeBytes { $0.load(fromByteOffset: currentPos, as: sockaddr_in.self) }
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            var sin_addr = dst_sin.sin_addr
            inet_ntop(AF_INET, &sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN))
            let dstIP = String(cString: buffer)
            
            if dstIP == ip {
                // Second is RTA_GATEWAY (Should be sockaddr_dl for local ARP entries)
                // We need to skip the first sockaddr (destination ip)
                // Sizes are aligned. sockaddr_in is typically 16 bytes.
                let sin_size = Int(dst_sin.sin_len)
                currentPos += (sin_size > 0 ? ((sin_size - 1) / 4 + 1) * 4 : 4) // word alignment
                
                let gateway_sdl = data.withUnsafeBytes { $0.load(fromByteOffset: currentPos, as: sockaddr_dl.self) }
                if gateway_sdl.sdl_family == UInt8(AF_LINK) && gateway_sdl.sdl_alen > 0 {
                    let macPtr = data.withUnsafeBytes { bytes -> UnsafePointer<UInt8> in
                        let sdlPtr = bytes.baseAddress!.advanced(by: currentPos).assumingMemoryBound(to: sockaddr_dl.self)
                        // MAC data starts at sdl_data + sdl_nlen
                        let dataPtr = UnsafeRawPointer(sdlPtr).advanced(by: MemoryLayout<sockaddr_dl>.offset(of: \sockaddr_dl.sdl_data)!)
                        return dataPtr.advanced(by: Int(gateway_sdl.sdl_nlen)).assumingMemoryBound(to: UInt8.self)
                    }
                    
                    let macChars = (0..<Int(gateway_sdl.sdl_alen)).map { String(format: "%02X", macPtr[$0]) }
                    return macChars.joined(separator: ":")
                }
            }
            
            offset = messageEnd
        }
        
        return "N/A"
    }
    
    private static func getHostname(for ip: String) -> String {
        return "Unknown"
    }
    
    
    private static func parseInput(_ input: String) -> [String] {
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
    
    private static func parseCIDR(_ cidr: String) -> [String] {
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
    
    private static func parseRange(_ range: String) -> [String] {
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
    
    private static func ipToUint32(_ ip: String) -> UInt32? {
        var addr = in_addr()
        if inet_pton(AF_INET, ip, &addr) == 1 {
            return UInt32(bigEndian: addr.s_addr)
        }
        return nil
    }
    
    private static func uint32ToIP(_ val: UInt32) -> String {
        var addr = in_addr(s_addr: val.bigEndian)
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &addr, &buffer, socklen_t(INET_ADDRSTRLEN))
        return String(cString: buffer)
    }
}
