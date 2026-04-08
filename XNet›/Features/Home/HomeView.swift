import SwiftUI
import Combine
import CoreWLAN
import IOKit.ps

struct HomeView: View {
    @State private var dashboardData = DashboardData()
    @State private var isRefreshing = false
    @State private var selectedThemeID = TerminalThemeStore.readThemeID()
    
    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    
    private var selectedTheme: TerminalTheme {
        TerminalTheme(rawValue: selectedThemeID) ?? .defaultTheme
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                dashboardHero
                    .padding(.top, 32)
                
                sectionTitle("Recursos do Sistema", subtitle: "Monitoramento em tempo real de uso e tráfego")
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 18)], spacing: 18) {
                    MetricCard(
                        title: "Uso de CPU",
                        value: "\(Int(dashboardData.cpuUsage))%",
                        detail: dashboardData.cpuUsage > 80 ? "Uso elevado" : "Operação normal",
                        icon: "cpu",
                        color: dashboardData.cpuUsage > 80 ? .red : .blue,
                        emphasis: dashboardData.cpuUsage / 100
                    )
                    MetricCard(
                        title: "Memória RAM",
                        value: dashboardData.ramUsage,
                        detail: "Memória em uso",
                        icon: "memorychip",
                        color: .purple
                    )
                    MetricCard(
                        title: "Bateria",
                        value: "\(Int(dashboardData.batteryLevel))%",
                        detail: dashboardData.isCharging ? "Carregando" : "Energia atual",
                        icon: dashboardData.batteryIcon,
                        color: dashboardData.batteryColor,
                        emphasis: dashboardData.batteryLevel / 100
                    )
                    MetricCard(
                        title: "Download",
                        value: dashboardData.downloadSpeed,
                        detail: "Tráfego de entrada",
                        icon: "arrow.down.circle.fill",
                        color: .green
                    )
                    MetricCard(
                        title: "Upload",
                        value: dashboardData.uploadSpeed,
                        detail: "Tráfego de saída",
                        icon: "arrow.up.circle.fill",
                        color: .orange
                    )
                }
                
                sectionTitle("Conectividade", subtitle: "Visão rápida dos endereços e interface atual")
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 18)], spacing: 18) {
                    NetworkHighlightCard(
                        title: "IP Local",
                        value: dashboardData.localIP,
                        footnote: "Interface \(dashboardData.interfaceName)",
                        icon: "desktopcomputer",
                        color: .blue
                    )
                    NetworkHighlightCard(
                        title: "IP Público",
                        value: dashboardData.publicIP,
                        footnote: "Conectividade externa",
                        icon: "globe",
                        color: .purple
                    )
                }
                
                sectionTitle("Detalhes da Rede", subtitle: "Resumo operacional da interface ativa")
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 18)], spacing: 18) {
                    DetailPanel(title: "Estado Atual", icon: "bolt.horizontal.circle.fill", color: .blue) {
                        VStack(alignment: .leading, spacing: 10) {
                            StatusPill(label: "Atualização", value: isRefreshing ? "Sincronizando..." : "Ao vivo", color: isRefreshing ? .orange : .green)
                            StatusPill(label: "Interface", value: dashboardData.interfaceName, color: .blue)
                            StatusPill(label: "Wi‑Fi", value: dashboardData.ssid, color: .purple)
                        }
                    }
                    
                    DetailPanel(title: "Configurações", icon: "point.3.connected.trianglepath.dotted", color: .indigo) {
                        VStack(spacing: 0) {
                            InfoRow(label: "Interface Ativa", value: dashboardData.interfaceName, icon: "antenna.radiowaves.left.and.right")
                            Divider().padding(.leading, 44)
                            InfoRow(label: "SSID do Wi‑Fi", value: dashboardData.ssid, icon: "wifi")
                            Divider().padding(.leading, 44)
                            InfoRow(label: "Sub-rede", value: dashboardData.subnetMask, icon: "rectangle.split.3x1")
                            Divider().padding(.leading, 44)
                            InfoRow(label: "Gateway", value: dashboardData.router, icon: "router")
                        }
                    }
                }

                Spacer(minLength: 50)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: [
                    selectedTheme.chromeTopColor,
                    selectedTheme.chromeBottomColor
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear { refreshAll() }
        .onReceive(timer) { _ in refreshAll() }
        .onReceive(NotificationCenter.default.publisher(for: TerminalThemeStore.didChangeNotification)) { output in
            if let themeID = output.object as? String {
                selectedThemeID = themeID
            } else {
                selectedThemeID = TerminalThemeStore.readThemeID()
            }
        }
    }
    
    private var dashboardHero: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Painel de Controle")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(selectedTheme.foregroundColor)
                    Text("Monitoramento em tempo real do sistema, conectividade e tráfego da rede.")
                        .font(.title3)
                        .foregroundStyle(selectedTheme.mutedColor)
                }
                
                Spacer()
                
                HStack(spacing: 10) {
                    HeroBadge(title: "Status", value: isRefreshing ? "Atualizando" : "Online", color: isRefreshing ? .orange : .green)
                    HeroBadge(title: "Rede", value: dashboardData.interfaceName, color: .blue)
                }
            }
            
            HStack(spacing: 14) {
                HeroInfoCard(title: "SSID", value: dashboardData.ssid, icon: "wifi", color: .blue)
                HeroInfoCard(title: "Gateway", value: dashboardData.router, icon: "router", color: .orange)
                HeroInfoCard(title: "Upload/Download", value: "\(dashboardData.uploadSpeed) • \(dashboardData.downloadSpeed)", icon: "arrow.left.arrow.right.circle", color: .purple)
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    selectedTheme.accentColor.opacity(selectedTheme.isLight ? 0.1 : 0.16),
                    selectedTheme.panelBorderColor.opacity(selectedTheme.isLight ? 0.1 : 0.16),
                    selectedTheme.cardBackgroundColor
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(selectedTheme.panelBorderColor.opacity(selectedTheme.isLight ? 0.35 : 0.45), lineWidth: 1)
        )
    }
    
    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(selectedTheme.foregroundColor)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(selectedTheme.mutedColor)
        }
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

struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let icon: String
    let color: Color
    var emphasis: Double? = nil
    
    private var theme: TerminalTheme {
        TerminalTheme(rawValue: TerminalThemeStore.readThemeID()) ?? .defaultTheme
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 42, height: 42)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Spacer()
                if let emphasis {
                    Text("\(Int(emphasis * 100))%")
                        .font(.caption.bold())
                        .foregroundStyle(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(theme.mutedColor)
                Text(value)
                    .font(.title3.bold())
                    .foregroundStyle(theme.foregroundColor)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(theme.mutedColor)
            }
            
            if let emphasis {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(theme.panelBorderColor.opacity(theme.isLight ? 0.18 : 0.28))
                        Capsule()
                            .fill(color.gradient)
                            .frame(width: max(12, proxy.size.width * min(max(emphasis, 0), 1)))
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackgroundColor.opacity(theme.isLight ? 0.94 : 0.68))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(theme.panelBorderColor.opacity(theme.isLight ? 0.35 : 0.45), lineWidth: 1)
        )
    }
}

struct NetworkHighlightCard: View {
    let title: String
    let value: String
    let footnote: String
    let icon: String
    let color: Color
    
    private var theme: TerminalTheme {
        TerminalTheme(rawValue: TerminalThemeStore.readThemeID()) ?? .defaultTheme
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.headline.weight(.bold))
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(theme.mutedColor)
                Spacer()
                Circle()
                    .fill(color.opacity(0.8))
                    .frame(width: 10, height: 10)
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.foregroundColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(footnote)
                .font(.caption)
                .foregroundStyle(theme.mutedColor)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackgroundColor.opacity(theme.isLight ? 0.94 : 0.68))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    let icon: String
    
    private var theme: TerminalTheme {
        TerminalTheme(rawValue: TerminalThemeStore.readThemeID()) ?? .defaultTheme
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .foregroundStyle(theme.accentColor)
            Text(label)
                .foregroundStyle(theme.mutedColor)
            Spacer()
            Text(value)
                .bold()
                .foregroundStyle(theme.foregroundColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct DetailPanel<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    private var theme: TerminalTheme {
        TerminalTheme(rawValue: TerminalThemeStore.readThemeID()) ?? .defaultTheme
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(theme.foregroundColor)
                Spacer()
            }
            content
        }
        .padding(18)
        .background(theme.cardBackgroundColor.opacity(theme.isLight ? 0.9 : 0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(theme.panelBorderColor.opacity(theme.isLight ? 0.35 : 0.45), lineWidth: 1)
        )
    }
}

struct HeroBadge: View {
    let title: String
    let value: String
    let color: Color
    
    private var theme: TerminalTheme {
        TerminalTheme(rawValue: TerminalThemeStore.readThemeID()) ?? .defaultTheme
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(theme.mutedColor)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(theme.cardBackgroundColor.opacity(theme.isLight ? 0.88 : 0.68))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct HeroInfoCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    private var theme: TerminalTheme {
        TerminalTheme(rawValue: TerminalThemeStore.readThemeID()) ?? .defaultTheme
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(theme.mutedColor)
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.foregroundColor)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackgroundColor.opacity(theme.isLight ? 0.88 : 0.64))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct StatusPill: View {
    let label: String
    let value: String
    let color: Color
    
    private var theme: TerminalTheme {
        TerminalTheme(rawValue: TerminalThemeStore.readThemeID()) ?? .defaultTheme
    }
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(theme.mutedColor)
            }
            Spacer()
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(theme.foregroundColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(theme.cardBackgroundColor.opacity(theme.isLight ? 0.82 : 0.45))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
