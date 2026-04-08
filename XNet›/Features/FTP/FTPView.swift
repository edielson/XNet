//
//  FTPView.swift
//  XNet›
//

import SwiftUI
import UniformTypeIdentifiers
import SwiftData

struct FTPView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var connectionManager = FTPConnectionManager()
    @State private var registeredDevices: [TerminalDevice] = []
    
    // Connection Settings
    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var password = ""
    @State private var transferProtocol: TransferProtocolType = .sftp
    @State private var selectedCredentialID: String?
    @State private var selectedGroupFilter = "Todos"
    @State private var deviceSearch = ""
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            
            GeometryReader { geo in
                HStack(spacing: 0) {
                    deviceSidebar
                        .frame(width: 320)
                    
                    Divider()
                    
                    HStack(spacing: 0) {
                        LocalFileBrowser(manager: connectionManager)
                            .frame(width: (geo.size.width - 320) / 2)
                        
                        Divider()
                        
                        RemoteFileBrowser(manager: connectionManager)
                            .frame(width: (geo.size.width - 320) / 2)
                    }
                }
            }
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.03), Color.blue.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .background(
            LinearGradient(
                colors: [
                    Color(NSColor.windowBackgroundColor),
                    Color(NSColor.controlBackgroundColor).opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .navigationTitle("")
        .onAppear {
            loadRegisteredDevices()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TerminalDevicesUpdated"))) { _ in
            loadRegisteredDevices()
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("File Transfer")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    HStack(spacing: 8) {
                        Circle()
                            .fill(connectionManager.isConnected ? Color.green : Color.secondary.opacity(0.5))
                            .frame(width: 8, height: 8)
                        Text(connectionManager.isConnected ? "Sessão ativa em \(transferProtocol.rawValue.uppercased()) • \(host)" : "Clique em um dispositivo e conecte automaticamente")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Picker("", selection: $transferProtocol) {
                        Text("SFTP").tag(TransferProtocolType.sftp)
                        Text("FTP").tag(TransferProtocolType.ftp)
                        Text("SCP").tag(TransferProtocolType.scp)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    .onChange(of: transferProtocol) { _, newValue in
                        updatePort(for: newValue)
                    }
                    
                    Button(action: toggleConnection) {
                        HStack {
                            Image(systemName: connectionManager.isConnected ? "stop.fill" : "bolt.fill")
                            Text(connectionManager.isConnected ? "Disconnect" : "Connect")
                        }
                        .frame(width: 110)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(connectionManager.isConnected ? .red : .blue)
                    .disabled(host.isEmpty)
                }
            }
            
            HStack(spacing: 12) {
                connectionField(icon: "server.rack", title: "Host", width: 200) {
                    TextField("Host", text: $host)
                        .textFieldStyle(.plain)
                }
                connectionField(icon: "number", title: "Porta", width: 80) {
                    TextField("Port", text: $port)
                        .textFieldStyle(.plain)
                }
                connectionField(icon: "person.fill", title: "Usuário", width: 140) {
                    TextField("User", text: $username)
                        .textFieldStyle(.plain)
                }
                connectionField(icon: "key.fill", title: "Senha", width: 150) {
                    SecureField("Pass", text: $password)
                        .textFieldStyle(.plain)
                }
                
                Spacer(minLength: 0)
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text(connectionManager.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                    if connectionManager.isTransferring {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Transferindo...")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.blue)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .padding(.bottom, 18)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var deviceSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hosts")
                        .font(.headline)
                    Text("FTP, SFTP e SCP via cadastro")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(filteredRegisteredDevices.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)
            
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("Buscar host, IP ou grupo", text: $deviceSearch)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 14)
            
            HStack(spacing: 10) {
                Menu {
                    ForEach(availableGroupFilters, id: \.self) { group in
                        Button(group) {
                            selectedGroupFilter = group
                        }
                    }
                } label: {
                    Label(selectedGroupFilter, systemImage: "folder")
                        .font(.caption.weight(.semibold))
                }
                .menuStyle(.borderlessButton)
                
                Spacer()
                
                Text("Clique para conectar")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(groupedTransferDevices, id: \.group) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text(group.group)
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Text("\(group.devices.count)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            
                            ForEach(group.devices) { device in
                                transferDeviceCard(device)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .background(
            LinearGradient(
                colors: [Color(NSColor.controlBackgroundColor), Color(NSColor.windowBackgroundColor)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func connectionField<Content: View>(icon: String, title: String, width: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: width, alignment: .leading)
        .background(Color(NSColor.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func transferDeviceCard(_ device: TerminalDevice) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                connectToDevice(device, protocolOverride: preferredProtocol(for: device))
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.16))
                            .frame(width: 34, height: 34)
                        Image(systemName: protocolIcon(device))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(device.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text("\(device.username.isEmpty ? "sem usuário" : device.username) • \(device.host)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("Preferido: \(preferredProtocol(for: device).rawValue.uppercased())")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.blue)
                    }
                    
                    Spacer()
                    
                    if selectedCredentialID == device.credentialID && connectionManager.isConnected && host == device.host {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .buttonStyle(.plain)
            
            HStack(spacing: 6) {
                quickConnectButton("SFTP", protocolType: .sftp, device: device, tint: .blue)
                quickConnectButton("SCP", protocolType: .scp, device: device, tint: .purple)
                quickConnectButton("FTP", protocolType: .ftp, device: device, tint: .orange)
            }
        }
        .padding(12)
        .background(selectedCredentialID == device.credentialID ? Color.accentColor.opacity(0.14) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(selectedCredentialID == device.credentialID ? Color.accentColor.opacity(0.32) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    private func quickConnectButton(_ title: String, protocolType: TransferProtocolType, device: TerminalDevice, tint: Color) -> some View {
        Button {
            connectToDevice(device, protocolOverride: protocolType)
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint.opacity(0.9))
        .controlSize(.mini)
    }
    
    private func toggleConnection() {
        if connectionManager.isConnected {
            connectionManager.disconnect()
        } else {
            connectionManager.connect(host: host, port: port, user: username, pass: password, protocolType: transferProtocol)
        }
    }
    
    private func loadRegisteredDevices() {
        let descriptor = FetchDescriptor<TerminalDevice>(sortBy: [SortDescriptor(\.groupName, order: .forward), SortDescriptor(\.name, order: .forward)])
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        if !rows.isEmpty {
            registeredDevices = rows
        } else if let cached = cachedTransferDevices(), !cached.isEmpty {
            registeredDevices = cached
        } else {
            registeredDevices = []
        }
        if !availableGroupFilters.contains(selectedGroupFilter) {
            selectedGroupFilter = "Todos"
        }
    }
    
    private func applyDeviceToFTP(_ device: TerminalDevice, protocolOverride: TransferProtocolType? = nil) {
        selectedCredentialID = device.credentialID
        host = device.host
        username = device.username
        password = FTPPasswordStore.readPassword(credentialID: device.credentialID) ?? ""
        let resolvedProtocol = protocolOverride ?? preferredProtocol(for: device)
        transferProtocol = resolvedProtocol
        port = resolvedPort(for: device, protocolType: resolvedProtocol)
    }
    
    private func connectToDevice(_ device: TerminalDevice, protocolOverride: TransferProtocolType? = nil) {
        applyDeviceToFTP(device, protocolOverride: protocolOverride)
        if connectionManager.isConnected {
            connectionManager.disconnect()
        }
        connectionManager.connect(host: host, port: port, user: username, pass: password, protocolType: transferProtocol)
    }
    
    private func updatePort(for protocolType: TransferProtocolType) {
        guard let activeDevice = registeredDevices.first(where: { $0.credentialID == selectedCredentialID }) else {
            switch protocolType {
            case .sftp, .scp:
                port = "22"
            case .ftp:
                port = "21"
            }
            return
        }
        port = resolvedPort(for: activeDevice, protocolType: protocolType)
    }
    
    private func preferredProtocol(for device: TerminalDevice) -> TransferProtocolType {
        let type = device.connectionType.uppercased()
        if type.contains("SCP") {
            return .scp
        }
        if type.contains("FTP") && !type.contains("SFTP") {
            return .ftp
        }
        return .sftp
    }
    
    private func resolvedPort(for device: TerminalDevice, protocolType: TransferProtocolType) -> String {
        let trimmedPort = device.port.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPort.isEmpty {
            return trimmedPort
        }
        switch protocolType {
        case .sftp, .scp:
            return "22"
        case .ftp:
            return "21"
        }
    }
    
    private func protocolIcon(_ device: TerminalDevice) -> String {
        let type = device.connectionType.uppercased()
        if type.contains("FTP") && !type.contains("SFTP") {
            return "externaldrive.connected.to.line.below"
        }
        if type.contains("SCP") {
            return "shippingbox.fill"
        }
        return "lock.shield"
    }
    
    private var availableGroupFilters: [String] {
        let names = Set(transferCapableDevices.map { normalizedGroupName($0.groupName) })
        return ["Todos"] + names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    private var transferCapableDevices: [TerminalDevice] {
        registeredDevices.filter {
            !$0.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && $0.connectionType.localizedCaseInsensitiveCompare("Serial") != .orderedSame
        }
    }
    
    private var filteredRegisteredDevices: [TerminalDevice] {
        let search = deviceSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        return transferCapableDevices.filter { device in
            let matchesGroup = selectedGroupFilter == "Todos" || normalizedGroupName(device.groupName) == selectedGroupFilter
            let matchesSearch = search.isEmpty
            || device.name.localizedCaseInsensitiveContains(search)
            || device.host.localizedCaseInsensitiveContains(search)
            || device.username.localizedCaseInsensitiveContains(search)
            || normalizedGroupName(device.groupName).localizedCaseInsensitiveContains(search)
            return matchesGroup && matchesSearch
        }
    }
    
    private var groupedTransferDevices: [(group: String, devices: [TerminalDevice])] {
        let grouped = Dictionary(grouping: filteredRegisteredDevices) { normalizedGroupName($0.groupName) }
        return grouped.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.map { key in
            let devices = (grouped[key] ?? []).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return (group: key, devices: devices)
        }
    }
    
    private func normalizedGroupName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Geral" : trimmed
    }
    
    private func cachedTransferDevices() -> [TerminalDevice]? {
        let decoder = JSONDecoder()
        for key in [TransferDeviceCacheEntry.storageKeyV3, TransferDeviceCacheEntry.storageKeyV2] {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let cached = try? decoder.decode([TransferDeviceCacheEntry].self, from: data),
                  !cached.isEmpty else { continue }
            return cached.map {
                TerminalDevice(
                    name: $0.name,
                    groupName: normalizedGroupName($0.groupName),
                    connectionType: $0.connectionType,
                    host: $0.host,
                    port: $0.port,
                    username: $0.username,
                    notes: $0.notes,
                    credentialID: $0.credentialID
                )
            }
        }
        return nil
    }
}

// MARK: - Models

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let isDirectory: Bool
    let size: Int64
    let path: String
    let date: Date
}

enum SortOption: String, CaseIterable, Identifiable {
    case name = "Name"
    case date = "Date"
    var id: String { self.rawValue }
}

private struct TransferDeviceCacheEntry: Decodable {
    static let storageKeyV3 = "terminal.device.cache.v3"
    static let storageKeyV2 = "terminal.device.cache.v2"
    
    let name: String
    let groupName: String
    let connectionType: String
    let host: String
    let port: String
    let username: String
    let notes: String
    let credentialID: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case groupName
        case connectionType
        case host
        case port
        case username
        case notes
        case credentialID
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        groupName = try container.decodeIfPresent(String.self, forKey: .groupName) ?? "Geral"
        connectionType = try container.decode(String.self, forKey: .connectionType)
        host = try container.decode(String.self, forKey: .host)
        port = try container.decode(String.self, forKey: .port)
        username = try container.decode(String.self, forKey: .username)
        notes = try container.decode(String.self, forKey: .notes)
        credentialID = try container.decode(String.self, forKey: .credentialID)
    }
}

// MARK: - Local Browser

struct LocalFileBrowser: View {
    @Bindable var manager: FTPConnectionManager
    @State private var currentPath: String = NSHomeDirectory()
    @State private var files: [FileItem] = []
    @State private var searchText: String = ""
    @State private var sortOption: SortOption = .name
    
    var body: some View {
        VStack(spacing: 0) {
            // Path Bar
            HStack(spacing: 8) {
                Image(systemName: "folder.badge.gearshape")
                    .foregroundStyle(.blue)
                TextField("Path", text: $currentPath)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { loadFiles() }
                
                Button(action: {
                    let url = URL(fileURLWithPath: currentPath)
                    currentPath = url.deletingLastPathComponent().path
                    loadFiles()
                }) {
                    Image(systemName: "arrow.up.to.line")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)
            .padding(12)
            
            Divider()
            
            // Filter & Sort
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    TextField("Filter...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(6)
                
                Picker("", selection: $sortOption) {
                    ForEach(SortOption.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .frame(width: 80)
                .labelsHidden()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            let filteredFiles = searchText.isEmpty ? files : files.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            let sortedFiles = filteredFiles.sorted {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory && !$1.isDirectory }
                if sortOption == .date {
                    return $0.date > $1.date // Newest first
                } else {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
            }
            List {
                ForEach(sortedFiles) { file in
                    HStack {
                        Image(systemName: file.isDirectory ? "folder.fill" : "doc")
                            .foregroundColor(file.isDirectory ? .blue : .secondary)
                        Text(file.name)
                        Spacer()
                        if !file.isDirectory {
                            Text(formatBytes(file.size))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if file.date != Date.distantPast {
                            Text(formatDate(file.date))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onItemDoubleClick {
                        if file.isDirectory {
                            currentPath = file.path
                            loadFiles()
                        }
                    }
                    // Implement Drag out (Upload)
                    .onDrag {
                        let provider = NSItemProvider(object: file.path as NSString)
                        provider.suggestedName = "UPLOAD:\(file.path)"
                        return provider
                    }
                }
            }
            .onDrop(of: [.plainText], isTargeted: nil) { providers in
                // Accept drop from right side (Download)
                providers.first?.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (item, error) in
                    if let stringData = item as? Data, let path = String(data: stringData, encoding: .utf8), path.starts(with: "DOWNLOAD:") {
                        let remotePath = String(path.dropFirst(9))
                        DispatchQueue.main.async {
                            manager.downloadFile(remotePath: remotePath, localFolder: currentPath)
                        }
                    }
                }
                return true
            }
        }
        .onAppear { loadFiles() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LocalBrowserRefresh"))) { _ in
            loadFiles()
        }
    }
    
    private func loadFiles() {
        let fm = FileManager.default
        do {
            let contents = try fm.contentsOfDirectory(atPath: currentPath)
            var items: [FileItem] = []
            
            for item in contents {
                if item.hasPrefix(".") { continue } // simple skip hidden
                let fullPath = (currentPath as NSString).appendingPathComponent(item)
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: fullPath, isDirectory: &isDir) {
                    let attrs = try? fm.attributesOfItem(atPath: fullPath)
                    let size = attrs?[.size] as? Int64 ?? 0
                    let date = attrs?[.modificationDate] as? Date ?? Date.distantPast
                    items.append(FileItem(name: item, isDirectory: isDir.boolValue, size: size, path: fullPath, date: date))
                }
            }
            
            // Sort dirs first
            files = items.sorted {
                if $0.isDirectory == $1.isDirectory { return $0.name.lowercased() < $1.name.lowercased() }
                return $0.isDirectory && !$1.isDirectory
            }
        } catch {
            print("Local list error: \(error)")
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Remote Browser

struct RemoteFileBrowser: View {
    @Bindable var manager: FTPConnectionManager
    @State private var searchText: String = ""
    @State private var sortOption: SortOption = .name
    
    var body: some View {
        VStack(spacing: 0) {
            // Path Bar
            HStack(spacing: 8) {
                Image(systemName: "network")
                    .foregroundStyle(.purple)
                TextField("Remote Path", text: $manager.remoteCurrentPath)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { manager.loadRemoteFiles() }
                    .disabled(!manager.isConnected)
                
                Button(action: {
                    let path = manager.remoteCurrentPath
                    var parts = path.split(separator: "/")
                    if !parts.isEmpty {
                        parts.removeLast()
                        manager.remoteCurrentPath = parts.isEmpty ? "/" : "/" + parts.joined(separator: "/")
                        manager.loadRemoteFiles()
                    }
                }) {
                    Image(systemName: "arrow.up.to.line")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.plain)
                .disabled(!manager.isConnected)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)
            .padding(12)
            
            Divider()
            
            // Filter & Sort
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    TextField("Filter...", text: $searchText)
                        .textFieldStyle(.plain)
                        .disabled(!manager.isConnected)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(6)
                
                Picker("", selection: $sortOption) {
                    ForEach(SortOption.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .frame(width: 80)
                .labelsHidden()
                .disabled(!manager.isConnected)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            if !manager.isConnected {
                VStack {
                    Spacer()
                    Text("Not Connected")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                let filteredFiles = searchText.isEmpty ? manager.remoteFiles : manager.remoteFiles.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                let sortedFiles = filteredFiles.sorted {
                    if $0.isDirectory != $1.isDirectory { return $0.isDirectory && !$1.isDirectory }
                    if sortOption == .date {
                        return $0.date > $1.date
                    } else {
                        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                }
                List {
                    ForEach(sortedFiles) { file in
                        HStack {
                            Image(systemName: file.isDirectory ? "folder.fill" : "doc")
                                .foregroundColor(file.isDirectory ? .blue : .secondary)
                            Text(file.name)
                            Spacer()
                            if !file.isDirectory {
                                Text(formatBytes(file.size))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if file.date != Date.distantPast {
                                Text(formatDate(file.date))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onItemDoubleClick {
                            if file.isDirectory {
                                manager.remoteCurrentPath = file.path
                                manager.loadRemoteFiles()
                            }
                        }
                        // Implement Drag out (Download)
                        .onDrag {
                            let dragData = "DOWNLOAD:\(file.path)".data(using: .utf8)!
                            let provider = NSItemProvider(item: dragData as NSData, typeIdentifier: UTType.plainText.identifier)
                            return provider
                        }
                    }
                }
                .onDrop(of: [.plainText], isTargeted: nil) { providers in
                    // Accept drop from left side (Upload)
                    providers.first?.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (item, error) in
                        // It might come as a string or data or URL
                        if let str = item as? String, str.starts(with: "UPLOAD:") {
                            let localPath = String(str.dropFirst(7))
                            DispatchQueue.main.async {
                                manager.uploadFile(localPath: localPath, remoteFolder: manager.remoteCurrentPath)
                            }
                        } else if let data = item as? Data, let str = String(data: data, encoding: .utf8), str.starts(with: "UPLOAD:") {
                            let localPath = String(str.dropFirst(7))
                            DispatchQueue.main.async {
                                manager.uploadFile(localPath: localPath, remoteFolder: manager.remoteCurrentPath)
                            }
                        }
                    }
                    return true
                }
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Helper for double click on macOS lists (Requires custom modifier since List row actions are tricky in SwiftUI macOS)
extension View {
    func onItemDoubleClick(action: @escaping () -> Void) -> some View {
        self.onTapGesture(count: 2, perform: action)
    }
}

private enum FTPPasswordStore {
    private static let keyPrefix = "br.com.myrouter.xnet.terminal.password."
    
    static func readPassword(credentialID: String) -> String? {
        UserDefaults.standard.string(forKey: keyPrefix + credentialID)
    }
}
