import SwiftUI
import SwiftData

struct NetBoxView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = "Sites"
    @State private var showingAddSheet = false
    @State private var toastMessage = ""
    @State private var showToast = false
    
    // Form States
    @State private var newName = ""
    @State private var newDesc = ""
    @State private var newType = "Router"
    @State private var selectedSiteID: PersistentIdentifier?
    let deviceTypes = ["Router", "Switch", "Firewall", "Server", "Workstation", "Other"]
    
    @Query(sort: \NetBoxSite.name) private var allSites: [NetBoxSite]
    @Query(sort: \NetBoxDevice.name) private var allDevices: [NetBoxDevice]
    
    var body: some View {
        VStack(spacing: 0) {
            // NATIVE TOOLBAR (Clean 2-Column approach)
            HStack {
                Picker("Category", selection: $selectedTab) {
                    Label("Sites", systemImage: "building.2").tag("Sites")
                    Label("Devices", systemImage: "cpu").tag("Devices")
                    Label("IPAM", systemImage: "network").tag("IPAM")
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
                
                Spacer()
                
                Button {
                    resetForms()
                    showingAddSheet = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Unfolded View logic (2 columns max for clarity)
            ZStack(alignment: .bottom) {
                switch selectedTab {
                case "Sites": NetBoxSitesView()
                case "Devices": NetBoxAllDevicesView(devices: allDevices)
                default: NetBoxIPAMView(allDevices: allDevices)
                }
                
                if showToast {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text(toastMessage).font(.caption).bold()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(.ultraThinMaterial).clipShape(Capsule())
                    .padding(.bottom, 20).transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            VStack(spacing: 20) {
                Text("Add New \(selectedTab.dropLast())").font(.headline)
                Form {
                    if selectedTab == "Sites" {
                        TextField("Site Name", text: $newName)
                        TextField("Address/Description", text: $newDesc)
                    } else if selectedTab == "Devices" {
                        TextField("Hostname", text: $newName)
                        Picker("Type", selection: $newType) {
                            ForEach(deviceTypes, id: \.self) { Text($0) }
                        }
                        Picker("Site", selection: $selectedSiteID) {
                            Text("No Site").tag(nil as PersistentIdentifier?)
                            ForEach(allSites) { site in Text(site.name).tag(site.id as PersistentIdentifier?) }
                        }
                    } else {
                        TextField("CIDR", text: $newName)
                        TextField("Description", text: $newDesc)
                        Picker("Site", selection: $selectedSiteID) {
                            Text("Global").tag(nil as PersistentIdentifier?)
                            ForEach(allSites) { site in Text(site.name).tag(site.id as PersistentIdentifier?) }
                        }
                    }
                }
                HStack {
                    Button("Cancel") { showingAddSheet = false }
                    Spacer()
                    Button("Save") { saveAction() }
                        .buttonStyle(.borderedProminent).disabled(newName.isEmpty)
                }
            }.padding().frame(width: 320)
        }
    }
    
    private func resetForms() {
        newName = ""
        newDesc = ""
        selectedSiteID = nil
    }
    
    private func saveAction() {
        switch selectedTab {
        case "Sites":
            let site = NetBoxSite(name: newName, siteDescription: newDesc)
            modelContext.insert(site)
        case "Devices":
            let site = allSites.first(where: { $0.id == selectedSiteID })
            modelContext.insert(NetBoxDevice(name: newName, deviceType: newType, site: site))
        case "IPAM":
            let site = allSites.first(where: { $0.id == selectedSiteID })
            modelContext.insert(NetBoxPrefix(cidr: newName, prefixDescription: newDesc, site: site))
        default: break
        }
        try? modelContext.save()
        triggerToast("Successfully Saved!")
        showingAddSheet = false
    }
    
    private func triggerToast(_ msg: String) {
        toastMessage = msg
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { showToast = false } }
    }
}

// MARK: - Navigation Wrappers with EDIT SITES Logic
struct NetBoxSitesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NetBoxSite.name) private var sites: [NetBoxSite]
    @State private var selectedSiteID: PersistentIdentifier?
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSiteID) {
                ForEach(sites) { site in
                    NavigationLink(value: site.id) {
                        Label(site.name, systemImage: "building.2.fill")
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            modelContext.delete(site)
                            try? modelContext.save()
                        } label: { Label("Delete Site", systemImage: "trash") }
                    }
                }
            }
            .navigationTitle("Global Sites")
            .listStyle(.sidebar)
        } detail: {
            if let id = selectedSiteID, let site = sites.first(where: { $0.id == id }) {
                SiteDetailView(site: site)
            } else {
                ContentUnavailableView("Nodes Documentation", systemImage: "map", description: Text("Manage PoP sites and hierarchy."))
            }
        }
    }
}

struct NetBoxAllDevicesView: View {
    @Environment(\.modelContext) private var modelContext
    let devices: [NetBoxDevice]
    
    var body: some View {
        List {
            ForEach(devices) { device in
                HStack {
                    Label(device.name, systemImage: "cpu.fill")
                    Spacer()
                    Text(device.deviceType).font(.caption2).padding(4).background(Color.blue.opacity(0.1)).cornerRadius(4)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        modelContext.delete(device)
                        try? modelContext.save()
                    } label: { Label("Delete Hardware", systemImage: "trash") }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}

struct NetBoxIPAMView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NetBoxPrefix.cidr) private var allPrefixes: [NetBoxPrefix]
    @State private var selectedPrefixID: PersistentIdentifier?
    let allDevices: [NetBoxDevice]
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedPrefixID) {
                ForEach(allPrefixes) { prefix in
                    NavigationLink(value: prefix.id) {
                        VStack(alignment: .leading) {
                            Text(prefix.cidr).font(.system(.body, design: .monospaced, weight: .bold))
                            Text(prefix.site?.name ?? "Global Space").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            modelContext.delete(prefix)
                            try? modelContext.save()
                        } label: { Label("Deallocate Prefix", systemImage: "trash") }
                    }
                }
            }
            .navigationTitle("Global IPAM")
            .listStyle(.sidebar)
        } detail: {
            if let id = selectedPrefixID, let prefix = allPrefixes.first(where: { $0.id == id }) {
                PrefixDetailView(prefix: prefix, devicesInSite: prefix.site?.devices ?? allDevices)
            } else {
                ContentUnavailableView("Allocated Space", systemImage: "network", description: Text("Manage your subnet documentation."))
            }
        }
    }
}
