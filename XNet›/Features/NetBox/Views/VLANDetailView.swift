import SwiftUI
import SwiftData

struct VLANDetailView: View {
    let vlan: NetBoxVLAN
    let allDevices: [NetBoxDevice]
    @Environment(\.modelContext) private var modelContext
    @State private var isEditing = false; @State private var ename = ""; @State private var edesc = ""
    
    var body: some View {
        List {
            Section("VLAN Strategy") {
                LabeledContent("VID #", value: "\(vlan.vid)")
                LabeledContent("Name", value: vlan.name)
                LabeledContent("Group", value: vlan.vlanGroup?.name ?? "Ungrouped")
            }
            
            Section("Layer 3 Context") {
                if vlan.prefixes.isEmpty { Text("Logical-only VLAN.").italic().foregroundStyle(.secondary) }
                ForEach(vlan.prefixes) { prefix in
                    VStack(alignment: .leading) {
                        Text(prefix.cidr).font(.system(.body, design: .monospaced, weight: .bold))
                        Text(prefix.prefixDescription).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            
            if !vlan.vlanDescription.isEmpty {
                 Section("Technical Notes") { Text(vlan.vlanDescription).foregroundStyle(.secondary) }
            }
            
            Section("Actions") {
                Button("Edit Details") { ename = vlan.name; edesc = vlan.vlanDescription; isEditing = true }.foregroundStyle(.blue)
            }
        }
        .navigationTitle("VLAN \(vlan.vid)")
        .sheet(isPresented: $isEditing) {
             VStack(spacing: 20) {
                  Text("Edit Virtual LAN").font(.headline)
                  Form { TextField("Name", text: $ename); TextField("Description", text: $edesc) }
                  HStack { Button("Cancel") { isEditing = false }; Spacer(); Button("Update") { vlan.name = ename; vlan.vlanDescription = edesc; try? modelContext.save(); isEditing = false }.buttonStyle(.borderedProminent) }
             }.padding().frame(width: 320)
        }
    }
}
