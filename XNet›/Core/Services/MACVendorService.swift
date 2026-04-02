import Foundation

actor MACVendorService {
    static let shared = MACVendorService()
    
    private var cache: [String: String] = [:]
    
    private let vendors: [String: String] = [
        // Apple
        "44:D8:84": "Apple", "A8:61:95": "Apple", "C0:3E:BA": "Apple", "D4:F4:6F": "Apple", 
        "F0:99:B6": "Apple", "FC:2A:9C": "Apple", "00:03:93": "Apple", "00:0A:27": "Apple", 
        "00:0D:93": "Apple", "00:10:FA": "Apple", "00:14:51": "Apple", "00:16:D4": "Apple", 
        "00:17:F2": "Apple", "00:19:E3": "Apple", "00:1B:63": "Apple", "00:1C:B3": "Apple", 
        "28:CF:E9": "Apple", "34:15:9E": "Apple", "40:30:04": "Apple", "AC:87:A3": "Apple",
        
        // Network Infrastructure & Chips
        "00:E0:4C": "Realtek", "00:1D:60": "Intel", "00:21:5C": "Intel", "00:1A:3F": "Intel",
        "A4:34:D9": "Intel", "68:5D:43": "Intel", "00:10:18": "Broadcom", "00:1B:E9": "Broadcom",
        "00:03:7F": "Atheros", "00:13:74": "Atheros",
        
        // Networking Brands (Pro & Consumer)
        "04:18:D6": "Ubiquiti", "24:A4:3C": "Ubiquiti", "44:D9:E7": "Ubiquiti", "68:72:51": "Ubiquiti", 
        "70:A7:41": "Ubiquiti", "74:83:C2": "Ubiquiti", "80:2A:A8": "Ubiquiti", "AC:8B:A9": "Ubiquiti",
        "4C:5E:0C": "Mikrotik", "E4:8D:8C": "Mikrotik", "6C:3B:6B": "Mikrotik", "D4:CA:6D": "Mikrotik",
        "14:7D:DA": "TP-Link", "F8:1A:67": "TP-Link", "74:DA:38": "TP-Link", "BC:46:99": "TP-Link",
        "50:6A:03": "Netgear", "44:94:FC": "Netgear", "BC:EE:7B": "Asus", "F4:28:53": "Asus",
        
        // IoT & Mobile (Samsung, Xiaomi, Huawei, Espressif)
        "00:00:F0": "Samsung", "38:D2:CA": "Samsung", "40:16:37": "Samsung", "50:85:69": "Samsung",
        "14:F6:5A": "Xiaomi", "18:59:36": "Xiaomi", "28:6C:07": "Xiaomi", "64:09:80": "Xiaomi",
        "00:1E:E5": "Huawei", "00:25:68": "Huawei", "28:6E:D4": "Huawei", "AC:22:0B": "Espressif (ESP32)",
        "30:AE:A4": "Espressif (ESP32)", "BC:DD:C2": "Espressif (ESP32)",
        
        // Computing & Virtualization
        "00:00:0C": "Cisco", "00:06:5B": "Dell", "00:0F:1F": "Dell", "00:11:43": "Dell",
        "00:0E:7F": "HP", "00:11:85": "HP", "00:14:38": "HP", "00:1A:11": "Google",
        "00:0D:3A": "Microsoft (Azure/Surface)", "00:22:48": "Microsoft", 
        "00:50:56": "VMWare", "08:00:27": "Oracle (VirtualBox)", "52:54:00": "QEMU/Realtek"
    ]
    
    func lookup(mac: String) -> String {
        let clean = mac.replacingOccurrences(of: "-", with: ":").uppercased()
        let parts = clean.components(separatedBy: ":")
        guard parts.count >= 3 else { return "Unknown" }
        
        let oui = parts[0...2].joined(separator: ":")
        
        if let cached = cache[oui] {
            return cached
        }
        
        if let vendor = vendors[oui] {
            return vendor
        }
        
        return "Unknown Vendor"
    }
    
    func lookupExtended(mac: String) async -> String {
        let local = lookup(mac: mac)
        if local != "Unknown Vendor" {
            return local
        }
        
        let clean = mac.uppercased().replacingOccurrences(of: "-", with: ":")
        let parts = clean.components(separatedBy: ":")
        guard parts.count >= 3 else { return "Unknown" }
        let oui = parts[0...2].joined(separator: ":")
        
        if let onlineVendor = await fetchOnline(mac: oui) {
            cache[oui] = onlineVendor
            return onlineVendor
        }
        
        return "Unknown Vendor"
    }
    
    private func fetchOnline(mac: String) async -> String? {
        let urlString = "https://api.macvendors.com/\(mac.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? mac)"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            if let vendorName = String(data: data, encoding: .utf8), !vendorName.isEmpty {
                return vendorName.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            print("Error fetching vendor online: \(error)")
        }
        return nil
    }
}
