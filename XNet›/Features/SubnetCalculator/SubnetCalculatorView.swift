//
//  SubnetCalculatorView.swift
//  XNet›
//

import SwiftUI

struct SubnetCalculatorView: View {
    @State private var ipAddress: String = "192.168.1.1/24"
    @State private var service = SubnetCalculatorService()
    
    @State private var selectedCidrForBreakdown: Int? = nil
    
    private var subnetInfo: SubnetInfo? {
        let parts = ipAddress.split(separator: "/")
        let ip = String(parts.first ?? "")
        let cidr = parts.count > 1 ? (Int(parts[1]) ?? 24) : 24
        return service.calculate(address: ip, cidr: cidr)
    }
    
    private var breakdownSubnets: [String] {
        guard let info = subnetInfo, let target = selectedCidrForBreakdown else { return [] }
        return service.generateSubnets(baseIp: info.networkAddress, currentCidr: info.cidr, targetCidr: target)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Subnet Calculator")
                    .font(.largeTitle)
                    .bold()
                Spacer()
                Image(systemName: "grid")
                    .font(.title)
                    .foregroundStyle(.blue)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("NETWORK CONFIGURATION")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .bold()
                        
                        TextField("IP Address (e.g. 192.168.1.1/24)", text: $ipAddress)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                    
                    if let info = subnetInfo {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ResultCard(title: "Network Address", value: info.networkAddress, icon: "network")
                            ResultCard(title: "Broadcast Address", value: info.broadcastAddress, icon: "antenna.radiowaves.left.and.right")
                            ResultCard(title: "Subnet Mask", value: info.mask, icon: "bolt.shield")
                            ResultCard(title: "Wildcard Mask", value: info.wildcard, icon: "seal")
                            ResultCard(title: "First Usable", value: info.firstUsable, icon: "arrow.right.circle")
                            ResultCard(title: "Last Usable", value: info.lastUsable, icon: "arrow.left.circle")
                        }
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Total Usable Hosts")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("\(info.totalUsable)")
                                    .font(.title2)
                                    .bold()
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("BINARY VISUALIZER")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .bold()
                            
                            BinaryRow(label: "IP", octets: info.binaryAddress, cidr: info.cidr)
                            BinaryRow(label: "Mask", octets: info.binaryMask, cidr: info.cidr, isMask: true)
                        }
                        .padding()
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SUBNET PARTITIONING")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .bold()
                            
                            let currentCidr = info.cidr
                            if currentCidr < 32 {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    ForEach((currentCidr + 1)...32, id: \.self) { targetCidr in
                                        let count = Int(pow(2.0, Double(targetCidr - currentCidr)))
                                        Button(action: {
                                            selectedCidrForBreakdown = targetCidr
                                        }) {
                                            VStack {
                                                Text("/\(targetCidr)")
                                                    .font(.headline)
                                                    .foregroundStyle(selectedCidrForBreakdown == targetCidr ? .white : .blue)
                                                Text("\(count) subnets")
                                                    .font(.caption2)
                                                    .foregroundStyle(selectedCidrForBreakdown == targetCidr ? .white.opacity(0.8) : .secondary)
                                            }
                                            .padding(.vertical, 8)
                                            .frame(maxWidth: .infinity)
                                            .background(selectedCidrForBreakdown == targetCidr ? Color.blue : Color(.controlBackgroundColor))
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            } else {
                                Text("No sub-partitioning possible for a /32 host address.")
                                    .font(.caption)
                                    .italic()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
                        .cornerRadius(12)
                        
                        if let selectedCidr = selectedCidrForBreakdown {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("SUBNET BREAKDOWN (/\(selectedCidr))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .bold()
                                
                                List {
                                    ForEach(breakdownSubnets, id: \.self) { subnet in
                                        HStack {
                                            Text(subnet)
                                                .font(.system(.body, design: .monospaced))
                                                .bold()
                                            Spacer()
                                            let subInfo = service.calculate(address: String(subnet.split(separator: "/")[0]), cidr: selectedCidr)
                                            Text("\(subInfo?.networkAddress ?? "") - \(subInfo?.broadcastAddress ?? "")")
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .listStyle(.plain)
                                .frame(height: 200)
                                .background(Color.black.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(12)
                        }
                    } else {
                        ContentUnavailableView("Invalid IP Address", systemImage: "xmark.circle", description: Text("Please enter a valid IPv4 address to see calculations."))
                    }
                }
                .padding()
            }
        }
    }
}

struct ResultCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(.body, design: .monospaced))
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}

struct BinaryRow: View {
    let label: String
    let octets: [String]
    let cidr: Int
    var isMask: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                ForEach(0..<4) { i in
                    HStack(spacing: 2) {
                        let bits = Array(octets[i])
                        ForEach(0..<8) { b in
                            let absoluteBit = i * 8 + b
                            Text(String(bits[b]))
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(absoluteBit < cidr ? (isMask ? .blue : .primary) : .secondary)
                                .opacity(absoluteBit < cidr ? 1.0 : 0.5)
                        }
                    }
                    if i < 3 {
                        Text(".")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

#Preview {
    SubnetCalculatorView()
        .frame(width: 600, height: 500)
}
