import SwiftUI
import SwiftData

struct VLANGroupDetailView: View {
    let group: NetBoxVLANGroup
    @Environment(\.modelContext) private var modelContext
    @State private var isEditing = false; @State private var ename = ""; @State private var emin = ""; @State private var emax = ""
    
    var body: some View {
        List {
            Section("Group Boundaries") {
                LabeledContent("Group Name", value: group.name)
                LabeledContent("Range (ID)", value: "\(group.minVID) - \(group.maxVID)")
            }
            
            Section("VLAN Allocation Map") {
                 if group.vlans.isEmpty { Text("Range is empty.").italic().foregroundStyle(.secondary) }
                 ForEach(group.vlans) { vlan in
                      HStack {
                           Text("\(vlan.vid)").font(.system(size: 10, weight: .bold)).foregroundStyle(.white).padding(4).background(Color.purple).cornerRadius(4)
                           Text(vlan.name)
                           Spacer()
                      }
                 }
            }
            
            Section("Range Actions") {
                Button("Modify Range Constraints") { 
                    ename = group.name; emin = "\(group.minVID)"; emax = "\(group.maxVID)"; isEditing = true 
                }.foregroundStyle(.blue)
                Button(role: .destructive) { modelContext.delete(group); try? modelContext.save() } label: { Label("Delete Group", systemImage: "trash") }
            }
        }
        .navigationTitle(group.name)
        .sheet(isPresented: $isEditing) {
             VStack(spacing: 20) {
                  Text("Edit Group Constraints").font(.headline)
                  Form { 
                       TextField("Group Name", text: $ename)
                       TextField("Min VID", text: $emin); TextField("Max VID", text: $emax) 
                  }
                  HStack { 
                       Button("Cancel") { isEditing = false }; Spacer()
                       Button("Save") { 
                            group.name = ename; group.minVID = Int(emin) ?? 1; group.maxVID = Int(emax) ?? 4094; try? modelContext.save(); isEditing = false 
                       }.buttonStyle(.borderedProminent) 
                  }
             }.padding().frame(width: 320)
        }
    }
}
