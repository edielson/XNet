import SwiftUI
import SwiftData

struct TerminalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TerminalDevice.name) private var savedDevices: [TerminalDevice]
    
    @State private var connectionType: ConnectionType = .ssh
    @State private var host: String = ""
    @State private var port: String = "22"
    @State private var username: String = ""
    @State private var manager = TerminalConnectionManager()
    @State private var availableSerialPorts: [String] = []
    @State private var selectedDeviceID: PersistentIdentifier?
    @State private var showingDeviceForm = false
    @State private var editingDevice: TerminalDevice?
    @State private var isApplyingSavedDevice = false
    
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
                        Button {
                            editingDevice = nil
                            showingDeviceForm = true
                        } label: {
                            Label("Novo", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            guard let selectedDevice else { return }
                            editingDevice = selectedDevice
                            showingDeviceForm = true
                        } label: {
                            Label("Editar", systemImage: "square.and.pencil")
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedDevice == nil)
                        
                        Button(role: .destructive) {
                            guard let selectedDevice else { return }
                            deleteDevice(selectedDevice)
                        } label: {
                            Label("Excluir", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedDevice == nil)
                        
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
            .padding(.bottom, 16)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
                
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Dispositivos Salvos")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    
                    Divider()
                    
                    List(savedDevices, selection: $selectedDeviceID) { device in
                        Button {
                            selectedDeviceID = device.persistentModelID
                            applyDevice(device)
                            connectFromDevice(device)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.name)
                                    .font(.system(size: 13, weight: .semibold))
                                Text("\(device.connectionType) • \(device.host):\(device.port)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Editar") {
                                selectedDeviceID = device.persistentModelID
                                editingDevice = device
                                showingDeviceForm = true
                            }
                            Button("Excluir", role: .destructive) {
                                deleteDevice(device)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                .frame(width: 300)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                ZStack {
                    Color.black
                    
                    if manager.isConnected {
                        InteractiveTerminalTextView(text: $manager.logs) { input in
                            manager.sendRaw(input)
                        }
                    } else {
                        terminalPlaceholder
                    }
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
            if !isApplyingSavedDevice {
                updateDefaultPort(for: newValue)
            }
        }
        .sheet(isPresented: $showingDeviceForm) {
            TerminalDeviceFormSheet(deviceToEdit: editingDevice) { payload in
                saveDevice(payload)
            }
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
            connectUsingCurrentFields()
        }
    }
    
    private func connectUsingCurrentFields() {
        manager.logs = ""
        switch connectionType {
        case .ssh:
            manager.connectSSH(host: host, port: port, user: username)
        case .telnet:
            manager.connectTelnet(host: host, port: port)
        case .serial:
            if let baud = Int(port) {
                manager.connectSerial(portPath: host, baudRate: baud)
            }
        }
    }
    
    private var selectedDevice: TerminalDevice? {
        guard let selectedDeviceID else { return nil }
        return savedDevices.first(where: { $0.persistentModelID == selectedDeviceID })
    }
    
    private func applyDevice(_ device: TerminalDevice) {
        isApplyingSavedDevice = true
        connectionType = ConnectionType(rawValue: device.connectionType) ?? .ssh
        host = device.host
        port = device.port
        username = device.username
        if connectionType == .serial {
            availableSerialPorts = manager.getAvailableSerialPorts()
            if !availableSerialPorts.contains(host), !host.isEmpty {
                availableSerialPorts.insert(host, at: 0)
            }
        }
        DispatchQueue.main.async {
            isApplyingSavedDevice = false
        }
    }
    
    private func connectFromDevice(_ device: TerminalDevice) {
        if manager.isConnected {
            manager.disconnect()
        }
        applyDevice(device)
        DispatchQueue.main.async {
            connectUsingCurrentFields()
        }
    }
    
    private func saveDevice(_ payload: TerminalDevicePayload) {
        if let existing = editingDevice {
            existing.name = payload.name
            existing.connectionType = payload.connectionType
            existing.host = payload.host
            existing.port = payload.port
            existing.username = payload.username
            existing.notes = payload.notes
        } else {
            let device = TerminalDevice(
                name: payload.name,
                connectionType: payload.connectionType,
                host: payload.host,
                port: payload.port,
                username: payload.username,
                notes: payload.notes
            )
            modelContext.insert(device)
        }
        try? modelContext.save()
        editingDevice = nil
    }
    
    private func deleteDevice(_ device: TerminalDevice) {
        modelContext.delete(device)
        try? modelContext.save()
        if selectedDeviceID == device.persistentModelID {
            selectedDeviceID = nil
        }
    }
}

private struct TerminalDevicePayload {
    var name: String
    var connectionType: String
    var host: String
    var port: String
    var username: String
    var notes: String
}

private struct TerminalDeviceFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let deviceToEdit: TerminalDevice?
    let onSave: (TerminalDevicePayload) -> Void
    
    @State private var name = ""
    @State private var connectionType: TerminalView.ConnectionType = .ssh
    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var notes = ""
    
    var body: some View {
        VStack(spacing: 16) {
            Text(deviceToEdit == nil ? "Novo Dispositivo" : "Editar Dispositivo")
                .font(.title3.bold())
            
            Form {
                TextField("Nome", text: $name)
                Picker("Tipo", selection: $connectionType) {
                    ForEach(TerminalView.ConnectionType.allCases) { Text($0.rawValue).tag($0) }
                }
                TextField(connectionType == .serial ? "Porta serial" : "Host/IP", text: $host)
                TextField(connectionType == .serial ? "Baud rate" : "Porta", text: $port)
                if connectionType == .ssh {
                    TextField("Usuário", text: $username)
                }
                TextField("Notas", text: $notes)
            }
            .formStyle(.grouped)
            
            HStack {
                Spacer()
                Button("Cancelar", role: .cancel) {
                    dismiss()
                }
                Button("Salvar") {
                    onSave(
                        TerminalDevicePayload(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Dispositivo" : name,
                            connectionType: connectionType.rawValue,
                            host: host,
                            port: port,
                            username: username,
                            notes: notes
                        )
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && connectionType != .serial)
            }
        }
        .padding(18)
        .frame(width: 460)
        .onAppear {
            guard let device = deviceToEdit else { return }
            name = device.name
            connectionType = TerminalView.ConnectionType(rawValue: device.connectionType) ?? .ssh
            host = device.host
            port = device.port
            username = device.username
            notes = device.notes
        }
        .onChange(of: connectionType) { _, value in
            if deviceToEdit != nil { return }
            switch value {
            case .ssh:
                port = "22"
            case .telnet:
                port = "23"
            case .serial:
                port = "115200"
            }
        }
    }
}

#Preview {
    TerminalView()
}
