import SwiftUI
import SwiftData

struct InventoryDevicesView: View {
    var body: some View {
        VStack {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            Text("Inventory")
                .font(.title)
                .bold()
            Text("Legacy inventory management. Use NetBox for modern IPAM/DCIM.")
                .foregroundStyle(.secondary)
        }
    }
}
