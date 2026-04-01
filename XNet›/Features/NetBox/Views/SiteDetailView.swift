import SwiftUI
import SwiftData

struct SiteDetailView: View {
    let site: NetBoxSite
    @Environment(\.modelContext) private var modelContext
    
    // Edit States
    @State private var showingEdit = false
    @State private var editedName = ""
    @State private var editedDesc = ""
    
    // Add Resources States
    @State private var showingAddPrefix = false
    @State private var showingAddDevice = false
    @State private var newCidr = ""
    @State private var newPrefixDesc = ""
    @State private var newDeviceName = ""
    @State private var selectedDeviceType = "Router"
    
    let deviceTypes = ["Router", "Switch", "Firewall", "Server", "Workstation", "Other"]
    
    var body: some View {
        List {
            Section {
                LabeledContent("Site Name") {
                    Text(site.name).fontWeight(.semibold)
                }
                LabeledContent("Description") {
                    Text(site.siteDescription.isEmpty ? "No description" : site.siteDescription)
                        .foregroundStyle(.secondary)
                }
                Button("Edit Site Details") {
                    editedName = site.name
                    editedDesc = site.siteDescription
                    showingEdit = true
                }
                .font(.caption).buttonStyle(.borderless)
            } header: {
                Text("General Information").font(.caption).foregroundStyle(.secondary)
            }
            
            Section {
                if site.devices.isEmpty {
                    Text("No devices registered.").font(.callout).foregroundStyle(.secondary).italic()
                }
                ForEach(site.devices.sorted(by: { $0.name < $1.name })) { device in
                    NavigationLink(destination: DeviceEditView(device: device)) {
                        NativeDeviceRow(device: device)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            modelContext.delete(device)
                            try? modelContext.save()
                        } label: { Label("Remove Device", systemImage: "trash") }
                    }
                }
            } header: {
                HStack {
                    Text("Infrastructure Inventory").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button { showingAddDevice = true } label: { Image(systemName: "plus.circle") }.buttonStyle(.plain)
                }
            }
            
            Section {
                if site.prefixes.isEmpty {
                    Text("No subnets prefixes allocated.").font(.callout).foregroundStyle(.secondary).italic()
                }
                ForEach(site.prefixes.sorted(by: { $0.cidr < $1.cidr })) { prefix in
                    NavigationLink(destination: PrefixDetailView(prefix: prefix, devicesInSite: site.devices)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prefix.cidr).font(.system(.body, design: .monospaced, weight: .bold))
                            if !prefix.prefixDescription.isEmpty {
                                Text(prefix.prefixDescription).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("IP Address Management").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button { showingAddPrefix = true } label: { Image(systemName: "plus.circle") }.buttonStyle(.plain)
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .navigationTitle(site.name)
        .sheet(isPresented: $showingEdit) { editSiteSheet }
        .sheet(isPresented: $showingAddDevice) { addDeviceSheet }
        .sheet(isPresented: $showingAddPrefix) { addPrefixSheet }
    }
    
    // MARK: - Sheets Content
    private var editSiteSheet: some View {
        VStack(spacing: 20) {
            Text("Edit Site Details").font(.headline)
            Form {
                TextField("Site Name", text: $editedName)
                TextField("Description", text: $editedDesc)
            }
            HStack {
                Button("Cancel") { showingEdit = false }
                Spacer()
                Button("Update") {
                    site.name = editedName
                    site.siteDescription = editedDesc
                    try? modelContext.save()
                    showingEdit = false
                }.buttonStyle(.borderedProminent)
            }
        }.padding().frame(width: 350)
    }
    
    private var addDeviceSheet: some View {
        VStack(spacing: 20) {
            Text("Hardware Registration").font(.headline)
            Form {
                TextField("Hostname", text: $newDeviceName)
                Picker("Device Type", selection: $selectedDeviceType) {
                    ForEach(deviceTypes, id: \.self) { Text($0) }
                }
            }
            HStack {
                Button("Cancel") { showingAddDevice = false }
                Spacer()
                Button("Add Device") {
                    let dev = NetBoxDevice(name: newDeviceName, deviceType: selectedDeviceType, site: site)
                    modelContext.insert(dev)
                    try? modelContext.save()
                    showingAddDevice = false
                    newDeviceName = ""
                }.buttonStyle(.borderedProminent)
            }
        }.padding().frame(width: 320)
    }
    
    private var addPrefixSheet: some View {
        VStack(spacing: 20) {
            Text("Prefix Allocation").font(.headline)
            Form {
                TextField("CIDR", text: $newCidr)
                TextField("Description", text: $newPrefixDesc)
            }
            HStack {
                Button("Cancel") { showingAddPrefix = false }
                Spacer()
                Button("Allocate") {
                    let pf = NetBoxPrefix(cidr: newCidr, prefixDescription: newPrefixDesc, site: site)
                    modelContext.insert(pf)
                    try? modelContext.save()
                    showingAddPrefix = false
                    newCidr = ""
                    newPrefixDesc = ""
                }.buttonStyle(.borderedProminent)
            }
        }.padding().frame(width: 320)
    }
}

// New sub-view for editing devices
struct DeviceEditView: View {
    let device: NetBoxDevice
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var editedName = ""
    @State private var editedType = ""
    let deviceTypes = ["Router", "Switch", "Firewall", "Server", "Workstation", "Other"]
    
    var body: some View {
        Form {
            Section("Device Configuration") {
                TextField("Hostname", text: $editedName)
                Picker("Model Category", selection: $editedType) {
                    ForEach(deviceTypes, id: \.self) { Text($0) }
                }
            }
            
            Section("Network Assignments") {
                if device.assignedIPs.isEmpty {
                    Text("No IP addresses assigned.").foregroundStyle(.secondary)
                }
                ForEach(device.assignedIPs) { ip in
                    LabeledContent(ip.address, value: ip.interfaceLabel ?? "LAN")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Edit: \(device.name)")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save Changes") {
                    device.name = editedName
                    device.deviceType = editedType
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
        .onAppear {
            editedName = device.name
            editedType = device.deviceType
        }
    }
}

// Restoration of the missing native component
struct NativeDeviceRow: View {
    let device: NetBoxDevice
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(device.name, systemImage: hardwareIcon)
                    .font(.headline)
                Spacer()
                Text(device.deviceType).font(.system(size: 9, weight: .bold)).foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 2).background(Color.blue).cornerRadius(4)
            }
            
            if !device.assignedIPs.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(device.assignedIPs.sorted(by: { $0.address < $1.address })) { ip in
                        HStack(spacing: 4) {
                            Text(ip.interfaceLabel ?? "LAN").font(.system(size: 8, weight: .bold)).foregroundStyle(.white).padding(.horizontal, 4).background(Color.blue.opacity(0.8)).cornerRadius(4)
                            Text(ip.address).font(.system(size: 10, design: .monospaced))
                        }
                        .padding(4).background(Color.black.opacity(0.05)).cornerRadius(6)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var hardwareIcon: String {
        switch device.deviceType {
        case "Firewall": return "shield.fill"
        case "Switch": return "point.3.connected.trianglepath.dotted"
        case "Router": return "server.rack"
        case "Server": return "internaldrive"
        default: return "cpu"
        }
    }
}
