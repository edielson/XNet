//
//  Tool.swift
//  XNet›
//

import SwiftUI

enum Tool: String, CaseIterable, Identifiable, Hashable {
    // Dashboard
    case home
    // Audit (Primary)
    case netbox
    // Diagnóstico (Diagnostics)
    case ipScan, portScan, ping, traceroute
    // Remoto (Remote Access)
    case terminal, ftp, subnetCalculator
    
    var id: String { self.rawValue }
    
    var name: String {
        switch self {
        case .home: return "Dashboard"
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
        case .home: return "house.fill"
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

