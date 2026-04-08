//
//  DiagnosticModels.swift
//  XNet›
//

import Foundation
import SwiftData

// Common diagnostic models
struct PingResult: Identifiable, Sendable {
    let id = UUID()
    let sequence: Int
    let ip: String
    let bytes: Int
    let ttl: Int
    let time: Double
}

struct TracerouteHop: Identifiable, Sendable {
    let id: Int
    let host: String
    let ip: String
    let time1: String
    let time2: String
    let time3: String
}

struct ScannedDevice: Identifiable, Sendable {
    let id = UUID()
    let ip: String
    let mac: String
    let hostname: String
    let vendor: String
    var isOnline: Bool = true
}

struct ScannedPort: Identifiable, Sendable {
    let id = UUID()
    let port: Int
    let protocolName: String
    var state: String
}

// Thread-safe flag - @unchecked Sendable to allow manual locking
final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var _flag = false
    
    nonisolated var isCancelled: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _flag
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _flag = newValue
        }
    }
    
    init() {}
}

@Model
final class TerminalDevice {
    var name: String
    var connectionType: String
    var host: String
    var port: String
    var username: String
    var notes: String
    
    init(name: String, connectionType: String = "SSH", host: String, port: String, username: String = "", notes: String = "") {
        self.name = name
        self.connectionType = connectionType
        self.host = host
        self.port = port
        self.username = username
        self.notes = notes
    }
}
