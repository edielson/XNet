import SwiftUI

@MainActor
class XNetUpdater: ObservableObject {
    @Published var updateAvailable = false
    @Published var latestVersion = ""
    @Published var releaseURL = ""
    @Published var releaseNotes = ""
    
    // Replace with your GitHub Repository name (format: "owner/repo")
    private let repo = "kaua-alves-queiros/XNet"
    
    func checkForUpdates() async {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tagName = json["tag_name"] as? String,
               let htmlUrl = json["html_url"] as? String,
               let body = json["body"] as? String {
                
                let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                
                // Remove 'v' prefix if present
                let cleanLatest = tagName.lowercased().replacingOccurrences(of: "v", with: "")
                let cleanCurrent = currentVersion.lowercased().replacingOccurrences(of: "v", with: "")
                
                if cleanLatest.compare(cleanCurrent, options: .numeric) == .orderedDescending {
                    self.latestVersion = tagName
                    self.releaseURL = htmlUrl
                    self.releaseNotes = body
                    self.updateAvailable = true
                }
            }
        } catch {
            print("Failed to check for updates: \(error)")
        }
    }
}
