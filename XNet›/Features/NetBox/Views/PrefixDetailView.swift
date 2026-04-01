import SwiftUI
import SwiftData

struct PrefixDetailView: View {
    let prefix: NetBoxPrefix
    let devicesInSite: [NetBoxDevice]
    
    @Environment(\.modelContext) private var modelContext
    @State private var showingAssign = false
    @State private var showingDeviceSearch = false
    @State private var deviceSearchText = ""
    
    // Form States
    @State private var newIP = ""
    @State private var label = "LAN"
    @State private var usageType = "Device" // "Device" or "Custom"
    @State private var customUsage = ""
    @State private var selectedDeviceID: PersistentIdentifier?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(prefix.cidr).font(.largeTitle).bold()
                    Text(prefix.prefixDescription).font(.subheadline).foregroundStyle(.secondary)
                    Text(prefix.site?.name ?? "Global Space").foregroundStyle(.blue).font(.caption).bold()
                }
                Spacer()
                Button { 
                    prepareAssignment()
                    showingAssign = true 
                } label: {
                    Label("Designate New IP", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            // Allocation List
            List {
                if prefix.ips.isEmpty {
                    ContentUnavailableView("No IP Allocations", systemImage: "network", description: Text("Start assigning IP addresses from this subnet prefix."))
                }
                
                ForEach(prefix.ips.sorted(by: { $0.address < $1.address })) { ip in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(ip.interfaceLabel ?? "LAN")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .background(Color.blue)
                                    .cornerRadius(4)
                                
                                Text(ip.address).font(.system(.body, design: .monospaced, weight: .semibold))
                            }
                            
                            if let device = ip.device {
                                Label("\(device.name) (\(device.deviceType))", systemImage: "desktopcomputer")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else if let note = ip.usageDescription, !note.isEmpty {
                                Text(note).font(.caption).foregroundStyle(.orange)
                            }
                        }
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            modelContext.delete(ip)
                            try? modelContext.save()
                        } label: {
                            Image(systemName: "trash").font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .sheet(isPresented: $showingAssign) {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Image(systemName: "ipaddress.fill-standard").font(.largeTitle).foregroundStyle(.blue.gradient)
                    Text("IP Designation").font(.headline)
                    Text("Allocating address from \(prefix.cidr)").font(.caption2).foregroundStyle(.secondary)
                }.padding(.top)
                
                VStack(spacing: 12) {
                    TextField("IP Address (e.g. 10.0.0.5)", text: $newIP).textFieldStyle(.roundedBorder)
                    TextField("Interface Label (WAN, LAN, Loopback...)", text: $label).textFieldStyle(.roundedBorder)
                    
                    Picker("Allocation Type", selection: $usageType) {
                        Text("Link to Device").tag("Device")
                        Text("Manual Description").tag("Custom")
                    }.pickerStyle(.segmented)
                    
                    if usageType == "Device" {
                        // SEARCHABLE DEVICE SELECTOR (Jobs Style)
                        Button {
                            showingDeviceSearch = true
                        } label: {
                            HStack {
                                if let selectedDev = devicesInSite.first(where: { $0.id == selectedDeviceID }) {
                                    Image(systemName: "desktopcomputer").foregroundStyle(.blue)
                                    Text(selectedDev.name)
                                } else {
                                    Text("Select Physical Device...").foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(8).background(Color.black.opacity(0.05)).cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showingDeviceSearch) {
                            DeviceSelector(devices: devicesInSite, searchText: $deviceSearchText) { dev in
                                selectedDeviceID = dev.id
                                showingDeviceSearch = false
                            }
                            .frame(width: 300, height: 400)
                        }
                    } else {
                        TextField("Text Note (e.g. Fixed IP Client X)", text: $customUsage).textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.horizontal)
                
                HStack {
                    Button("Cancel") { showingAssign = false }
                    Spacer()
                    Button("Designate IP") {
                        saveAssignment()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newIP.isEmpty || (usageType == "Device" && selectedDeviceID == nil))
                }
                .padding()
            }
            .frame(width: 350)
        }
    }
    
    private func prepareAssignment() {
        if let lastIP = prefix.ips.sorted(by: { $0.address < $1.address }).last?.address {
            let parts = lastIP.split(separator: ".")
            if parts.count == 4, let lastOctet = Int(parts[3]) {
                newIP = "\(parts[0]).\(parts[1]).\(parts[2]).\(lastOctet + 1)"
            } else {
                newIP = prefix.cidr.split(separator: "/").first?.description ?? ""
            }
        } else {
            newIP = prefix.cidr.split(separator: "/").first?.description ?? ""
        }
    }
    
    private func saveAssignment() {
        let device = (usageType == "Device") ? devicesInSite.first(where: { $0.id == selectedDeviceID }) : nil
        let entry = NetBoxIP(address: newIP, interfaceLabel: label, usageDescription: customUsage, prefix: prefix, device: device)
        modelContext.insert(entry)
        
        do {
            try modelContext.save()
            showingAssign = false
            // Reset states
            customUsage = ""
            selectedDeviceID = nil
            label = "LAN"
        } catch {
            print("Failed to save assignment: \(error)")
        }
    }
}

// MARK: - Premium Device Selector Component
struct DeviceSelector: View {
    let devices: [NetBoxDevice]
    @Binding var searchText: String
    let onSelect: (NetBoxDevice) -> Void
    
    var filteredDevices: [NetBoxDevice] {
        if searchText.isEmpty { return devices }
        return devices.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search 500+ devices...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .buttonStyle(.plain)
                }
            }
            .padding(8).background(Color.black.opacity(0.05)).cornerRadius(8).padding()
            
            Divider()
            
            // Device List
            List {
                ForEach(filteredDevices) { dev in
                    Button {
                        onSelect(dev)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "cpu").foregroundStyle(.blue.gradient)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dev.name).bold()
                                Text("\(dev.deviceType) • \(dev.site?.name ?? "Global")").font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle").foregroundStyle(.secondary).font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)
        }
    }
}
