//
//  DetailContentView.swift
//  XNet›
//

import SwiftUI

struct DetailContentView: View {
    let tool: Tool
    
    var body: some View {
        switch tool {
        case .ping:
            PingView()
        case .traceroute:
            TracerouteView()
        case .ipScan:
            IPScanView()
        case .portScan:
            PortScanView()
        case .terminal:
            TerminalView()
        case .ftp:
            FTPView()
        case .subnetCalculator:
            SubnetCalculatorView()
        case .netbox:
            NetBoxView()
        case .devices:
            InventoryDevicesView()
        default:
            PlaceholderView(tool: tool)
        }
    }
}

struct PlaceholderView: View {
    let tool: Tool
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: tool.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
                
                Text(tool.name)
                    .font(.largeTitle)
                    .bold()
                
                Spacer()
            }
            .padding()
            
            Divider()
            
            Spacer()
            
            Text("Interface for \(tool.name) is ready for implementation.")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Local storage (SwiftData) will be used here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(tool.name)
    }
}
