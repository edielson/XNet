//
//  Tool.swift
//  XNet›
//

import SwiftUI

enum Tool: String, CaseIterable, Identifiable, Hashable {
    // Cadastros (Inventory)
    case devices, deviceGroups, netbox
    // Diagnóstico (Diagnostics)
    case ipScan, portScan, ping, traceroute
    // Remoto (Remote Access)
    case terminal, ftp, subnetCalculator
    
    var id: String { self.rawValue }
    
    var name: String {
        switch self {
        case .devices: return "Devices"
        case .deviceGroups: return "Device Groups"
        case .ipScan: return "IP Scanner"
        case .portScan: return "Port Scan"
        case .ping: return "Ping"
        case .traceroute: return "Traceroute"
        case .terminal: return "Terminal"
        case .ftp: return "FTP"
        case .subnetCalculator: return "Subnet Calculator"
        case .netbox: return "NetBox"
        }
    }
    
    var icon: String {
        switch self {
        case .devices: return "desktopcomputer"
        case .deviceGroups: return "folder.badge.gearshape"
        case .ipScan: return "network"
        case .portScan: return "bolt.horizontal"
        case .ping: return "antenna.radiowaves.left.and.right"
        case .traceroute: return "map"
        case .terminal: return "terminal"
        case .ftp: return "arrow.up.doc"
        case .subnetCalculator: return "plus.forwardslash.minus"
        case .netbox: return "square.stack.3d.up"
        }
    }
}
