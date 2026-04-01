import SwiftUI
import SwiftData

struct SiteDetailView: View {
    let site: NetBoxSite
    @Environment(\.modelContext) private var modelContext
    @State private var isEditing = false; @State private var ename = ""; @State private var edesc = ""
    
    var body: some View {
        List {
            Section("Physical Context") {
                LabeledContent("Site Name", value: site.name)
                LabeledContent("Inventory", value: "\(site.devices.count) Hardware Units")
                LabeledContent("Subnets", value: "\(site.prefixes.count) Subnet Prefixes")
            }
            
            Section("Devices in Site") {
                if site.devices.isEmpty { Text("No physical machines.").italic().foregroundStyle(.secondary) }
                ForEach(site.devices) { dev in
                    HStack {
                        Image(systemName: "cpu").foregroundStyle(.blue.gradient)
                        VStack(alignment: .leading) { Text(dev.name).bold(); Text(dev.deviceType).font(.caption).foregroundStyle(.secondary) }
                        Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("Local Networks") {
                 if site.prefixes.isEmpty { Text("No prefixes in site.").italic().foregroundStyle(.secondary) }
                 ForEach(site.prefixes) { p in
                      VStack(alignment: .leading) {
                           Text(p.cidr).font(.system(.body, design: .monospaced, weight: .bold))
                           Text(p.prefixDescription).font(.caption).foregroundStyle(.secondary)
                      }
                 }
            }
            
            if !site.siteDescription.isEmpty {
                Section("Technical Context") { Text(site.siteDescription).foregroundStyle(.secondary) }
            }
            
            Section("Actions") {
                Button("Edit Site Details") { ename = site.name; edesc = site.siteDescription; isEditing = true }.foregroundStyle(.blue)
            }
        }
        .navigationTitle(site.name)
        .sheet(isPresented: $isEditing) {
            VStack(spacing: 20) {
                  Text("Edit Physical Site").font(.headline)
                  Form { TextField("Name", text: $ename); TextField("Description", text: $edesc) }
                  HStack { Button("Cancel") { isEditing = false }; Spacer(); Button("Update") { site.name = ename; site.siteDescription = edesc; try? modelContext.save(); isEditing = false }.buttonStyle(.borderedProminent) }
             }.padding().frame(width: 320)
        }
    }
}
