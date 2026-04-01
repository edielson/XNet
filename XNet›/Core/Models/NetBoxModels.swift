import Foundation
import SwiftData

@Model
final class NetBoxSite {
    var name: String
    var siteDescription: String
    @Relationship(deleteRule: .cascade, inverse: \NetBoxPrefix.site) 
    var prefixes: [NetBoxPrefix] = []
    @Relationship(deleteRule: .cascade, inverse: \NetBoxDevice.site)
    var devices: [NetBoxDevice] = []
    
    init(name: String, siteDescription: String = "") {
        self.name = name
        self.siteDescription = siteDescription
    }
}

@Model
final class NetBoxDevice {
    var name: String
    var deviceType: String
    var assetTag: String
    var site: NetBoxSite?
    @Relationship(deleteRule: .nullify, inverse: \NetBoxIP.device)
    var assignedIPs: [NetBoxIP] = []
    
    init(name: String, deviceType: String = "Server", assetTag: String = "", site: NetBoxSite? = nil) {
        self.name = name
        self.deviceType = deviceType
        self.assetTag = assetTag
        self.site = site
    }
}

@Model
final class NetBoxPrefix {
    var cidr: String
    var prefixDescription: String
    var site: NetBoxSite?
    @Relationship(deleteRule: .cascade, inverse: \NetBoxIP.prefix) 
    var ips: [NetBoxIP] = []
    
    init(cidr: String, prefixDescription: String = "", site: NetBoxSite? = nil) {
        self.cidr = cidr
        self.prefixDescription = prefixDescription
        self.site = site
    }
}

@Model
final class NetBoxIP {
    var address: String
    // Making this optional to solve the 134110 migration error
    var interfaceLabel: String?
    var usageDescription: String?
    var status: String?
    
    var prefix: NetBoxPrefix?
    var device: NetBoxDevice?
    
    // Computed property for easy access with default value
    var label: String { interfaceLabel ?? "LAN" }
    var note: String { usageDescription ?? "" }
    
    init(address: String, interfaceLabel: String = "LAN", usageDescription: String = "", status: String = "Active", prefix: NetBoxPrefix? = nil, device: NetBoxDevice? = nil) {
        self.address = address
        self.interfaceLabel = interfaceLabel
        self.usageDescription = usageDescription
        self.status = status
        self.prefix = prefix
        self.device = device
    }
}
