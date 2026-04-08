import SwiftUI
import SwiftData

@main
struct XNet_App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            NetBoxSite.self, 
            NetBoxPrefix.self, 
            NetBoxIP.self, 
            NetBoxDevice.self,
            NetBoxVLANGroup.self,
            NetBoxVLAN.self,
            TerminalDevice.self
        ])
    }
}
