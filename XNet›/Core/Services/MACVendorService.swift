import Foundation

class MACVendorService {
    
    private static var cache: [String: String] = [:]
    
    private static let vendors: [String: String] = [
        // Apple
        "44:D8:84": "Apple", "A8:61:95": "Apple", "C0:3E:BA": "Apple", "D4:F4:6F": "Apple", 
        "F0:99:B6": "Apple", "FC:2A:9C": "Apple", "00:03:93": "Apple", "00:0A:27": "Apple", 
        "00:0D:93": "Apple", "00:10:FA": "Apple", "00:14:51": "Apple", "00:16:D4": "Apple", 
        "00:17:F2": "Apple", "00:19:E3": "Apple", "00:1B:63": "Apple", "00:1C:B3": "Apple", 
        "00:1D:4F": "Apple", "00:1E:52": "Apple", "00:1E:C2": "Apple", "00:1F:5B": "Apple", 
        "00:21:E9": "Apple", "00:22:41": "Apple", "00:23:12": "Apple", "00:23:6C": "Apple", 
        "00:24:36": "Apple", "00:25:00": "Apple", "00:25:4B": "Apple", "00:25:BC": "Apple", 
        "00:26:08": "Apple", "00:26:4A": "Apple", "00:26:BB": "Apple", "28:CF:E9": "Apple", 
        "34:15:9E": "Apple", "34:C0:59": "Apple", "40:30:04": "Apple", "40:3C:FC": "Apple", 
        "54:E4:3A": "Apple", "60:03:08": "Apple", "64:20:0C": "Apple", "64:76:BA": "Apple",
        "70:3E:AC": "Apple", "78:4F:43": "Apple", "80:EA:96": "Apple", "84:B1:53": "Apple", 
        "8C:85:90": "Apple", "90:72:40": "Apple", "A4:31:35": "Apple", "AC:87:A3": "Apple",
        "B0:34:95": "Apple", "B4:18:D1": "Apple", "BC:3B:AF": "Apple", "C0:33:5E": "Apple",
        "D0:23:DB": "Apple", "E0:C9:7A": "Apple", "F0:18:98": "Apple", "F8:27:93": "Apple",
        
        // Cisco
        "00:00:0C": "Cisco", "00:01:42": "Cisco", "00:01:43": "Cisco", "00:01:63": "Cisco", 
        "00:01:64": "Cisco", "00:01:96": "Cisco", "00:01:97": "Cisco", "00:02:16": "Cisco", 
        "00:02:17": "Cisco", "00:02:4A": "Cisco", "00:02:4B": "Cisco", "00:02:B9": "Cisco",
        
        // Dell
        "00:06:5B": "Dell", "00:0F:1F": "Dell", "00:11:43": "Dell", "00:12:3F": "Dell", 
        "00:13:20": "Dell", "00:13:72": "Dell", "00:14:22": "Dell", "00:15:C5": "Dell", 
        "00:16:76": "Dell", "00:18:8B": "Dell", "00:19:B9": "Dell", "00:1A:A0": "Dell",
        
        // HP
        "00:08:02": "HP", "00:0B:CD": "HP", "00:0E:7F": "HP", "00:0F:20": "HP", 
        "00:10:83": "HP", "00:11:0A": "HP", "00:11:85": "HP", "00:12:79": "HP", 
        "00:13:21": "HP", "00:14:38": "HP", "00:15:60": "HP", "00:16:35": "HP",
        
        // Samsung
        "00:00:F0": "Samsung", "00:07:AB": "Samsung", "00:0D:E6": "Samsung", "00:12:47": "Samsung", 
        "38:D2:CA": "Samsung", "40:16:37": "Samsung", "40:98:AD": "Samsung", "44:F4:59": "Samsung", 
        "50:85:69": "Samsung", "5C:A3:9D": "Samsung", "60:6B:BD": "Samsung", "70:D4:F2": "Samsung",
        "84:74:2A": "Samsung", "94:51:03": "Samsung", "A0:0B:BA": "Samsung", "C4:73:1E": "Samsung",
        
        // Google
        "00:1A:11": "Google", "3C:5A:B4": "Google", "F4:F5:D8": "Google", "DA:A1:19": "Google", 
        "20:DF:B9": "Google", "D8:EB:46": "Google", "94:9F:3E": "Google", "F0:EF:86": "Google",
        
        // Raspberry Pi
        "B8:27:EB": "Raspberry Pi Foundation", "DC:A6:32": "Raspberry Pi Foundation", "E4:5F:01": "Raspberry Pi Foundation", 
        
        // Virtual Platforms
        "00:50:56": "VMWare", "00:0C:29": "VMWare", "00:05:69": "VMWare", 
        "08:00:27": "Oracle (VirtualBox)", "00:15:5D": "Microsoft (Hyper-V/Azure)", 
        "00:03:FF": "Microsoft (Hyper-V)", "00:16:3E": "Xen", "52:54:00": "Realtek/QEMU",
        
        // Network Gear (Ubiquiti, Mikrotik, TP-Link, Intel, etc.)
        "04:18:D6": "Ubiquiti", "24:A4:3C": "Ubiquiti", "44:D9:E7": "Ubiquiti", "68:72:51": "Ubiquiti", 
        "70:A7:41": "Ubiquiti", "74:83:C2": "Ubiquiti", "80:2A:A8": "Ubiquiti", "AC:8B:A9": "Ubiquiti",
        
        "4C:5E:0C": "Mikrotik", "E4:8D:8C": "Mikrotik", "6C:3B:6B": "Mikrotik", 
        "D4:CA:6D": "Mikrotik", "2C:C8:1B": "Mikrotik", "00:0C:42": "Mikrotik", 
        
        "14:7D:DA": "TP-Link", "E0:D9:E3": "TP-Link", "F8:1A:67": "TP-Link", "00:14:78": "TP-Link", 
        "50:C7:BF": "TP-Link", "60:E3:27": "TP-Link", "74:DA:38": "TP-Link", "A0:F3:C1": "TP-Link",
        "BC:46:99": "TP-Link", "D8:07:37": "TP-Link", "EC:08:6B": "TP-Link", "F4:F2:6D": "TP-Link",
        
        "00:1D:60": "Intel", "00:1E:64": "Intel", "00:21:5C": "Intel", "00:21:6A": "Intel", 
        "18:5E:0F": "Intel", "24:77:03": "Intel", "68:5D:43": "Intel", "A4:34:D9": "Intel", 
        "00:E0:4C": "Realtek", "BC:EE:7B": "Asus", 
        "D4:3D:7E": "Micro-Star (MSI)", "00:1F:D0": "Micro-Star (MSI)", 
        "00:1A:3F": "Intel", "00:0D:3A": "Microsoft", "00:22:48": "Microsoft", 
        "28:D2:44": "Asus", "F4:28:53": "Asus", "00:23:54": "Asus", "40:16:7E": "Asus", "48:5B:39": "Asus", 
        
        // Espressif (IoT)
        "AC:22:0B": "Espressif (ESP32/ESP8266)", "24:62:AB": "Espressif (ESP32/ESP8266)", 
        "30:AE:A4": "Espressif (ESP32/ESP8266)", "C4:4F:33": "Espressif (ESP32/ESP8266)",
        "BC:DD:C2": "Espressif (ESP32/ESP8266)", "54:5A:A6": "Espressif (ESP32/ESP8266)",
        
        // Other Common
        "00:25:9C": "Sony", "28:0D:FC": "Sony", "D4:4B:5E": "Sony",
        "00:1E:E5": "Huawei", "00:25:68": "Huawei", "28:6E:D4": "Huawei",
        "14:F6:5A": "Xiaomi", "18:59:36": "Xiaomi", "28:6C:07": "Xiaomi", "64:09:80": "Xiaomi",
        "00:11:32": "Synology", "00:11:32": "Synology", "D8:CB:8A": "Synology"
    ]
    
    static func lookup(mac: String) -> String {
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
    
    static func lookupExtended(mac: String) async -> String {
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
    
    private static func fetchOnline(mac: String) async -> String? {
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
