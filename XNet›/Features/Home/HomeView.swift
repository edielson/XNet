import SwiftUI
import Combine
import CoreWLAN
import IOKit.ps

struct HomeView: View {
    @State private var dashboardData = DashboardData()
    @State private var isRefreshing = false
    
    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Painel de Controle")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Monitoramento real de hardware e rede.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                
                // Section 1: System Vitals
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recursos do Sistema")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        VitalsCard(title: "Uso de CPU", value: "\(Int(dashboardData.cpuUsage))%", icon: "cpu", color: dashboardData.cpuUsage > 80 ? .red : .blue)
                        VitalsCard(title: "Memória RAM", value: dashboardData.ramUsage, icon: "memorychip", color: .purple)
                        VitalsCard(title: "Bateria", value: "\(Int(dashboardData.batteryLevel))%", icon: dashboardData.batteryIcon, color: dashboardData.batteryColor)
                        VitalsCard(title: "Download", value: dashboardData.downloadSpeed, icon: "arrow.down.circle.fill", color: .green)
                        VitalsCard(title: "Upload", value: dashboardData.uploadSpeed, icon: "arrow.up.circle.fill", color: .orange)
                    }
                }
                
                // Section 2: IPs & Connectivity
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    NetworkingCard(title: "IP Local (\(dashboardData.interfaceName))", value: dashboardData.localIP, icon: "desktopcomputer", color: .blue)
                    NetworkingCard(title: "IP Público", value: dashboardData.publicIP, icon: "globe", color: .purple)
                }
                
                // Section 3: Detailed Network Config
                VStack(alignment: .leading, spacing: 20) {
                    Text("Configurações de Rede")
                        .font(.title2)
                        .bold()
                    
                    VStack(spacing: 0) {
                        InfoRow(label: "Interface Ativa", value: dashboardData.interfaceName, icon: "antenna.radiowaves.left.and.right")
                        Divider().padding(.leading, 44)
                        InfoRow(label: "SSID do Wi-Fi", value: dashboardData.ssid, icon: "wifi")
                        Divider().padding(.leading, 44)
                        InfoRow(label: "Sub-rede", value: dashboardData.subnetMask, icon: "rectangle.split.3x1")
                        Divider().padding(.leading, 44)
                        InfoRow(label: "Roteador Default", value: dashboardData.router, icon: "router")
                    }
                    .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                }
                
                Spacer(minLength: 50)
            }
            .padding(.horizontal, 40)
        }
        .onAppear { refreshAll() }
        .onReceive(timer) { _ in refreshAll() }
    }
    
    private func refreshAll() {
        isRefreshing = true
        Task {
            let current = dashboardData
            let updated = await current.getUpdated()
            await MainActor.run {
                self.dashboardData = updated
                self.isRefreshing = false
            }
        }
    }
}

// MARK: - Components

struct VitalsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .bold()
            }
            Spacer()
        }
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
    }
}

struct NetworkingCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.headline)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .foregroundStyle(.blue)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Model & Logic

struct DashboardData {
    // Network
    var localIP: String = "---"
    var subnetMask: String = "---"
    var publicIP: String = "---"
    var interfaceName: String = "---"
    var ssid: String = "---"
    var router: String = "---"
    
    // System
    var cpuUsage: Double = 0.0
    var ramUsage: String = "---"
    var batteryLevel: Double = 0.0
    var isCharging: Bool = false
    
    // Traffic
    var downloadSpeed: String = "0 KB/s"
    var uploadSpeed: String = "0 KB/s"
    private var lastInBytes: UInt64 = 0
    private var lastOutBytes: UInt64 = 0
    private var lastTrafficTime: Double = CFAbsoluteTimeGetCurrent()
    private var lastCPUTime: host_cpu_load_info?
    
    var batteryColor: Color {
        if batteryLevel < 20 { return .red }
        if batteryLevel < 50 { return .orange }
        return .green
    }
    
    var batteryIcon: String {
        if isCharging { return "battery.100.bolt" }
        if batteryLevel < 20 { return "battery.25" }
        return "battery.100"
    }
    
