import SwiftUI
import SwiftData

struct DeviceDetailView: View {
    let device: NetBoxDevice
    @Environment(\.modelContext) private var modelContext
    @State private var isEditing = false; @State private var editName = ""
    
    var body: some View {
        List {
            Section("Machine Assets") {
                LabeledContent("Hostname", value: device.name)
                LabeledContent("Platform", value: device.deviceType)
                LabeledContent("Physical Location", value: device.site?.name ?? "Global Space")
            }
            
            Section("IP Documented Interfaces") {
                 if device.assignedIPs.isEmpty { Text("No active IP documentation.").italic().foregroundStyle(.secondary) }
                 ForEach(device.assignedIPs) { ip in
                      HStack {
                           Text(ip.address).font(.system(.body, design: .monospaced, weight: .bold))
                           Spacer()
                           Text(ip.interfaceLabel ?? "LAN").font(.caption).foregroundStyle(.blue).padding(2).background(Color.blue.opacity(0.1)).cornerRadius(4)
                      }
                 }
            }
            
            Section("Audit Actions") {
                Button("Edit Hostname") { editName = device.name; isEditing = true }.foregroundStyle(.blue)
                Button(role: .destructive) { modelContext.delete(device); try? modelContext.save() } label: { Label("Decommission Device", systemImage: "trash") }
            }
        }
        .navigationTitle(device.name)
        .sheet(isPresented: $isEditing) {
             VStack(spacing: 20) {
                  Text("Update Machine Asset").font(.headline)
                  Form { TextField("Hostname", text: $editName) }
                  HStack { Button("Cancel") { isEditing = false }; Spacer(); Button("Confirm") { device.name = editName; try? modelContext.save(); isEditing = false }.buttonStyle(.borderedProminent) }
             }.padding().frame(width: 320)
        }
    }
}
