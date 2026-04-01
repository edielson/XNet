//
//  SubnetCalculatorService.swift
//  XNet›
//

import Foundation

struct SubnetInfo: Sendable {
    let address: String
    let mask: String
    let cidr: Int
    let networkAddress: String
    let broadcastAddress: String
    let firstUsable: String
    let lastUsable: String
    let totalUsable: UInt32
    let wildcard: String
    let binaryAddress: [String]
    let binaryMask: [String]
}

class SubnetCalculatorService {
    
    func calculate(address: String, cidr: Int) -> SubnetInfo? {
        let cleanAddr = address.trimmingCharacters(in: .whitespaces)
        guard let ipUInt = ipToUInt32(cleanAddr) else { return nil }
        
        // Prefix boundary check
        let prefix = max(0, min(32, cidr))
        
        // Calculate Mask
        let maskUInt: UInt32 = prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix))
        
        // Network and Broadcast
        let networkUInt = ipUInt & maskUInt
        let broadcastUInt = networkUInt | (~maskUInt)
        
        // Results
        let networkAddr = uint32ToIp(networkUInt)
        let broadcastAddr = uint32ToIp(broadcastUInt)
        let maskAddr = uint32ToIp(maskUInt)
        let wildcardAddr = uint32ToIp(~maskUInt)
        
        // Usable Range
        var firstUsable = ""
        var lastUsable = ""
        var totalUsable: UInt32 = 0
        
        if prefix <= 30 {
            firstUsable = uint32ToIp(networkUInt + 1)
            lastUsable = uint32ToIp(broadcastUInt - 1)
            totalUsable = (broadcastUInt - networkUInt) - 1
        } else if prefix == 31 {
            // p2p
            firstUsable = uint32ToIp(networkUInt)
            lastUsable = uint32ToIp(broadcastUInt)
            totalUsable = 2
        } else {
            // /32 host
            firstUsable = uint32ToIp(networkUInt)
            lastUsable = uint32ToIp(broadcastUInt)
            totalUsable = 1
        }
        
        return SubnetInfo(
            address: cleanAddr,
            mask: maskAddr,
            cidr: prefix,
            networkAddress: networkAddr,
            broadcastAddress: broadcastAddr,
            firstUsable: firstUsable,
            lastUsable: lastUsable,
            totalUsable: totalUsable,
            wildcard: wildcardAddr,
            binaryAddress: toBinaryOctets(ipUInt),
            binaryMask: toBinaryOctets(maskUInt)
        )
    }
    
    private func ipToUInt32(_ ip: String) -> UInt32? {
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return nil }
        
        var result: UInt32 = 0
        for part in parts {
            guard let val = UInt32(part), val <= 255 else { return nil }
            result = (result << 8) | val
        }
        return result
    }
    
    private func uint32ToIp(_ val: UInt32) -> String {
        let p1 = (val >> 24) & 0xFF
        let p2 = (val >> 16) & 0xFF
        let p3 = (val >> 8) & 0xFF
        let p4 = val & 0xFF
        return "\(p1).\(p2).\(p3).\(p4)"
    }
    
    private func toBinaryOctets(_ val: UInt32) -> [String] {
        return [
            String((val >> 24) & 0xFF, radix: 2).paddingLeft(toLength: 8, withPad: "0"),
            String((val >> 16) & 0xFF, radix: 2).paddingLeft(toLength: 8, withPad: "0"),
            String((val >> 8) & 0xFF, radix: 2).paddingLeft(toLength: 8, withPad: "0"),
            String(val & 0xFF, radix: 2).paddingLeft(toLength: 8, withPad: "0")
        ]
    }
    
    func generateSubnets(baseIp: String, currentCidr: Int, targetCidr: Int) -> [String] {
        guard let baseInt = ipToUInt32(baseIp), targetCidr > currentCidr, targetCidr <= 32 else { return [] }
        
        let subnetsInNetwork = Int(pow(2.0, Double(targetCidr - currentCidr)))
        let subnetsToReturn = min(subnetsInNetwork, 256)
        let hostsInSubnet = UInt32(pow(2.0, Double(32 - targetCidr)))
        
        var results: [String] = []
        let currentMask: UInt32 = currentCidr == 0 ? 0 : (0xFFFFFFFF << (32 - currentCidr))
        let networkBase = baseInt & currentMask
        
        for i in 0..<subnetsToReturn {
            let subnetStart = networkBase + (UInt32(i) * hostsInSubnet)
            results.append("\(uint32ToIp(subnetStart))/\(targetCidr)")
        }
        return results
    }
}

extension String {
    func paddingLeft(toLength length: Int, withPad pad: String) -> String {
        if self.count >= length { return self }
        return String(repeating: pad, count: length - self.count) + self
    }
}
