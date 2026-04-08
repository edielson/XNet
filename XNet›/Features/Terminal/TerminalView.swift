import SwiftUI
import SwiftData

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
    @State private var tabs: [TerminalTabItem] = []
    @State private var selectedTabID: UUID? = nil
    @State private var deviceSearch = ""
    
    enum ConnectionType: String, CaseIterable, Identifiable {
        case ssh = "SSH", telnet = "Telnet", serial = "Serial"
        var id: String { self.rawValue }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                tabBar
                
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Shell Terminal")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        HStack(spacing: 8) {
                            Image(systemName: manager.isConnected ? "waveform.path.ecg" : "bolt.horizontal")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(manager.isConnected ? .green : .secondary)
                            Text(manager.isConnected ? "Sessão ativa via \(connectionType.rawValue)" : "Pronto para conectar")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
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
                        .controlSize(.small)
                        
                        Button {
                            guard let selectedDevice else { return }
                            editingDevice = selectedDevice
                            showingDeviceForm = true
                        } label: {
                            Label("Editar", systemImage: "square.and.pencil")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(selectedDevice == nil)
                        
                        Button(role: .destructive) {
                            guard let selectedDevice else { return }
                            deleteDevice(selectedDevice)
                        } label: {
                            Label("Excluir", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(selectedDevice == nil)
                        
                        Button {
                            isDeviceListVisible.toggle()
                        } label: {
                            Label(isDeviceListVisible ? "Ocultar Lista" : "Mostrar Lista", systemImage: isDeviceListVisible ? "sidebar.left" : "sidebar.right")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
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
                        .controlSize(.small)
                    }
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
                            Text("\(savedDevices.count)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.primary.opacity(0.08))
                                .clipShape(Capsule())
                            Spacer()
                            Button {
                                editingDevice = nil
                                showingDeviceForm = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        
                        Divider()
                        
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            TextField("Buscar host, IP ou usuário", text: $deviceSearch)
                                .textFieldStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredSavedDevices) { device in
                                    HStack(spacing: 10) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.blue.opacity(0.22))
                                                .frame(width: 28, height: 28)
                                            Image(systemName: "terminal")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(.blue)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(device.name)
                                                .font(.system(size: 12, weight: .semibold))
                                                .lineLimit(1)
                                            Text("\(device.connectionType.lowercased()), \(device.username.isEmpty ? "sem user" : device.username)")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                            Text("\(device.host):\(device.port)")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedDeviceID = device.id
                                        }
                                        
                                        HStack(spacing: 4) {
                                            Button {
                                                selectedDeviceID = device.id
                                                editingDevice = device
                                                showingDeviceForm = true
                                            } label: {
                                                Image(systemName: "square.and.pencil")
                                                    .font(.system(size: 10, weight: .bold))
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.mini)
                                            
                                            Button {
                                                selectedDeviceID = device.id
                                                openDeviceInNewTab(device)
                                            } label: {
                                                Image(systemName: "play.fill")
                                                    .font(.system(size: 10, weight: .bold))
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .controlSize(.mini)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(selectedDeviceID == device.id ? Color.accentColor.opacity(0.2) : Color.white.opacity(0.03))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedDeviceID == device.id ? Color.accentColor.opacity(0.45) : Color.white.opacity(0.06), lineWidth: 1)
                                    )
                                    .contextMenu {
                                        Button("Editar") {
                                            selectedDeviceID = device.id
                                            editingDevice = device
                                            showingDeviceForm = true
                                        }
                                        Button("Conectar") {
                                            selectedDeviceID = device.id
                                            openDeviceInNewTab(device)
                                        }
                                        Button("Excluir", role: .destructive) {
                                            deleteDevice(device)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                        }
                    }
                    .frame(width: 300)
                    .background(
                        LinearGradient(
                            colors: [Color(NSColor.controlBackgroundColor), Color(NSColor.windowBackgroundColor)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    Divider()
                }
                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.95)
                    
                    
                    if manager.isConnected {
                        InteractiveTerminalTextView(text: $manager.logs) { input in
                            manager.sendRaw(input)
                        }
                    } else {
                        terminalPlaceholder
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(10)
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color(NSColor.windowBackgroundColor),
                    Color(NSColor.windowBackgroundColor).opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .navigationTitle("")
        .onAppear {
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
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedTabID == tab.id ? Color.blue.opacity(0.26) : Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                closeTab(tab.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
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
            .controlSize(.small)
        }
        .padding(8)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
        let tab = TerminalTabItem(name: "Sessão \(tabs.count + 1)")
        tabs.append(tab)
        selectedTabID = tab.id
        loadTab(tab)
    }
    
    private func closeTab(_ id: UUID) {
        saveCurrentTabState()
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].manager.disconnect()
        tabs.remove(at: index)
        if tabs.isEmpty {
            selectedTabID = nil
            manager = TerminalConnectionManager()
            host = ""
            port = "22"
            username = ""
            savedPassword = ""
            availableSerialPorts = []
            return
        }
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
        ensureActiveTabForCurrentSession()
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
    
    private func ensureActiveTabForCurrentSession() {
        guard selectedTabID == nil else { return }
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let tab = TerminalTabItem(name: trimmedHost.isEmpty ? "Sessão 1" : trimmedHost)
        tabs.append(tab)
        selectedTabID = tab.id
        saveCurrentTabState()
    }
    
    private var selectedDevice: TerminalDeviceEntry? {
        guard let selectedDeviceID else { return nil }
        return savedDevices.first(where: { $0.id == selectedDeviceID })
    }
    
    private var filteredSavedDevices: [TerminalDeviceEntry] {
        let term = deviceSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return savedDevices }
        return savedDevices.filter {
            $0.name.localizedCaseInsensitiveContains(term)
            || $0.host.localizedCaseInsensitiveContains(term)
            || $0.username.localizedCaseInsensitiveContains(term)
            || $0.connectionType.localizedCaseInsensitiveContains(term)
        }
    }
    
    private func applyDevice(_ device: TerminalDeviceEntry) {
        isApplyingSavedDevice = true
        connectionType = ConnectionType(rawValue: device.connectionType) ?? .ssh
        host = device.host
        port = device.port
        username = device.username
        savedPassword = resolvePassword(for: device)
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
        let credentialID = normalizedCredentialID(existing: editingDevice?.credentialID)
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
            credentialCandidates(for: entry).forEach { TerminalPasswordStore.deletePassword(credentialID: $0) }
        } else {
            let allSaved = credentialCandidates(for: entry).allSatisfy { candidateID in
                TerminalPasswordStore.savePassword(payload.password, credentialID: candidateID)
            }
            if !allSaved {
                manager.logs += "\n[Credential Save Error]\n"
            }
        }
        
        syncEntryToDatabase(entry)
        editingDevice = nil
    }
    
    private func deleteDevice(_ device: TerminalDeviceEntry) {
        credentialCandidates(for: device).forEach { TerminalPasswordStore.deletePassword(credentialID: $0) }
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
    
    private func normalizedCredentialID(existing: String?) -> String {
        let trimmed = existing?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? UUID().uuidString : trimmed
    }
    
    private func normalizedCredentialID(for entry: TerminalDeviceEntry) -> String {
        let trimmed = entry.credentialID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "\(entry.connectionType)|\(entry.host)|\(entry.port)|\(entry.username)" : trimmed
    }
    
    private func resolvePassword(for entry: TerminalDeviceEntry) -> String {
        let primaryID = normalizedCredentialID(for: entry)
        for candidateID in credentialCandidates(for: entry) {
            guard let password = TerminalPasswordStore.readPassword(credentialID: candidateID),
                  !password.isEmpty else { continue }
            if candidateID != primaryID {
                _ = TerminalPasswordStore.savePassword(password, credentialID: primaryID)
            }
            return password
        }
        return ""
    }
    
    private func credentialCandidates(for entry: TerminalDeviceEntry) -> [String] {
        let primaryID = normalizedCredentialID(for: entry)
        let host = entry.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = entry.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let type = entry.connectionType.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = entry.port.trimmingCharacters(in: .whitespacesAndNewlines)
        let hostLower = host.lowercased()
        
        var candidates = [
            primaryID,
            "\(type)|\(host)|\(port)|\(user)",
            "\(host)|\(port)|\(user)",
            "\(host)|\(user)"
        ]
        
        if !hostLower.isEmpty {
            candidates.append("\(type)|\(hostLower)|\(port)|\(user)")
            candidates.append("\(hostLower)|\(port)|\(user)")
            candidates.append("\(hostLower)|\(user)")
        }
        
        var unique: [String] = []
        for candidate in candidates {
            let value = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty { continue }
            if !unique.contains(value) {
                unique.append(value)
            }
        }
        return unique
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
    private static let keyPrefix = "br.com.myrouter.xnet.terminal.password."
    
    static func savePassword(_ password: String, credentialID: String) -> Bool {
        UserDefaults.standard.set(password, forKey: keyPrefix + credentialID)
        return true
    }
    
    static func readPassword(credentialID: String) -> String? {
        UserDefaults.standard.string(forKey: keyPrefix + credentialID)
    }
    
    static func deletePassword(credentialID: String) {
        UserDefaults.standard.removeObject(forKey: keyPrefix + credentialID)
    }
}
