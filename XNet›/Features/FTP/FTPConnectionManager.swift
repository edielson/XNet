//
//  FTPConnectionManager.swift
//  XNet›
//

import Foundation
import SwiftUI

@Observable
class FTPConnectionManager {
    var isConnected = false
    var isTransferring = false
    var statusMessage = "Ready"
    
    var remoteCurrentPath = "/"
    var remoteFiles: [FileItem] = []
    
    // Connection Info
    private var scheme = ""
    private var credentials = ""
    private var baseUrl = ""
    
    func connect(host: String, port: String, user: String, pass: String, isSFTP: Bool) {
        scheme = isSFTP ? "sftp" : "ftp"
        // Safely escape username and password for curl
        // Process handles argument boundaries natively without shell escaping
        credentials = "\(user):\(pass)"
        baseUrl = "\(scheme)://\(host):\(port)"
        
        statusMessage = "Connecting to \(baseUrl)..."
        
        // Test connection by listing root
        remoteCurrentPath = "/"
        loadRemoteFiles { success in
            if success {
                self.isConnected = true
                self.statusMessage = "Connected to \(host)"
            } else {
                self.isConnected = false
                if self.statusMessage.contains("Connecting") {
                    self.statusMessage = "Connection failed. Check credentials and protocol."
                }
            }
        }
    }
    
    func disconnect() {
        isConnected = false
        remoteFiles = []
        statusMessage = "Disconnected"
    }
    
