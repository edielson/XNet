import SwiftUI

struct TerminalView: View {
    @State private var connectionType: ConnectionType = .ssh
    @State private var host: String = ""
    @State private var port: String = "22"
    @State private var username: String = ""
    @State private var manager = TerminalConnectionManager()
    @State private var availableSerialPorts: [String] = []
    
    enum ConnectionType: String, CaseIterable, Identifiable {
        case ssh = "SSH", telnet = "Telnet", serial = "Serial"
        var id: String { self.rawValue }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Premium Unified Header
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Shell Terminal")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text(manager.isConnected ? "Session active via \(connectionType.rawValue)" : "Configure your connection")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Picker("", selection: $connectionType) {
                            ForEach(ConnectionType.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                        
                        Button(action: toggleConnection) {
                            HStack {
                                Image(systemName: manager.isConnected ? "stop.fill" : "bolt.fill")
                                Text(manager.isConnected ? "Disconnect" : "Connect")
                            }
                            .frame(width: 100)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(manager.isConnected ? .red : .blue)
                        .disabled(host.isEmpty && connectionType != .serial)
                    }
                }
                
                // Connection Input Bar
                HStack(spacing: 16) {
                    HStack(spacing: 12) {
                        if connectionType == .serial {
                            serialFieldsCompact
                        } else {
                            networkFieldsCompact
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    
                    Spacer(minLength: 0)
                    
                    Button(action: { host = ""; username = ""; manager.logs = "" }) {
                        Image(systemName: "broom.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .help("Clear Terminal & Fields")
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 32)
            .padding(.bottom, 24)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()

            // MARK: - Terminal Canvas
            ZStack {
                Color.black // Fundo sólido
                
                if manager.isConnected {
                    InteractiveTerminalTextView(text: $manager.logs) { input in
                        manager.sendRaw(input)
                    }
                } else {
                    terminalPlaceholder
                }
            }
        }
        .navigationTitle("")
        .onAppear {
            if connectionType == .serial {
                availableSerialPorts = manager.getAvailableSerialPorts()
            }
        }
        .onChange(of: connectionType) { _, newValue in
            updateDefaultPort(for: newValue)
        }
    }

    // MARK: - UI Components
    
    private var networkFieldsCompact: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Image(systemName: "server.rack")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 10))
                TextField("Host", text: $host)
                    .textFieldStyle(.plain)
                    .frame(width: 120)
            }
            
            Divider().frame(height: 12)
            
            HStack(spacing: 4) {
                Image(systemName: "number")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 10))
                TextField("Port", text: $port)
                    .textFieldStyle(.plain)
                    .frame(width: 40)
            }
            
            if connectionType == .ssh {
                Divider().frame(height: 12)
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 10))
                    TextField("User", text: $username)
                        .textFieldStyle(.plain)
                        .frame(width: 80)
                }
            }
        }
    }
    
    private var serialFieldsCompact: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Image(systemName: "cable.connector")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 10))
                Picker("", selection: $host) {
                    if availableSerialPorts.isEmpty {
                        Text("No devices").tag("")
                    } else {
                        ForEach(availableSerialPorts, id: \.self) { p in
                            Text(p.replacingOccurrences(of: "/dev/cu.", with: "")).tag(p)
                        }
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 140)
            }
            
            Divider().frame(height: 12)
            
            HStack(spacing: 4) {
                Image(systemName: "speedometer")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 10))
                Picker("", selection: $port) {
                    ForEach(["9600", "115200", "230400", "921600"], id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 100)
            }
        }
    }

    private var terminalPlaceholder: some View {
        VStack(spacing: 20) {
            Image(systemName: "powershell")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.3))
            Text("Ready to connect...")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary.opacity(0.5))
        }
    }

    // MARK: - Logic
    
    private func updateDefaultPort(for type: ConnectionType) {
        switch type {
        case .ssh: port = "22"
        case .telnet: port = "23"
        case .serial:
            port = "115200"
            availableSerialPorts = manager.getAvailableSerialPorts()
            if let first = availableSerialPorts.first { host = first }
        }
    }
    
    private func toggleConnection() {
        if manager.isConnected {
            manager.disconnect()
        } else {
            manager.logs = ""
            switch connectionType {
            case .ssh: manager.connectSSH(host: host, port: port, user: username)
            case .telnet: manager.connectTelnet(host: host, port: port)
            case .serial:
                if let baud = Int(port) { manager.connectSerial(portPath: host, baudRate: baud) }
            }
        }
    }
}

#Preview {
    TerminalView()
}
