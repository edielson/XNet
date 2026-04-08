import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct TerminalView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var savedDevices: [TerminalDeviceEntry] = []
    @State private var savedGroups: [String] = ["Geral"]
    
    @State private var connectionType: ConnectionType = .ssh
    @State private var host: String = ""
    @State private var port: String = "22"
    @State private var username: String = ""
    @State private var savedPassword: String = ""
    @State private var manager = TerminalConnectionManager()
    @State private var availableSerialPorts: [String] = []
    @State private var selectedDeviceID: UUID?
    @State private var showingDeviceForm = false
    @State private var showingGroupForm = false
    @State private var editingDevice: TerminalDeviceEntry?
    @State private var isApplyingSavedDevice = false
    @State private var isDeviceListVisible = true
    @State private var tabs: [TerminalTabItem] = []
    @State private var selectedTabID: UUID? = nil
    @State private var deviceSearch = ""
    @State private var expandedGroups: Set<String> = []
    @State private var showingDeviceExporter = false
    @State private var showingDeviceImporter = false
    @State private var exportDocument = TerminalDeviceRegistryDocument()
    @State private var exportFilename = "xnet-dispositivos.json"
    @State private var importExportMessage: String?
    @State private var selectedThemeID = TerminalThemeStore.readThemeID()
    
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
                            .foregroundStyle(selectedTheme.foregroundColor)
                        HStack(spacing: 8) {
                            Image(systemName: manager.isConnected ? "waveform.path.ecg" : "bolt.horizontal")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(manager.isConnected ? .green : selectedTheme.mutedColor)
                            Text(manager.isConnected ? "Sessão ativa via \(connectionType.rawValue)" : "Pronto para conectar")
                                .font(.subheadline)
                                .foregroundStyle(selectedTheme.mutedColor)
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
                            showingGroupForm = true
                        } label: {
                            Label("Nova Pasta", systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Menu {
                            Button("Exportar Cadastros") {
                                prepareDeviceExport()
                            }
                            Button("Importar Cadastros") {
                                showingDeviceImporter = true
                            }
                        } label: {
                            Label("Cadastro", systemImage: "arrow.up.arrow.down.square")
                        }
                        .menuStyle(.borderedButton)
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
                        .tint(manager.isConnected ? .red : selectedTheme.accentColor)
                        .disabled(host.isEmpty && connectionType != .serial)
                        .controlSize(.small)
                    }
                }
                
                themeSelector
            }
            .padding(.horizontal, 28)
            .padding(.top, 32)
            .padding(.bottom, 16)
            .background(
                LinearGradient(
                    colors: [selectedTheme.chromeTopColor, selectedTheme.chromeBottomColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            Divider()
                
            HStack(spacing: 0) {
                if isDeviceListVisible {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Dispositivos Salvos")
                                .font(.headline)
                                .foregroundStyle(selectedTheme.foregroundColor)
                            Text("\(savedDevices.count)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(selectedTheme.mutedColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(selectedTheme.cardBackgroundColor.opacity(selectedTheme.isLight ? 0.95 : 0.68))
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
                            
                            Button {
                                showingGroupForm = true
                            } label: {
                                Image(systemName: "folder.badge.plus")
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
                                .foregroundStyle(selectedTheme.mutedColor)
                            TextField("Buscar host, IP ou usuário", text: $deviceSearch)
                                .textFieldStyle(.plain)
                                .foregroundStyle(selectedTheme.foregroundColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(selectedTheme.cardBackgroundColor.opacity(selectedTheme.isLight ? 0.95 : 0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(groupedFilteredSavedDevices, id: \.group) { groupItem in
                                    VStack(spacing: 6) {
                                        Button {
                                            toggleGroup(groupItem.group)
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: expandedGroups.contains(groupItem.group) ? "folder.fill" : "folder")
                                                    .foregroundStyle(selectedTheme.mutedColor)
                                                Text(groupItem.group)
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(selectedTheme.foregroundColor)
                                                Text("\(groupItem.devices.count)")
                                                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(selectedTheme.mutedColor)
                                                    .padding(.horizontal, 7)
                                                    .padding(.vertical, 2)
                    .background(selectedTheme.cardBackgroundColor.opacity(selectedTheme.isLight ? 0.9 : 0.7))
                                                    .clipShape(Capsule())
                                                Spacer()
                                                Image(systemName: expandedGroups.contains(groupItem.group) ? "chevron.down" : "chevron.right")
                                                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(selectedTheme.mutedColor)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 7)
            .background(selectedTheme.cardBackgroundColor.opacity(selectedTheme.isLight ? 0.9 : 0.52))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        .buttonStyle(.plain)
                                        
                                        if expandedGroups.contains(groupItem.group) {
                                            VStack(spacing: 8) {
                                                ForEach(groupItem.devices) { device in
                                                    deviceRow(device)
                                                }
                                            }
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
                            colors: [selectedTheme.sidebarTopColor, selectedTheme.sidebarBottomColor],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    Divider()
                }
                ZStack(alignment: .topLeading) {
                    selectedTheme.backgroundColor
                    
                    
                    if manager.isConnected {
                        InteractiveTerminalTextView(text: $manager.logs, theme: selectedTheme) { input in
                            manager.sendRaw(input)
                        }
                    } else {
                        terminalPlaceholder
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selectedTheme.panelBorderColor.opacity(selectedTheme.isLight ? 0.65 : 0.7), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(10)
            }
        }
        .background(
            LinearGradient(
                colors: [
                    selectedTheme.chromeTopColor,
                    selectedTheme.chromeBottomColor
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .navigationTitle("")
        .onAppear {
            reloadSavedDevices()
            reloadSavedGroups()
            refreshExpandedGroups()
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
        .onChange(of: deviceSearch) { _, _ in
            refreshExpandedGroups()
        }
        .onChange(of: selectedThemeID) { _, newValue in
            TerminalThemeStore.saveThemeID(newValue)
        }
        .sheet(isPresented: $showingDeviceForm) {
            TerminalDeviceFormSheet(deviceToEdit: editingDevice, availableGroups: formGroupOptions) { payload in
                saveDevice(payload)
            }
        }
        .sheet(isPresented: $showingGroupForm) {
            TerminalDeviceGroupFormSheet { name in
                createGroup(named: name)
            }
        }
        .fileExporter(
            isPresented: $showingDeviceExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                importExportMessage = "Cadastros exportados com sucesso."
            case .failure(let error):
                importExportMessage = "Falha ao exportar: \(error.localizedDescription)"
            }
        }
        .fileImporter(
            isPresented: $showingDeviceImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleDeviceImport(result)
        }
        .alert("Cadastro de Dispositivos", isPresented: Binding(
            get: { importExportMessage != nil },
            set: { if !$0 { importExportMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importExportMessage ?? "")
        }
    }

    private var selectedTheme: TerminalTheme {
        TerminalTheme(rawValue: selectedThemeID) ?? .defaultTheme
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
                                        .foregroundStyle(selectedTheme.foregroundColor)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedTabID == tab.id ? selectedTheme.accentColor.opacity(selectedTheme.isLight ? 0.18 : 0.24) : selectedTheme.cardBackgroundColor.opacity(selectedTheme.isLight ? 0.82 : 0.58))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                closeTab(tab.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(selectedTheme.mutedColor)
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
        .background(selectedTheme.cardBackgroundColor.opacity(selectedTheme.isLight ? 0.9 : 0.52))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(selectedTheme.panelBorderColor.opacity(selectedTheme.isLight ? 0.4 : 0.5), lineWidth: 1)
        )
    }

    private var themeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Temas do Terminal", systemImage: "paintpalette")
                    .font(.headline)
                    .foregroundStyle(selectedTheme.foregroundColor)
                Spacer()
                Text(selectedTheme.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(selectedTheme.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(selectedTheme.accentColor.opacity(selectedTheme.isLight ? 0.12 : 0.16))
                    .clipShape(Capsule())
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(TerminalTheme.allCases) { theme in
                        Button {
                            selectedThemeID = theme.rawValue
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                themePreview(theme)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(theme.displayName)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(selectedTheme.foregroundColor)
                                        .lineLimit(1)
                                    Text(theme.appearanceLabel)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(selectedTheme.mutedColor)
                                }
                            }
                            .padding(12)
                            .frame(width: 170, alignment: .leading)
                            .background(
                                selectedThemeID == theme.rawValue
                                ? selectedTheme.accentColor.opacity(selectedTheme.isLight ? 0.16 : 0.18)
                                : selectedTheme.cardBackgroundColor.opacity(selectedTheme.isLight ? 0.88 : 0.6)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(selectedThemeID == theme.rawValue ? selectedTheme.accentColor.opacity(0.95) : selectedTheme.panelBorderColor.opacity(selectedTheme.isLight ? 0.4 : 0.55), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(16)
        .background(selectedTheme.cardBackgroundColor.opacity(selectedTheme.isLight ? 0.92 : 0.62))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(selectedTheme.panelBorderColor.opacity(selectedTheme.isLight ? 0.4 : 0.55), lineWidth: 1)
        )
    }
    
    private func themePreview(_ theme: TerminalTheme) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.backgroundColor)
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.accentColor)
                    .frame(width: 80, height: 8)
                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.foregroundColor.opacity(theme.isLight ? 0.8 : 0.72))
                    .frame(width: 110, height: 5)
                
                HStack(spacing: 5) {
                    ForEach(Array(theme.previewSwatches.enumerated()), id: \.offset) { item in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(item.element)
                            .frame(width: item.offset == 0 ? 24 : 17, height: 6)
                    }
                }
            }
            .padding(10)
        }
        .frame(height: 72)
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(theme.cursorColor)
                .frame(width: 8, height: 8)
                .padding(8)
        }
    }
    
    private var terminalPlaceholder: some View {
        VStack(spacing: 20) {
            Image(systemName: "powershell")
                .font(.system(size: 40))
                .foregroundStyle(selectedTheme.foregroundColor.opacity(0.28))
            Text("Ready to connect...")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(selectedTheme.foregroundColor.opacity(0.54))
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
            || normalizedGroupName($0.groupName).localizedCaseInsensitiveContains(term)
        }
    }
    
    private var groupedFilteredSavedDevices: [(group: String, devices: [TerminalDeviceEntry])] {
        let grouped = Dictionary(grouping: filteredSavedDevices) { normalizedGroupName($0.groupName) }
        let term = deviceSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let groupNames = allGroupNames.filter { group in
            if term.isEmpty { return true }
            return group.localizedCaseInsensitiveContains(term) || !(grouped[group] ?? []).isEmpty
        }
        return groupNames.map { key in
            let devices = (grouped[key] ?? []).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return (group: key, devices: devices)
        }
    }
    
    private var allGroupNames: [String] {
        let merged = savedGroups + savedDevices.map(\.groupName) + ["Geral"]
        var unique: [String] = []
        for name in merged.map(normalizedGroupName(_:)) {
            if !unique.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                unique.append(name)
            }
        }
        return unique.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    private var formGroupOptions: [String] {
        var options = allGroupNames
        if let editingDevice {
            let normalized = normalizedGroupName(editingDevice.groupName)
            if !options.contains(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) {
                options.append(normalized)
            }
        }
        return options.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
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
        let normalizedGroup = normalizedGroupName(payload.groupName)
        ensureGroupExists(named: normalizedGroup)
        let credentialID = normalizedCredentialID(existing: editingDevice?.credentialID)
        let entry = TerminalDeviceEntry(
            id: editingDevice?.id ?? UUID(),
            name: payload.name,
            groupName: normalizedGroup,
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
        refreshExpandedGroups()
        
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
        NotificationCenter.default.post(name: Notification.Name("TerminalDevicesUpdated"), object: nil)
        editingDevice = nil
    }
    
    private func deleteDevice(_ device: TerminalDeviceEntry) {
        credentialCandidates(for: device).forEach { TerminalPasswordStore.deletePassword(credentialID: $0) }
        savedDevices.removeAll { $0.id == device.id }
        persistSavedDevicesCache()
        refreshExpandedGroups()
        
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
        NotificationCenter.default.post(name: Notification.Name("TerminalDevicesUpdated"), object: nil)
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
                        groupName: $0.groupName,
                        connectionType: $0.connectionType,
                        host: $0.host,
                        port: $0.port,
                        username: $0.username,
                        notes: $0.notes,
                        credentialID: $0.credentialID
                    )
                }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                persistSavedDevicesCache()
                refreshExpandedGroups()
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
        refreshExpandedGroups()
    }
    
    private func reloadSavedGroups() {
        let descriptor = FetchDescriptor<TerminalDeviceGroup>(sortBy: [SortDescriptor(\.name, order: .forward)])
        var names = ((try? modelContext.fetch(descriptor)) ?? []).map(\.name)
        
        if names.isEmpty,
           let data = UserDefaults.standard.data(forKey: TerminalDeviceGroupStore.storageKey),
           let cached = try? JSONDecoder().decode([String].self, from: data) {
            names = cached
        }
        
        let normalized = normalizedGroupCollection(names + savedDevices.map(\.groupName) + ["Geral"])
        savedGroups = normalized
        persistGroupCache()
        syncGroupsToDatabase(normalized)
    }
    
    private func syncEntryToDatabase(_ entry: TerminalDeviceEntry) {
        let descriptor = FetchDescriptor<TerminalDevice>(sortBy: [SortDescriptor(\.name, order: .forward)])
        do {
            let rows = try modelContext.fetch(descriptor)
            if let existing = rows.first(where: { $0.credentialID == entry.credentialID }) {
                existing.name = entry.name
                existing.groupName = normalizedGroupName(entry.groupName)
                existing.connectionType = entry.connectionType
                existing.host = entry.host
                existing.port = entry.port
                existing.username = entry.username
                existing.notes = entry.notes
            } else {
                let row = TerminalDevice(
                    name: entry.name,
                    groupName: normalizedGroupName(entry.groupName),
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
    
    private func persistGroupCache() {
        if let data = try? JSONEncoder().encode(savedGroups) {
            UserDefaults.standard.set(data, forKey: TerminalDeviceGroupStore.storageKey)
        }
    }
    
    private func normalizedCredentialID(existing: String?) -> String {
        let trimmed = existing?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? UUID().uuidString : trimmed
    }
    
    private func normalizedGroupName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Geral" : trimmed
    }
    
    private func normalizedGroupCollection(_ values: [String]) -> [String] {
        var unique: [String] = []
        for value in values.map(normalizedGroupName(_:)) {
            if !unique.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
                unique.append(value)
            }
        }
        return unique.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    private func ensureGroupExists(named name: String) {
        let normalized = normalizedGroupName(name)
        savedGroups = normalizedGroupCollection(savedGroups + [normalized])
        persistGroupCache()
        syncGroupsToDatabase([normalized])
        refreshExpandedGroups()
    }
    
    private func createGroup(named name: String) {
        ensureGroupExists(named: name)
    }
    
    private func prepareDeviceExport() {
        let payload = TerminalDeviceRegistryPayload(
            version: 1,
            exportedAt: Date(),
            includesPasswords: false,
            groups: allGroupNames,
            devices: savedDevices.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(payload)
            exportDocument = TerminalDeviceRegistryDocument(text: String(decoding: data, as: UTF8.self))
            let formatter = ISO8601DateFormatter()
            let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
            exportFilename = "xnet-dispositivos-\(timestamp).json"
            showingDeviceExporter = true
        } catch {
            importExportMessage = "Falha ao preparar exportação: \(error.localizedDescription)"
        }
    }
    
    private func handleDeviceImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                let data = try Data(contentsOf: url)
                try importRegistry(from: data)
            } catch {
                importExportMessage = "Falha ao importar: \(error.localizedDescription)"
            }
        case .failure(let error):
            importExportMessage = "Falha ao importar: \(error.localizedDescription)"
        }
    }
    
    private func importRegistry(from data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(TerminalDeviceRegistryPayload.self, from: data)
        
        for group in payload.groups {
            ensureGroupExists(named: group)
        }
        
        var mergedDevices = savedDevices
        
        for imported in payload.devices {
            let normalizedImported = TerminalDeviceEntry(
                id: imported.id,
                name: imported.name,
                groupName: normalizedGroupName(imported.groupName),
                connectionType: imported.connectionType,
                host: imported.host,
                port: imported.port,
                username: imported.username,
                notes: imported.notes,
                credentialID: normalizedCredentialID(existing: imported.credentialID)
            )
            
            ensureGroupExists(named: normalizedImported.groupName)
            
            if let existingIndex = mergedDevices.firstIndex(where: { matchesImportedEntry($0, normalizedImported) }) {
                let existing = mergedDevices[existingIndex]
                let merged = TerminalDeviceEntry(
                    id: existing.id,
                    name: normalizedImported.name,
                    groupName: normalizedImported.groupName,
                    connectionType: normalizedImported.connectionType,
                    host: normalizedImported.host,
                    port: normalizedImported.port,
                    username: normalizedImported.username,
                    notes: normalizedImported.notes,
                    credentialID: existing.credentialID
                )
                mergedDevices[existingIndex] = merged
                syncEntryToDatabase(merged)
            } else {
                mergedDevices.append(normalizedImported)
                syncEntryToDatabase(normalizedImported)
            }
        }
        
        savedDevices = mergedDevices.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persistSavedDevicesCache()
        reloadSavedGroups()
        refreshExpandedGroups()
        NotificationCenter.default.post(name: Notification.Name("TerminalDevicesUpdated"), object: nil)
        
        let importedCount = payload.devices.count
        importExportMessage = "Importação concluída. \(importedCount) dispositivo(s) processado(s). Senhas não fazem parte do arquivo por segurança."
    }
    
    private func matchesImportedEntry(_ existing: TerminalDeviceEntry, _ imported: TerminalDeviceEntry) -> Bool {
        if !existing.credentialID.isEmpty,
           !imported.credentialID.isEmpty,
           existing.credentialID == imported.credentialID {
            return true
        }
        
        return existing.connectionType.caseInsensitiveCompare(imported.connectionType) == .orderedSame
        && existing.host.caseInsensitiveCompare(imported.host) == .orderedSame
        && existing.port == imported.port
        && existing.username.caseInsensitiveCompare(imported.username) == .orderedSame
    }
    
    private func syncGroupsToDatabase(_ groupNames: [String]) {
        let normalized = normalizedGroupCollection(groupNames + ["Geral"])
        let descriptor = FetchDescriptor<TerminalDeviceGroup>(sortBy: [SortDescriptor(\.name, order: .forward)])
        do {
            let rows = try modelContext.fetch(descriptor)
            for groupName in normalized {
                if rows.contains(where: { $0.name.caseInsensitiveCompare(groupName) == .orderedSame }) {
                    continue
                }
                modelContext.insert(TerminalDeviceGroup(name: groupName))
            }
            try modelContext.save()
        } catch {
            manager.logs += "\n[Database Group Save Error]: \(error.localizedDescription)\n"
        }
    }
    
    private func toggleGroup(_ group: String) {
        if expandedGroups.contains(group) {
            expandedGroups.remove(group)
        } else {
            expandedGroups.insert(group)
        }
    }
    
    private func refreshExpandedGroups() {
        let available = Set(groupedFilteredSavedDevices.map(\.group))
        if available.isEmpty {
            expandedGroups = []
            return
        }
        if expandedGroups.isEmpty {
            expandedGroups = available
            return
        }
        expandedGroups = expandedGroups.intersection(available)
        if expandedGroups.isEmpty {
            expandedGroups = available
        }
    }
    
    @ViewBuilder
    private func deviceRow(_ device: TerminalDeviceEntry) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTheme.accentColor.opacity(selectedTheme.isLight ? 0.16 : 0.24))
                    .frame(width: 28, height: 28)
                Image(systemName: "terminal")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selectedTheme.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(device.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selectedTheme.foregroundColor)
                    .lineLimit(1)
                Text("\(device.connectionType.lowercased()), \(device.username.isEmpty ? "sem user" : device.username)")
                    .font(.system(size: 10))
                    .foregroundStyle(selectedTheme.mutedColor)
                Text("\(device.host):\(device.port)")
                    .font(.system(size: 10))
                    .foregroundStyle(selectedTheme.mutedColor)
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
        .background(selectedDeviceID == device.id ? selectedTheme.accentColor.opacity(selectedTheme.isLight ? 0.14 : 0.18) : selectedTheme.cardBackgroundColor.opacity(selectedTheme.isLight ? 0.82 : 0.32))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(selectedDeviceID == device.id ? selectedTheme.accentColor.opacity(0.55) : selectedTheme.panelBorderColor.opacity(selectedTheme.isLight ? 0.3 : 0.45), lineWidth: 1)
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
    var groupName: String
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
    var groupName: String
    var connectionType: String
    var host: String
    var port: String
    var username: String
    var notes: String
    var credentialID: String
    
    static let storageKey = "terminal.device.cache.v3"
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case groupName
        case connectionType
        case host
        case port
        case username
        case notes
        case credentialID
    }
    
    init(id: UUID, name: String, groupName: String, connectionType: String, host: String, port: String, username: String, notes: String, credentialID: String) {
        self.id = id
        self.name = name
        self.groupName = groupName
        self.connectionType = connectionType
        self.host = host
        self.port = port
        self.username = username
        self.notes = notes
        self.credentialID = credentialID
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        groupName = try container.decodeIfPresent(String.self, forKey: .groupName) ?? "Geral"
        connectionType = try container.decode(String.self, forKey: .connectionType)
        host = try container.decode(String.self, forKey: .host)
        port = try container.decode(String.self, forKey: .port)
        username = try container.decode(String.self, forKey: .username)
        notes = try container.decode(String.self, forKey: .notes)
        credentialID = try container.decode(String.self, forKey: .credentialID)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(groupName, forKey: .groupName)
        try container.encode(connectionType, forKey: .connectionType)
        try container.encode(host, forKey: .host)
        try container.encode(port, forKey: .port)
        try container.encode(username, forKey: .username)
        try container.encode(notes, forKey: .notes)
        try container.encode(credentialID, forKey: .credentialID)
    }
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
    let availableGroups: [String]
    let onSave: (TerminalDevicePayload) -> Void
    
    @State private var name = ""
    @State private var connectionType: TerminalView.ConnectionType = .ssh
    @State private var groupName = "Geral"
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
                Picker("Grupo/Pasta", selection: $groupName) {
                    ForEach(availableGroups, id: \.self) { group in
                        Text(group).tag(group)
                    }
                }
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
                            groupName: groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Geral" : groupName,
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
            if let firstGroup = availableGroups.first {
                groupName = firstGroup
            }
            guard let device = deviceToEdit else { return }
            name = device.name
            connectionType = TerminalView.ConnectionType(rawValue: device.connectionType) ?? .ssh
            groupName = device.groupName
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

private struct TerminalDeviceGroupFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    
    let onSave: (String) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Nova Pasta")
                .font(.title3.bold())
            
            Form {
                TextField("Nome da pasta", text: $name)
            }
            .formStyle(.grouped)
            
            HStack {
                Spacer()
                Button("Cancelar", role: .cancel) {
                    dismiss()
                }
                Button("Salvar") {
                    onSave(name)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 360)
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

private enum TerminalDeviceGroupStore {
    static let storageKey = "terminal.group.cache.v1"
}

private enum TerminalThemeStore {
    static let storageKey = "terminal.theme.selected.v1"
    
    static func readThemeID() -> String {
        UserDefaults.standard.string(forKey: storageKey) ?? TerminalTheme.defaultTheme.rawValue
    }
    
    static func saveThemeID(_ themeID: String) {
        UserDefaults.standard.set(themeID, forKey: storageKey)
    }
}

private struct TerminalDeviceRegistryPayload: Codable {
    let version: Int
    let exportedAt: Date
    let includesPasswords: Bool
    let groups: [String]
    let devices: [TerminalDeviceEntry]
}

private struct TerminalDeviceRegistryDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var text: String
    
    init(text: String = "") {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
