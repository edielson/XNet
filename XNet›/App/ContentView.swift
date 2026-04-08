import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selection: Tool? = .home
    @State private var netboxSelection: NetBoxView.NetBoxNavigationItem? = nil
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @StateObject private var updater = XNetUpdater()
    @State private var selectedThemeID = TerminalThemeStore.readThemeID()

    // NetBox Management State
    @State private var showingAddSite = false
    @State private var showingAddDevice = false
    @State private var showingAddPrefix = false
    @State private var showingAddVLANGroup = false
    @State private var showingAddVLAN = false
    
    // Live Queries for Injection
    @Query(sort: \NetBoxSite.name) private var allSites: [NetBoxSite]
    @Query(sort: \NetBoxDevice.name) private var allDevices: [NetBoxDevice]
    @Query(sort: \NetBoxPrefix.cidr) private var allPrefixes: [NetBoxPrefix]
    @Query(sort: \NetBoxVLAN.vid) private var allVLANs: [NetBoxVLAN]
    @Query(sort: \NetBoxVLANGroup.name) private var allVLANGroups: [NetBoxVLANGroup]
    
    private var selectedTheme: TerminalTheme {
        TerminalTheme(rawValue: selectedThemeID) ?? .defaultTheme
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // MARK: - Sidebar (Global Navigation)
            List(selection: $selection) {
                Group {
                    SidebarSection(title: "Geral", icon: "house.fill", color: .blue, theme: selectedTheme) {
                        SidebarNavLink(tool: .home, selection: $selection, theme: selectedTheme)
                    }
                    
                    SidebarSection(title: "Audit", icon: "checkmark.shield.fill", color: .purple, theme: selectedTheme) {
                        SidebarNavLink(tool: .netbox, selection: $selection, theme: selectedTheme)
                    }
                    
                    SidebarSection(title: "Diagnóstico", icon: "network", color: .orange, theme: selectedTheme) {
                        ForEach([Tool.ipScan, Tool.portScan, Tool.ping, Tool.traceroute], id: \.self) { tool in
                            SidebarNavLink(tool: tool, selection: $selection, theme: selectedTheme)
                        }
                    }
                    
                    SidebarSection(title: "Utilitários", icon: "terminal.fill", color: .green, theme: selectedTheme) {
                        SidebarNavLink(tool: .terminal, selection: $selection, theme: selectedTheme)
                        SidebarNavLink(tool: .ftp, selection: $selection, theme: selectedTheme)
                        SidebarNavLink(tool: .subnetCalculator, selection: $selection, theme: selectedTheme)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: [selectedTheme.sidebarTopColor, selectedTheme.sidebarBottomColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("XNet Professional")
            .frame(minWidth: 200)
            
        } detail: {
            // MARK: - Detail Workspace
            Group {
                if let tool = selection {
                    if tool == .netbox {
                        // Custom 3-Column-like layout for NetBox ONLY
                        HStack(spacing: 0) {
                            NetBoxSubNav(selection: $netboxSelection, theme: selectedTheme)
                                .frame(width: 200)
                                .toolbar {
                                    ToolbarItem {
                                        Menu {
                                            Button("New Site") { showingAddSite = true }
                                            Button("New Device") { showingAddDevice = true }
                                            Button("New Prefix") { showingAddPrefix = true }
                                            Divider()
                                            Button("New VLAN Group") { showingAddVLANGroup = true }
                                            Button("New VLAN") { showingAddVLAN = true }
                                        } label: { 
                                            Label("Add Resource", systemImage: "plus") 
                                        }
                                    }
                                }
                            
                            Divider()
                            
                            ZStack {
                                if let subItem = netboxSelection {
                                     NetBoxDetailView(
                                        item: subItem, 
                                        selection: $netboxSelection,
                                        allSites: allSites,
                                        allDevices: allDevices,
                                        allPrefixes: allPrefixes,
                                        allVLANs: allVLANs,
                                        allVLANGroups: allVLANGroups
                                     )
                                } else {
                                    NetBoxDashboardView(theme: selectedTheme)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    } else {
                        DetailContentView(tool: tool)
                    }
                } else {
                    EmptyStateView(theme: selectedTheme)
                }
            }
            .background(
                LinearGradient(
                    colors: [selectedTheme.chromeTopColor, selectedTheme.chromeBottomColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .task {
            await updater.checkForUpdates()
        }
        .onReceive(NotificationCenter.default.publisher(for: TerminalThemeStore.didChangeNotification)) { output in
            if let themeID = output.object as? String {
                selectedThemeID = themeID
            } else {
                selectedThemeID = TerminalThemeStore.readThemeID()
            }
        }
        .sheet(isPresented: $showingAddSite) { AddSiteSheet(isPresented: $showingAddSite) }
        .sheet(isPresented: $showingAddDevice) { AddDeviceSheet(isPresented: $showingAddDevice) }
        .sheet(isPresented: $showingAddPrefix) { AddPrefixSheet(isPresented: $showingAddPrefix) }
        .sheet(isPresented: $showingAddVLANGroup) { AddVLANGroupSheet(isPresented: $showingAddVLANGroup) }
        .sheet(isPresented: $showingAddVLAN) { AddVLANSheet(isPresented: $showingAddVLAN) }
        .alert("Nova Versão Disponível: \(updater.latestVersion)", isPresented: $updater.updateAvailable) {
            Button("Baixar Agora") {
                if let url = URL(string: updater.releaseURL) {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Mais Tarde", role: .cancel) { }
        } message: {
            Text(updater.releaseNotes)
        }
    }
}

// MARK: - Premium UI Components

struct SidebarSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let theme: TerminalTheme
    @ViewBuilder let content: Content
    
    var body: some View {
        Section {
            content
        } header: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color.gradient)
                    .font(.caption)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.mutedColor)
            }
            .padding(.vertical, 4)
        }
    }
}

struct SidebarNavLink: View {
    let tool: Tool
    @Binding var selection: Tool?
    let theme: TerminalTheme
    
    var body: some View {
        NavigationLink(value: tool) {
            HStack(spacing: 12) {
                Image(systemName: tool.icon)
                    .foregroundStyle(selection == tool ? theme.backgroundColor : theme.foregroundColor)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 24)
                
                Text(tool.name)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(selection == tool ? theme.backgroundColor : theme.foregroundColor)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(selection == tool ? theme.accentColor.opacity(theme.isLight ? 0.92 : 0.82) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct EmptyStateView: View {
    let theme: TerminalTheme
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(theme.accentColor.opacity(theme.isLight ? 0.12 : 0.18))
                    .frame(width: 120, height: 120)
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 50))
                    .foregroundStyle(theme.accentColor.gradient)
            }
            
            VStack(spacing: 8) {
                Text("XNet Diagnostics")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(theme.foregroundColor)
                Text("Select a tool from the sidebar to begin auditing your network.")
                    .font(.subheadline)
                    .foregroundStyle(theme.mutedColor)
            }
        }
    }
}

// Netbox Navigation Items - Using the one from NetBoxView
struct NetBoxSubNav: View {
    @Binding var selection: NetBoxView.NetBoxNavigationItem?
    let theme: TerminalTheme
    
    var body: some View {
        List(selection: $selection) {
            Section("Infrastructure") {
                NavigationLink(value: NetBoxView.NetBoxNavigationItem.allSites) {
                    Label("All Sites", systemImage: "building.2.fill")
                }
                NavigationLink(value: NetBoxView.NetBoxNavigationItem.allDevices) {
                    Label("Hardware List", systemImage: "cpu.fill")
                }
            }
            
            Section("Network") {
                NavigationLink(value: NetBoxView.NetBoxNavigationItem.ipam) {
                    Label("Prefixes (L3)", systemImage: "network")
                }
                NavigationLink(value: NetBoxView.NetBoxNavigationItem.vlans) {
                    Label("VLAN Contexts", systemImage: "point.3.connected.trianglepath.dotted")
                }
            }
        }
        .navigationTitle("NetBox Audit")
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [theme.sidebarTopColor, theme.sidebarBottomColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct NetBoxDashboardView: View {
    let theme: TerminalTheme
    
    var body: some View {
        VStack {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 60))
                .foregroundStyle(theme.accentColor.gradient)
            Text("NetBox Core")
                .font(.title)
                .bold()
                .foregroundStyle(theme.foregroundColor)
            Text("Select a category to manage your infrastructure.")
                .foregroundStyle(theme.mutedColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [theme.chromeTopColor, theme.chromeBottomColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct NetBoxDetailView: View {
    let item: NetBoxView.NetBoxNavigationItem
    @Binding var selection: NetBoxView.NetBoxNavigationItem?
    
    let allSites: [NetBoxSite]
    let allDevices: [NetBoxDevice]
    let allPrefixes: [NetBoxPrefix]
    let allVLANs: [NetBoxVLAN]
    let allVLANGroups: [NetBoxVLANGroup]
    
    var body: some View {
        switch item {
        case .allSites: NetBoxSitesDashboard(selection: $selection)
        case .allDevices: NetBoxAllDevicesView(devices: allDevices, selection: $selection)
        case .ipam: NetBoxIPAMDashboard(selection: $selection)
        case .vlans: NetBoxVLANsDashboard(allVLANs: allVLANs, selection: $selection)
        case .site(let id): if let s = allSites.first(where: { $0.id == id }) { SiteDetailView(site: s) }
        case .device(let id): if let d = allDevices.first(where: { $0.id == id }) { DeviceDetailView(device: d) }
        case .prefix(let id): if let p = allPrefixes.first(where: { $0.id == id }) { PrefixDetailView(prefix: p, devicesInSite: p.site?.devices ?? allDevices) }
        case .vlan(let id): if let v = allVLANs.first(where: { $0.id == id }) { VLANDetailView(vlan: v, allDevices: allDevices) }
        case .group(let id): if let g = allVLANGroups.first(where: { $0.id == id }) { VLANGroupDetailView(group: g) }
        }
    }
}

#Preview {
    ContentView()
}
