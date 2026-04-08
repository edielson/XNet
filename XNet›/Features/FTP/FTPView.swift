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
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Premium Unified Header
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("File Transfer")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text(connectionManager.isConnected ? "Connected to \(host)" : "Enter server details to explore files")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Picker("", selection: $transferProtocol) {
                            Text("SFTP").tag(TransferProtocolType.sftp)
                            Text("FTP").tag(TransferProtocolType.ftp)
                            Text("SCP").tag(TransferProtocolType.scp)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 170)
                        .onChange(of: transferProtocol) { _, newValue in
                            switch newValue {
                            case .sftp, .scp:
                                port = "22"
                            case .ftp:
                                port = "21"
                            }
                        }
                        
                        Button(action: toggleConnection) {
                            HStack {
                                Image(systemName: connectionManager.isConnected ? "stop.fill" : "bolt.fill")
                                Text(connectionManager.isConnected ? "Disconnect" : "Connect")
                            }
                            .frame(width: 100)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(connectionManager.isConnected ? .red : .blue)
                        .disabled(host.isEmpty)
                    }
                }
                
                // Connection Input Bar
                HStack(spacing: 16) {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "server.rack")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 10))
                            TextField("Host", text: $host)
                                .textFieldStyle(.plain)
                                .frame(width: 140)
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
                        
                        Divider().frame(height: 12)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 10))
                            TextField("User", text: $username)
                                .textFieldStyle(.plain)
                                .frame(width: 80)
                        }
                        
                        Divider().frame(height: 12)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "key.fill")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 10))
                            SecureField("Pass", text: $password)
                                .textFieldStyle(.plain)
                                .frame(width: 80)
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
                    
                    if connectionManager.isTransferring {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Transferring...")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(20)
                    }
                }
                
                if !registeredDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text("Dispositivos Cadastrados")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("\(registeredDevices.count)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.primary.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(registeredDevices) { device in
                                    Button {
                                        applyDeviceToFTP(device)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: protocolIcon(device))
                                                .font(.system(size: 11, weight: .semibold))
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(device.name)
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .lineLimit(1)
                                                Text("\(device.host):\(device.port)")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(selectedCredentialID == device.credentialID ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.05))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 32)
            .padding(.bottom, 24)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Dual Pane View
            GeometryReader { geo in
                HStack(spacing: 0) {
                    LocalFileBrowser(manager: connectionManager)
                        .frame(width: geo.size.width / 2)
                    
                    Divider()
                    
                    RemoteFileBrowser(manager: connectionManager)
                        .frame(width: geo.size.width / 2)
                }
            }
            .background(Color.black.opacity(0.02))
        }
        .navigationTitle("")
        .onAppear {
            loadRegisteredDevices()
        }
    }
    
    private func toggleConnection() {
        if connectionManager.isConnected {
            connectionManager.disconnect()
        } else {
            connectionManager.connect(host: host, port: port, user: username, pass: password, protocolType: transferProtocol)
        }
    }
    
    private func loadRegisteredDevices() {
        let descriptor = FetchDescriptor<TerminalDevice>(sortBy: [SortDescriptor(\.name, order: .forward)])
        registeredDevices = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    private func applyDeviceToFTP(_ device: TerminalDevice) {
        selectedCredentialID = device.credentialID
        host = device.host
        username = device.username
        password = FTPPasswordStore.readPassword(credentialID: device.credentialID) ?? ""
        
        let type = device.connectionType.uppercased()
        if type.contains("SCP") {
            transferProtocol = .scp
            port = device.port.isEmpty ? "22" : device.port
        } else if type.contains("FTP") && !type.contains("SFTP") {
            transferProtocol = .ftp
            port = device.port.isEmpty ? "21" : device.port
        } else {
            transferProtocol = .sftp
            port = device.port.isEmpty ? "22" : device.port
        }
    }
    
    private func protocolIcon(_ device: TerminalDevice) -> String {
        let type = device.connectionType.uppercased()
        if type.contains("FTP") && !type.contains("SFTP") {
            return "externaldrive.connected.to.line.below"
        }
        return "lock.shield"
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