    func getUpdated() async -> DashboardData {
        var copy = self
        
        // 1. CPU Real
        let (usage, loadInfo) = copy.calculateCPUUsage()
        copy.cpuUsage = usage
        copy.lastCPUTime = loadInfo
        
        // 2. RAM Real
        copy.ramUsage = copy.getRAMUsage()
        
        // 3. Bateria Real
        let (level, charging) = copy.getBatteryInfo()
        copy.batteryLevel = level
        copy.isCharging = charging
        
        // 4. Rede Real & Tráfego
        let wifi = CWWiFiClient.shared().interface()
        copy.interfaceName = wifi?.interfaceName ?? "en0"
        copy.ssid = wifi?.ssid() ?? "Ethernet / Outro"
        
        let networkDetails = copy.getNetworkDetails(for: copy.interfaceName)
        copy.localIP = networkDetails.ip
        copy.subnetMask = networkDetails.mask
        copy.router = copy.getGatewayAddress()
        
        // Calcular Velocidade
        let now = CFAbsoluteTimeGetCurrent()
        let interval = now - copy.lastTrafficTime
        if interval > 0 && copy.lastInBytes > 0 {
            let inDiffBytes = Double(networkDetails.inBytes >= copy.lastInBytes ? networkDetails.inBytes - copy.lastInBytes : 0)
            let outDiffBytes = Double(networkDetails.outBytes >= copy.lastOutBytes ? networkDetails.outBytes - copy.lastOutBytes : 0)
            
            let inBitsPerSec = (inDiffBytes * 8.0) / interval
            let outBitsPerSec = (outDiffBytes * 8.0) / interval
            
            copy.downloadSpeed = copy.formatSpeed(inBitsPerSec)
            copy.uploadSpeed = copy.formatSpeed(outBitsPerSec)
        }
        
        copy.lastInBytes = networkDetails.inBytes
        copy.lastOutBytes = networkDetails.outBytes
        copy.lastTrafficTime = now
        
        if let pubIP = await copy.fetchPublicIP() {
            copy.publicIP = pubIP
        }
        
        return copy
    }
    
    private func formatSpeed(_ bitsPerSecond: Double) -> String {
        if bitsPerSecond < 1000 { return String(format: "%.0f bps", bitsPerSecond) }
        let kbps = bitsPerSecond / 1000
        if kbps < 1000 { return String(format: "%.1f Kbps", kbps) }
        let mbps = kbps / 1000
        return String(format: "%.1f Mbps", mbps)
    }
    
    // --- Lógica de Baixo Nível (Sem Mock) ---
    
    private func getRAMUsage() -> String {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            let used = UInt64(stats.active_count + stats.inactive_count + stats.wire_count) * pageSize
            return String(format: "%.1f GB", Double(used) / (1024 * 1024 * 1024))
        }
        return "---"
    }
    
    private func calculateCPUUsage() -> (usage: Double, loadInfo: host_cpu_load_info) {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            if let lastLoad = lastCPUTime {
                let userDiff = Double(cpuLoad.cpu_ticks.0 - lastLoad.cpu_ticks.0)
                let sysDiff = Double(cpuLoad.cpu_ticks.1 - lastLoad.cpu_ticks.1)
                let idleDiff = Double(cpuLoad.cpu_ticks.2 - lastLoad.cpu_ticks.2)
                let niceDiff = Double(cpuLoad.cpu_ticks.3 - lastLoad.cpu_ticks.3)
                
                let total = userDiff + sysDiff + idleDiff + niceDiff
                let usage = total > 0 ? (userDiff + sysDiff + niceDiff) / total * 100.0 : 0.0
                return (usage, cpuLoad)
            } else {
                return (5.0, cpuLoad)
            }
        }
        return (0.0, cpuLoad)
    }
    
    private func getBatteryInfo() -> (Double, Bool) {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        for source in sources {
            if let description = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] {
                let current = description[kIOPSCurrentCapacityKey] as? Double ?? 0
                let max = description[kIOPSMaxCapacityKey] as? Double ?? 100
                let charging = description[kIOPSIsChargingKey] as? Bool ?? false
                return (current / max * 100.0, charging)
            }
        }
        return (0, false)
    }
    
    private func getNetworkDetails(for interfaceName: String) -> (ip: String, mask: String, inBytes: UInt64, outBytes: UInt64) {
        var ip = "---"
        var mask = "---"
        var inBytes: UInt64 = 0
        var outBytes: UInt64 = 0
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return (ip, mask, 0, 0) }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let name = String(cString: ptr.pointee.ifa_name)
            guard name == interfaceName else { continue }
            
            let addr = ptr.pointee.ifa_addr.pointee
            if addr.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    ip = String(cString: hostname)
                }
                if let netmask = ptr.pointee.ifa_netmask {
                    var maskname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(netmask, socklen_t(addr.sa_len), &maskname, socklen_t(maskname.count), nil, 0, NI_NUMERICHOST) == 0 {
                        mask = String(cString: maskname)
                    }
                }
            } else if addr.sa_family == UInt8(AF_LINK) {
                // No macOS, estatísticas de interface ficam em if_data (AF_LINK)
                if let data = ptr.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) {
                    inBytes = UInt64(data.pointee.ifi_ibytes)
                    outBytes = UInt64(data.pointee.ifi_obytes)
                }
            }
        }
        freeifaddrs(ifaddr)
        return (ip, mask, inBytes, outBytes)
    }
    
    private func getGatewayAddress() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/route")
        process.arguments = ["-n", "get", "default"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return "---"
        }
        
        guard process.terminationStatus == 0 else { return "---" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return "---" }
        for line in output.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("gateway:") {
                let value = trimmed.replacingOccurrences(of: "gateway:", with: "").trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? "---" : value
            }
        }
        return "---"
    }
    
    private func fetchPublicIP() async -> String? {
        guard let url = URL(string: "https://api.ipify.org") else { return nil }
        if let (data, _) = try? await URLSession.shared.data(from: url) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
