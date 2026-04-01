import SwiftUI

struct ContentView: View {
    @State private var selection: Tool? = .devices
    @StateObject private var updater = XNetUpdater()

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Inventory") {
                    NavigationLink(value: Tool.devices) {
                        Label(Tool.devices.name, systemImage: Tool.devices.icon)
                    }
                    NavigationLink(value: Tool.deviceGroups) {
                        Label(Tool.deviceGroups.name, systemImage: Tool.deviceGroups.icon)
                    }
                }
                
                Section("Diagnostics") {
                    ForEach([Tool.ipScan, Tool.portScan, Tool.ping, Tool.traceroute], id: \.self) { tool in
                        NavigationLink(value: tool) {
                            Label(tool.name, systemImage: tool.icon)
                        }
                    }
                }
                
                Section("Remote Access") {
                    ForEach([Tool.terminal, Tool.ftp], id: \.self) { tool in
                        NavigationLink(value: tool) {
                            Label(tool.name, systemImage: tool.icon)
                        }
                    }
                }
                
                Section("Planning & NetBox") {
                    NavigationLink(value: Tool.netbox) {
                        Label(Tool.netbox.name, systemImage: Tool.netbox.icon)
                    }
                    NavigationLink(value: Tool.subnetCalculator) {
                        Label(Tool.subnetCalculator.name, systemImage: Tool.subnetCalculator.icon)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("XNet")
            .frame(minWidth: 200)
            
        } detail: {
            if let tool = selection {
                DetailContentView(tool: tool)
            } else {
                ContentUnavailableView("Select a Tool",
                                     systemImage: "sidebar.left",
                                     description: Text("Choose a tool from the sidebar to get started."))
            }
        }
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
        .task {
            await updater.checkForUpdates()
        }
    }
}

#Preview {
    ContentView()
}
