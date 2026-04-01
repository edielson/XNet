//
//  DiagnosticModels.swift
//  XNet›
//

import Foundation

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
}

struct ScannedPort: Identifiable, Sendable {
    let id = UUID()
    let port: Int
    let protocolName: String
    let state: String
}

// Thread-safe flag - @unchecked Sendable to allow manual locking
// Marked nonisolated to prevent the compiler from inferring MainActor isolation
final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var _flag = false
    
    // Explicitly nonisolated to be accessible from any Sendable closure
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
