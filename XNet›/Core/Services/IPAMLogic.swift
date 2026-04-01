import Foundation

struct IPAddressRange {
    let start: UInt32
    let end: UInt32
    let mask: UInt32
    
    static func from(cidr: String) -> IPAddressRange? {
        let parts = cidr.split(separator: "/")
        guard parts.count == 2, let maskBits = Int(parts[1]), maskBits >= 0, maskBits <= 32 else { return nil }
        
        let ipParts = parts[0].split(separator: ".")
        guard ipParts.count == 4 else { return nil }
        
        var ipInt: UInt32 = 0
        for part in ipParts {
            guard let val = UInt32(part), val <= 255 else { return nil }
            ipInt = (ipInt << 8) | val
        }
        
        // Use UInt32 explicitly for bitwise operations
        let fullMask: UInt32 = 0xFFFFFFFF
        let maskValue: UInt32 = maskBits == 0 ? 0 : (fullMask << (32 - maskBits))
        
        let network = ipInt & maskValue
        let broadcast = network | (~maskValue)
        
        return IPAddressRange(start: network, end: broadcast, mask: maskValue)
    }
    
    func overlaps(with other: IPAddressRange) -> Bool {
        return self.start <= other.end && other.start <= self.end
    }
}

struct IPAMCalculator {
    static func getNetworkInfo(cidr: String) -> [String: String] {
        guard let range = IPAddressRange.from(cidr: cidr) else { return [:] }
        
        return [
            "Network": intToIp(range.start),
            "Broadcast": intToIp(range.end),
            "Gateway": intToIp(range.start + 1),
            "Mask": intToIp(range.mask),
            "Hosts": "\(UInt64(range.end) - UInt64(range.start) + 1)"
        ]
    }
    
    private static func intToIp(_ value: UInt32) -> String {
        return "\( (value >> 24) & 0xFF ).\( (value >> 16) & 0xFF ).\( (value >> 8) & 0xFF ).\( value & 0xFF )"
    }
}