    func loadRemoteFiles(completion: ((Bool) -> Void)? = nil) {
        let path = remoteCurrentPath.hasSuffix("/") ? remoteCurrentPath : remoteCurrentPath + "/"
        let targetUrl = "\(baseUrl)\(path)"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        
        // -k: Insecure (allow self-signed certs for local environments)
        // -s: Silent
        // -u user:pass
        // --list-only might be needed for FTP if not default, but SFTP defaults to detailed ls
        process.arguments = ["-k", "-s", "-u", credentials, targetUrl]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        let errPipe = Pipe()
        process.standardError = errPipe
        
        DispatchQueue.global().async {
            do {
                try process.run()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    if let output = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self.parseCurlDirectoryListing(output, currentPath: path)
                            completion?(true)
                        }
                    } else {
                        DispatchQueue.main.async { completion?(false) }
                    }
                } else {
                    let errStr = String(data: errData, encoding: .utf8) ?? ""
                    DispatchQueue.main.async {
                        self.statusMessage = "List Failed (\(process.terminationStatus)): \(errStr.prefix(50))"
                        completion?(false)
                    }
                }
            } catch {
                DispatchQueue.main.async { completion?(false) }
            }
        }
    }
    
    func uploadFile(localPath: String, remoteFolder: String) {
        let filename = URL(fileURLWithPath: localPath).lastPathComponent
        let targetPath = remoteFolder.hasSuffix("/") ? remoteFolder + filename : remoteFolder + "/" + filename
        let targetUrl = "\(baseUrl)\(targetPath)"
        
        isTransferring = true
        statusMessage = "Uploading \(filename)..."
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        // Create remote dirs if needed option: --ftp-create-dirs
        process.arguments = ["-k", "-s", "-u", credentials, "--ftp-create-dirs", "-T", localPath, targetUrl]
        
        DispatchQueue.global().async {
            do {
                try process.run()
                process.waitUntilExit()
                DispatchQueue.main.async {
                    self.isTransferring = false
                    if process.terminationStatus == 0 {
                        self.statusMessage = "Upload complete: \(filename)"
                        if self.remoteCurrentPath == remoteFolder {
                            self.loadRemoteFiles()
                        }
                    } else {
                        self.statusMessage = "Upload failed (Status \(process.terminationStatus))"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isTransferring = false
                    self.statusMessage = "Upload failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func downloadFile(remotePath: String, localFolder: String) {
        let filename = (remotePath as NSString).lastPathComponent
        let targetLocalPath = (localFolder as NSString).appendingPathComponent(filename)
        let targetUrl = "\(baseUrl)\(remotePath)"
        
        isTransferring = true
        statusMessage = "Downloading \(filename)..."
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = ["-k", "-s", "-u", credentials, targetUrl, "-o", targetLocalPath]
        
        DispatchQueue.global().async {
            do {
                try process.run()
                process.waitUntilExit()
                DispatchQueue.main.async {
                    self.isTransferring = false
                    if process.terminationStatus == 0 {
                        self.statusMessage = "Download complete: \(filename)"
                        // Post a notification so the Local file browser can refresh
                        NotificationCenter.default.post(name: NSNotification.Name("LocalBrowserRefresh"), object: nil)
                    } else {
                        self.statusMessage = "Download failed (Status \(process.terminationStatus))"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isTransferring = false
                    self.statusMessage = "Download failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func parseCurlDirectoryListing(_ listing: String, currentPath: String) {
        var items: [FileItem] = []
        let lines = listing.components(separatedBy: .newlines)
        
        for line in lines {
            if line.isEmpty { continue }
            
            let trLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trLine.isEmpty { continue }
            
            let parts = trLine.split(separator: " ", omittingEmptySubsequences: true)
            if parts.isEmpty { continue }
            
            var name = ""
            var isDir = false
            var size: Int64 = 0
            var date: Date = Date.distantPast
            
            if parts.count >= 8 && (parts[0].hasPrefix("d") || parts[0].hasPrefix("-") || parts[0].hasPrefix("l")) {
                let permissions = String(parts[0])
                isDir = permissions.hasPrefix("d")
                
                var nameIndex = 8
                if parts.count == 8 { nameIndex = 7 }
                
                // Seek the time / year field (e.g. 19:20 or 2023) to delimit the name
                for i in 4..<parts.count {
                    if parts[i].contains(":") || (parts[i].count == 4 && Int(parts[i]) != nil) {
                        nameIndex = i + 1
                        break
                    }
                }
                
                if nameIndex < parts.count {
                    name = parts[nameIndex...].joined(separator: " ")
                    if nameIndex - 4 >= 0 {
                        size = Int64(parts[nameIndex - 4]) ?? 0
                        if nameIndex - 1 < parts.count {
                            let dateString = parts[(nameIndex - 3)..<nameIndex].joined(separator: " ")
                            date = parseDate(dateString)
                        }
                    }
                } else {
                    name = parts.last.map(String.init) ?? trLine
                }
            } else if parts.count >= 4 && (parts[2] == "<DIR>" || Int64(parts[2]) != nil) {
                isDir = parts[2] == "<DIR>"
                size = Int64(parts[2]) ?? 0
                name = parts[3...].joined(separator: " ")
                let dateString = [parts[0], parts[1]].joined(separator: " ")
                date = parseDate(dateString)
            } else {
                name = trLine
                isDir = false
            }
            
            if name == "." || name == ".." { continue }
            
            let fullPath = currentPath + name
            items.append(FileItem(name: name, isDirectory: isDir, size: size, path: fullPath, date: date))
        }
        
        self.remoteFiles = items.sorted {
            if $0.isDirectory == $1.isDirectory { return $0.name.lowercased() < $1.name.lowercased() }
            return $0.isDirectory && !$1.isDirectory
        }
    }
    
    private func parseDate(_ dateStr: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        let formats = [
            "MMM d HH:mm",
            "MMM d yyyy",
            "MM-dd-yy hh:mma",
            "MM-dd-yyyy hh:mma"
        ]
        
        for fmt in formats {
            formatter.dateFormat = fmt
            if let d = formatter.date(from: dateStr) {
                if fmt == "MMM d HH:mm" {
                    var comps = Calendar.current.dateComponents([.month, .day, .hour, .minute], from: d)
                    comps.year = Calendar.current.component(.year, from: Date())
                    if let finalDate = Calendar.current.date(from: comps) {
                        if finalDate > Date() {
                            comps.year! -= 1
                            return Calendar.current.date(from: comps) ?? finalDate
                        }
                        return finalDate
                    }
                }
                return d
            }
        }
        return Date.distantPast
    }
}
