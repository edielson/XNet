import SwiftUI
import SwiftData

struct NetBoxView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var navigationSelection: NetBoxNavigationItem? = .allSites
    
    // UI Feedback
    @State private var toastMessage = ""
    @State private var showToast = false
    @State private var showingAddSite = false
    @State private var showingAddPrefix = false
    @State private var showingAddDevice = false
    @State private var showingAddVLANGroup = false
    @State private var showingAddVLAN = false
    
    @Query(sort: \NetBoxSite.name) private var allSites: [NetBoxSite]
    @Query(sort: \NetBoxDevice.name) private var allDevices: [NetBoxDevice]
    @Query(sort: \NetBoxVLANGroup.name) private var allVLANGroups: [NetBoxVLANGroup]
    @Query(sort: \NetBoxVLAN.vid) private var allVLANs: [NetBoxVLAN]
    @Query(sort: \NetBoxPrefix.cidr) private var allPrefixes: [NetBoxPrefix]
    
    enum NetBoxNavigationItem: Hashable {
        case allSites, allDevices, ipam, vlans
        case site(PersistentIdentifier), vlan(PersistentIdentifier), prefix(PersistentIdentifier), group(PersistentIdentifier), device(PersistentIdentifier)
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $navigationSelection) {
                Section("Infrastructure") {
                    NavigationLink(value: NetBoxNavigationItem.allSites) { Label("All Sites", systemImage: "building.2.fill") }
                    NavigationLink(value: NetBoxNavigationItem.allDevices) { Label("Hardware List", systemImage: "cpu.fill") }
                }
                Section("IPAM & L2") {
                    NavigationLink(value: NetBoxNavigationItem.ipam) { Label("Prefixes (L3)", systemImage: "network") }
                    NavigationLink(value: NetBoxNavigationItem.vlans) { Label("VLAN Rollout", systemImage: "point.3.connected.trianglepath.dotted") }
                }
                Section("Site Access") {
                    ForEach(allSites) { s in NavigationLink(value: NetBoxNavigationItem.site(s.id)) { Text(s.name) } }
                }
                Section("VLAN Contexts") {
                    ForEach(allVLANGroups) { g in 
                        NavigationLink(value: NetBoxNavigationItem.group(g.id)) { Text(g.name) }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            modelContext.delete(allVLANGroups[index])
                        }
                        try? modelContext.save()
                    }
                }
            }
            .listStyle(.sidebar).navigationTitle("NetBox")
            .toolbar {
                ToolbarItem {
                    Menu {
                        Button("New Site") { showingAddSite = true }; Button("New Device") { showingAddDevice = true }; Button("New Prefix") { showingAddPrefix = true }
                        Divider(); Button("New VLAN Group") { showingAddVLANGroup = true }; Button("New VLAN") { showingAddVLAN = true }
                    } label: { Label("Add Resource", systemImage: "plus") }
                }
            }
        } detail: {
            ZStack(alignment: .bottom) {
                Group {
                    if let selection = navigationSelection {
                        switch selection {
                        case .allSites: NetBoxSitesDashboard(selection: $navigationSelection)
                        case .allDevices: NetBoxAllDevicesView(devices: allDevices, selection: $navigationSelection)
                        case .ipam: NetBoxIPAMDashboard(selection: $navigationSelection)
                        case .vlans: NetBoxVLANsDashboard(allVLANs: allVLANs, selection: $navigationSelection)
                        case .site(let id): if let s = allSites.first(where: { $0.id == id }) { SiteDetailView(site: s) }
                        case .vlan(let id): if let v = allVLANs.first(where: { $0.id == id }) { VLANDetailView(vlan: v, allDevices: allDevices) }
                        case .prefix(let id): if let p = allPrefixes.first(where: { $0.id == id }) { PrefixDetailView(prefix: p, devicesInSite: p.site?.devices ?? allDevices) }
                        case .group(let id): if let g = allVLANGroups.first(where: { $0.id == id }) { VLANGroupDetailView(group: g) }
                        case .device(let id): if let d = allDevices.first(where: { $0.id == id }) { DeviceDetailView(device: d) }
                        }
                    } else { ContentUnavailableView("Resource Audit", systemImage: "square.grid.2x2", description: Text("Manage your network assets.")) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(NSColor.windowBackgroundColor))
            }
        }
        .sheet(isPresented: $showingAddSite) { AddSiteSheet(isPresented: $showingAddSite) }
        .sheet(isPresented: $showingAddDevice) { AddDeviceSheet(isPresented: $showingAddDevice) }
        .sheet(isPresented: $showingAddPrefix) { AddPrefixSheet(isPresented: $showingAddPrefix) }
        .sheet(isPresented: $showingAddVLANGroup) { AddVLANGroupSheet(isPresented: $showingAddVLANGroup) }
        .sheet(isPresented: $showingAddVLAN) { AddVLANSheet(isPresented: $showingAddVLAN) }
    }
}
