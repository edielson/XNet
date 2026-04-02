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
    @Relationship(deleteRule: .cascade, inverse: \NetBoxVLAN.site)
    var vlans: [NetBoxVLAN] = []
    
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
    var notes: String
    var site: NetBoxSite?
    @Relationship(deleteRule: .nullify, inverse: \NetBoxIP.device)
    var assignedIPs: [NetBoxIP] = []
    
    init(name: String, deviceType: String = "Server", assetTag: String = "", notes: String = "", site: NetBoxSite? = nil) {
        self.name = name
        self.deviceType = deviceType
        self.assetTag = assetTag
        self.notes = notes
        self.site = site
    }
}

@Model
final class NetBoxVLANGroup {
    var name: String
    var groupDescription: String
    var minVID: Int = 1
    var maxVID: Int = 4094
    
    @Relationship(deleteRule: .cascade, inverse: \NetBoxVLAN.vlanGroup)
    var vlans: [NetBoxVLAN] = []
    
    init(name: String, groupDescription: String = "", minVID: Int = 1, maxVID: Int = 4094) {
        self.name = name
        self.groupDescription = groupDescription
        self.minVID = minVID
        self.maxVID = maxVID
    }
}

@Model
final class NetBoxVLAN {
    var vid: Int
    var name: String
    var vlanDescription: String
    var status: String
    
    var site: NetBoxSite?
    var vlanGroup: NetBoxVLANGroup?
    
    @Relationship(deleteRule: .nullify, inverse: \NetBoxPrefix.vlan)
    var prefixes: [NetBoxPrefix] = []
    
    init(vid: Int, name: String, vlanDescription: String = "", status: String = "Active", site: NetBoxSite? = nil, vlanGroup: NetBoxVLANGroup? = nil) {
        self.vid = vid
        self.name = name
        self.vlanDescription = vlanDescription
        self.status = status
        self.site = site
        self.vlanGroup = vlanGroup
    }
}

@Model
final class NetBoxPrefix {
    var cidr: String
    var prefixDescription: String
    var site: NetBoxSite?
    var vlan: NetBoxVLAN?
    @Relationship(deleteRule: .cascade, inverse: \NetBoxIP.prefix) 
    var ips: [NetBoxIP] = []
    
    init(cidr: String, prefixDescription: String = "", site: NetBoxSite? = nil, vlan: NetBoxVLAN? = nil) {
        self.cidr = cidr
        self.prefixDescription = prefixDescription
        self.site = site
        self.vlan = vlan
    }
}

@Model
final class NetBoxIP {
    var address: String
    var interfaceLabel: String?
    var usageDescription: String?
    var status: String?
    
    var prefix: NetBoxPrefix?
    var device: NetBoxDevice?
    
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
