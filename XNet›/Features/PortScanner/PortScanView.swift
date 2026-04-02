//
//  PortScanView.swift
//  XNet›
//

import SwiftUI

enum PortScanPreset: String, CaseIterable, Identifiable {
    case common = "Common Ports"
    case all = "All Ports (1-65535)"
    case custom = "Custom Range"
    
    var id: String { self.rawValue }
    
    var portsString: String {
        switch self {
        case .common:
            return "21 22 23 25 53 80 110 135 139 143 443 445 1433 1521 3306 3389 5432 5900 8080"
        case .all:
            return "1-65535"
        case .custom:
            return ""
        }
    }
}

struct PortScanView: View {
    @State private var targetHost: String = "google.com"
    @State private var selectedPreset: PortScanPreset = .common
    @State private var customPorts: String = "80-100"
    
    @State private var scannedPorts: [ScannedPort] = []
    @State private var isRunning = false
    @State private var statusText: String = "Select a preset or enter a custom port range."
    @State private var currentTask: Task<Void, Never>? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // High-End Header
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Port Analysis")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text(isRunning ? "Scanning \(targetHost)..." : "Audit open services and security gaps")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        if isRunning {
                            ProgressView()
                                .controlSize(.small)
                        }
                        
                        Button(action: {
                            isRunning ? stopScan() : startPortScan()
                        }) {
                            HStack {
                                Image(systemName: isRunning ? "stop.fill" : "play.fill")
                                Text(isRunning ? "Stop" : "Scan Now")
                            }
                            .frame(width: 100)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isRunning ? .red : .blue)
                        .keyboardShortcut(.defaultAction)
                    }
                }
                
                // Search & Filter Bar
                HStack(spacing: 16) {
                    // Host Input
                    HStack(spacing: 8) {
                        Image(systemName: "network")
                            .foregroundStyle(.blue)
                            .font(.system(size: 14, weight: .semibold))
                        
                        TextField("Host or IP", text: $targetHost)
                            .textFieldStyle(.plain)
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .disabled(isRunning)
                    
                    Spacer(minLength: 16)
                    
                    // Preset Picker
                    Picker("", selection: $selectedPreset) {
                        ForEach(PortScanPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .disabled(isRunning)
                    
                    // Conditional Custom Range
                    if selectedPreset == .custom {
                        HStack(spacing: 8) {
                            Image(systemName: "number")
                                .foregroundStyle(.secondary)
                            TextField("Range", text: $customPorts)
                                .textFieldStyle(.plain)
                                .font(.system(.body, design: .monospaced))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(width: 130)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .disabled(isRunning)
                    }
                    
                    Button(action: { scannedPorts.removeAll() }) {
                        Image(systemName: "broom.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .help("Clear Results")
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 32)
            .padding(.bottom, 24)
            .background(Color(NSColor.windowBackgroundColor))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedPreset)

            
            Divider()
            
            // Modern Results Table
            Table(scannedPorts) {
                TableColumn("Port") { sp in
                    Text(String(sp.port))
                        .font(.system(.body, design: .monospaced))
                        .bold()
                }
                .width(80)
                
                TableColumn("Status") { sp in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(sp.state == "Open" ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text(sp.state)
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(sp.state == "Open" ? .green : .red)
                    }
                }
                .width(120)
                
                TableColumn("Protocol / Service") { sp in
                    Text(sp.protocolName)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(sp.state == "Open" ? .primary : .secondary)
                }
            }
            .tableStyle(.inset)
        }
        .navigationTitle("Port Scan Diagnostic")
        .onDisappear {
            stopScan()
        }
    }
    
    private func startPortScan() {
        scannedPorts.removeAll()
        isRunning = true
        
        let targetPorts: [Int]
        if selectedPreset == .custom {
            targetPorts = parsePorts(customPorts)
        } else {
            targetPorts = parsePorts(selectedPreset.portsString)
        }
        
        scannedPorts = targetPorts.map { ScannedPort(port: $0, protocolName: "TCP", state: "Closed") }
        
        statusText = "Scanning native ports on \(targetHost)..."
        
        currentTask = Task {
            let stream = PortScannerService.scan(host: targetHost, ports: targetPorts)
            for await openPort in stream {
                if Task.isCancelled { break }
                if let idx = scannedPorts.firstIndex(where: { $0.port == openPort.port }) {
                    scannedPorts[idx] = openPort
                } else {
                    scannedPorts.append(openPort)
                    scannedPorts.sort(by: { $0.port < $1.port })
                }
            }
            isRunning = false
            let openCount = scannedPorts.filter({ $0.state == "Open" }).count
            statusText = "Scan Complete. Found \(openCount) open ports out of \(targetPorts.count)."
        }
    }
    
    private func stopScan() {
        currentTask?.cancel()
        currentTask = nil
        isRunning = false
        statusText = "Scan stopped."
    }
    
    private func parsePorts(_ input: String) -> [Int] {
        var result: [Int] = []
        let parts = input.replacingOccurrences(of: ",", with: " ").components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        for part in parts {
            if part.contains("-") {
                let range = part.components(separatedBy: "-")
                if range.count == 2, let start = Int(range[0]), let end = Int(range[1]) {
                    for p in start...end { result.append(p) }
                }
            } else if let p = Int(part) {
                result.append(p)
            }
        }
        return Array(Set(result)).sorted()
    }
}
