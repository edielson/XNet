import SwiftUI
import SwiftData

struct NetBoxView: View {
    @Environment(\.modelContext) private var modelContext
    
    enum NetBoxNavigationItem: Hashable {
        case allSites, allDevices, ipam, vlans
        case site(PersistentIdentifier), vlan(PersistentIdentifier), prefix(PersistentIdentifier), group(PersistentIdentifier), device(PersistentIdentifier)
    }
    
    @Query(sort: \NetBoxSite.name) private var allSites: [NetBoxSite]
    @Query(sort: \NetBoxDevice.name) private var allDevices: [NetBoxDevice]
    @Query(sort: \NetBoxPrefix.cidr) private var allPrefixes: [NetBoxPrefix]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Dashboard Header
                HeaderView(title: "NetBox Audit", subtitle: "Infrastructure and IPAM Management")
                
                // Asset Overview Grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 20) {
                    AssetCard(title: "Deployment Sites", count: allSites.count, icon: "building.2.fill", color: .purple)
                    AssetCard(title: "Total Devices", count: allDevices.count, icon: "cpu.fill", color: .blue)
                    AssetCard(title: "IP Prefixes", count: allPrefixes.count, icon: "network", color: .green)
                }
                
                // Detailed Breakdown Section
                VStack(alignment: .leading, spacing: 20) {
                    Text("Infrastructure Health")
                        .font(.title3)
                        .bold()
                    
                    HStack(spacing: 20) {
                        QuickMetric(title: "Active VLANs", value: "14", trend: "+2 this week")
                        QuickMetric(title: "Usage (L3)", value: "62%", trend: "Stable")
                        QuickMetric(title: "Rack Units", value: "24U Used", trend: "4U Free")
                    }
                }
            }
            .padding(32)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct HeaderView: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 34, weight: .bold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct AssetCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Spacer()
                Image(systemName: "arrow.up.right.circle.fill")
                    .foregroundStyle(.secondary.opacity(0.3))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(count)")
                    .font(.system(size: 28, weight: .bold))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

struct QuickMetric: View {
    let title: String
    let value: String
    let trend: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2)
                .bold()
                .foregroundStyle(.secondary)
                .kerning(1)
            Text(value)
                .font(.title2)
                .bold()
            Text(trend)
                .font(.caption)
                .foregroundStyle(.green)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}
