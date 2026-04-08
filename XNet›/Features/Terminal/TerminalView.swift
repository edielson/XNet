import SwiftUI
import SwiftData
import Security

struct TerminalView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var savedDevices: [TerminalDeviceEntry] = []
    
    @State private var connectionType: ConnectionType = .ssh
    @State private var host: String = ""
    @State private var port: String = "22"
    @State private var username: String = ""
    @State private var savedPassword: String = ""
    @State private var manager = TerminalConnectionManager()
    @State private var availableSerialPorts: [String] = []
    @State private var selectedDeviceID: UUID?
    @State private var showingDeviceForm = false
    @State private var editingDevice: TerminalDeviceEntry?
    @State private var isApplyingSavedDevice = false
    @State private var isDeviceListVisible = true
    @State private var tabs: [TerminalTabItem] = [TerminalTabItem(name: "Aba 1")]
    @State private var selectedTabID: UUID? = nil
    
    enum ConnectionType: String, CaseIterable, Identifiable {
        case ssh = "SSH", telnet = "Telnet", serial = "Serial"
        var id: String { self.rawValue }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                tabBar
                
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
                        
                        Button {
                            isDeviceListVisible.toggle()
                        } label: {
                            Label(isDeviceListVisible ? "Ocultar Lista" : "Mostrar Lista", systemImage: isDeviceListVisible ? "sidebar.left" : "sidebar.right")
                        }
                        .buttonStyle(.bordered)
                        
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
                    
                    Button(action: { host = ""; username = ""; savedPassword = ""; manager.logs = "" }) {
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
                if isDeviceListVisible {
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
                                selectedDeviceID = device.id
                                openDeviceInNewTab(device)
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
                                    selectedDeviceID = device.id
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
                }
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
            if selectedTabID == nil, let first = tabs.first {
                selectedTabID = first.id
                loadTab(first)
            }
            reloadSavedDevices()
            if connectionType == .serial {
                availableSerialPorts = manager.getAvailableSerialPorts()
            }
        }
        .onChange(of: connectionType) { _, newValue in
            if !isApplyingSavedDevice {
                updateDefaultPort(for: newValue)
            }
            saveCurrentTabState()
        }
        .onChange(of: host) { _, _ in saveCurrentTabState() }
        .onChange(of: port) { _, _ in saveCurrentTabState() }
        .onChange(of: username) { _, _ in saveCurrentTabState() }
        .onChange(of: savedPassword) { _, _ in saveCurrentTabState() }
        .sheet(isPresented: $showingDeviceForm) {
            TerminalDeviceFormSheet(deviceToEdit: editingDevice) { payload in
                saveDevice(payload)
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tabs) { tab in
                        HStack(spacing: 6) {
                            Button {
                                saveCurrentTabState()
                                selectedTabID = tab.id
                                loadTab(tab)
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(tab.manager.isConnected ? Color.green : Color.secondary.opacity(0.45))
                                        .frame(width: 7, height: 7)
                                    Text(tab.displayName)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedTabID == tab.id ? Color.blue.opacity(0.22) : Color.secondary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            
                            if tabs.count > 1 {
                                Button {
                                    closeTab(tab.id)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            
            Button {
                addTab()
            } label: {
                Label("Nova Aba", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
    }
    
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
            
            if connectionType != .serial {
                Divider().frame(height: 12)
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 10))
                    SecureField("Senha", text: $savedPassword)
                        .textFieldStyle(.plain)
                        .frame(width: 100)
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

    private func saveCurrentTabState() {
        guard let selectedTabID, let index = tabs.firstIndex(where: { $0.id == selectedTabID }) else { return }
        tabs[index].connectionType = connectionType
        tabs[index].host = host
        tabs[index].port = port
        tabs[index].username = username
        tabs[index].password = savedPassword
        tabs[index].availableSerialPorts = availableSerialPorts
        tabs[index].manager = manager
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedHost.isEmpty {
            tabs[index].name = trimmedHost
        }
    }
    
    private func loadTab(_ tab: TerminalTabItem) {
        connectionType = tab.connectionType
        host = tab.host
        port = tab.port
        username = tab.username
        savedPassword = tab.password
        availableSerialPorts = tab.availableSerialPorts
        manager = tab.manager
    }
    
    private func addTab() {
        saveCurrentTabState()
        let tab = TerminalTabItem(name: "Aba \(tabs.count + 1)")
        tabs.append(tab)
        selectedTabID = tab.id
        loadTab(tab)
    }
    
    private func closeTab(_ id: UUID) {
        guard tabs.count > 1 else { return }
        saveCurrentTabState()
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: index)
        if selectedTabID == id {
            let fallback = tabs[min(index, tabs.count - 1)]
            selectedTabID = fallback.id
            loadTab(fallback)
        }
    }
    
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
            manager.setSSHPassword(savedPassword)
            manager.connectSSH(host: host, port: port, user: username)
        case .telnet:
            manager.setTelnetPassword(savedPassword)
            manager.connectTelnet(host: host, port: port)
        case .serial:
            if let baud = Int(port) {
                manager.connectSerial(portPath: host, baudRate: baud)
            }
        }
    }
    
    private var selectedDevice: TerminalDeviceEntry? {
        guard let selectedDeviceID else { return nil }
        return savedDevices.first(where: { $0.id == selectedDeviceID })
    }
    
    private func applyDevice(_ device: TerminalDeviceEntry) {
        isApplyingSavedDevice = true
        connectionType = ConnectionType(rawValue: device.connectionType) ?? .ssh
        host = device.host
        port = device.port
        username = device.username
        savedPassword = TerminalPasswordStore.readPassword(credentialID: device.credentialID) ?? ""
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
    
    private func connectFromDevice(_ device: TerminalDeviceEntry) {
        if manager.isConnected {
            manager.disconnect()
        }
        applyDevice(device)
        DispatchQueue.main.async {
            connectUsingCurrentFields()
        }
    }
    
    private func openDeviceInNewTab(_ device: TerminalDeviceEntry) {
        saveCurrentTabState()
        let newTab = TerminalTabItem(name: device.name)
        tabs.append(newTab)
        selectedTabID = newTab.id
        loadTab(newTab)
        applyDevice(device)
        connectUsingCurrentFields()
        saveCurrentTabState()
    }
    
    private func saveDevice(_ payload: TerminalDevicePayload) {
        let credentialID = editingDevice?.credentialID ?? UUID().uuidString
        let entry = TerminalDeviceEntry(
            id: editingDevice?.id ?? UUID(),
            name: payload.name,
            connectionType: payload.connectionType,
            host: payload.host,
            port: payload.port,
            username: payload.username,
            notes: payload.notes,
            credentialID: credentialID
        )
        
        if let index = savedDevices.firstIndex(where: { $0.id == entry.id }) {
            savedDevices[index] = entry
        } else {
            savedDevices.append(entry)
        }
        savedDevices.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        selectedDeviceID = entry.id
        persistSavedDevicesCache()
        
        if payload.password.isEmpty {
            TerminalPasswordStore.deletePassword(credentialID: credentialID)
        } else {
            TerminalPasswordStore.savePassword(payload.password, credentialID: credentialID)
        }
        
        syncEntryToDatabase(entry)
        editingDevice = nil
    }
    
    private func deleteDevice(_ device: TerminalDeviceEntry) {
        TerminalPasswordStore.deletePassword(credentialID: device.credentialID)
        savedDevices.removeAll { $0.id == device.id }
        persistSavedDevicesCache()
        
        let descriptor = FetchDescriptor<TerminalDevice>(sortBy: [SortDescriptor(\.name, order: .forward)])
        if let records = try? modelContext.fetch(descriptor) {
            if let dbRecord = records.first(where: { $0.credentialID == device.credentialID }) {
                modelContext.delete(dbRecord)
                do {
                    try modelContext.save()
                } catch {
                    manager.logs += "\n[Database Delete Error]: \(error.localizedDescription)\n"
                }
            }
        }
        
        if selectedDeviceID == device.id {
            selectedDeviceID = nil
        }
    }
    
    private func reloadSavedDevices() {
        let descriptor = FetchDescriptor<TerminalDevice>(sortBy: [SortDescriptor(\.name, order: .forward)])
        do {
            let rows = try modelContext.fetch(descriptor)
            if !rows.isEmpty {
                savedDevices = rows.map {
                    TerminalDeviceEntry(
                        id: UUID(),
                        name: $0.name,
                        connectionType: $0.connectionType,
                        host: $0.host,
                        port: $0.port,
                        username: $0.username,
                        notes: $0.notes,
                        credentialID: $0.credentialID
                    )
                }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                persistSavedDevicesCache()
                return
            }
        } catch {
            manager.logs += "\n[Database Fetch Error]: \(error.localizedDescription)\n"
        }
        
        if let data = UserDefaults.standard.data(forKey: TerminalDeviceEntry.storageKey),
           let cached = try? JSONDecoder().decode([TerminalDeviceEntry].self, from: data),
           !cached.isEmpty {
            savedDevices = cached.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } else {
            savedDevices = []
        }
    }
    
    private func syncEntryToDatabase(_ entry: TerminalDeviceEntry) {
        let descriptor = FetchDescriptor<TerminalDevice>(sortBy: [SortDescriptor(\.name, order: .forward)])
        do {
            let rows = try modelContext.fetch(descriptor)
            if let existing = rows.first(where: { $0.credentialID == entry.credentialID }) {
                existing.name = entry.name
                existing.connectionType = entry.connectionType
                existing.host = entry.host
                existing.port = entry.port
                existing.username = entry.username
                existing.notes = entry.notes
            } else {
                let row = TerminalDevice(
                    name: entry.name,
                    connectionType: entry.connectionType,
                    host: entry.host,
                    port: entry.port,
                    username: entry.username,
                    notes: entry.notes,
                    credentialID: entry.credentialID
                )
                modelContext.insert(row)
            }
            try modelContext.save()
        } catch {
            manager.logs += "\n[Database Save Error]: \(error.localizedDescription)\n"
        }
    }
    
    private func persistSavedDevicesCache() {
        if let data = try? JSONEncoder().encode(savedDevices) {
            UserDefaults.standard.set(data, forKey: TerminalDeviceEntry.storageKey)
        }
    }
}

private struct TerminalDevicePayload {
    var name: String
    var connectionType: String
    var host: String
    var port: String
    var username: String
    var password: String
    var notes: String
}

private struct TerminalDeviceEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var connectionType: String
    var host: String
    var port: String
    var username: String
    var notes: String
    var credentialID: String
    
    static let storageKey = "terminal.device.cache.v2"
}

private struct TerminalTabItem: Identifiable {
    let id = UUID()
    var name: String
    var connectionType: TerminalView.ConnectionType = .ssh
    var host: String = ""
    var port: String = "22"
    var username: String = ""
    var password: String = ""
    var availableSerialPorts: [String] = []
    var manager: TerminalConnectionManager = TerminalConnectionManager()
    
    var displayName: String {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedHost.isEmpty ? name : trimmedHost
    }
}

private struct TerminalDeviceFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let deviceToEdit: TerminalDeviceEntry?
    let onSave: (TerminalDevicePayload) -> Void
    
    @State private var name = ""
    @State private var connectionType: TerminalView.ConnectionType = .ssh
    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var password = ""
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
                if connectionType != .serial {
                    SecureField("Senha", text: $password)
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
                            password: password,
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
            password = TerminalPasswordStore.readPassword(credentialID: device.credentialID) ?? ""
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

private enum TerminalPasswordStore {
    private static let service = "br.com.myrouter.xnet.terminal.password"
    
    static func savePassword(_ password: String, credentialID: String) {
        guard let data = password.data(using: .utf8) else { return }
        deletePassword(credentialID: credentialID)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: credentialID,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func readPassword(credentialID: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: credentialID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }
        return password
    }
    
    static func deletePassword(credentialID: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: credentialID
        ]
        SecItemDelete(query as CFDictionary)
    }
}
