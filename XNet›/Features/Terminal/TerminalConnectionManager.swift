//
//  TerminalConnectionManager.swift
//  XNet›
//

import Foundation
import Network
import Darwin

@Observable
class TerminalConnectionManager {
    var logs: String = ""
    var isConnected: Bool = false
    
    private var sshProcess: Process?
    private var pipeIn: Pipe?
    private var pipeOut: Pipe?
    private var pipeErr: Pipe?
    
    private var telnetConnection: NWConnection?
    
    private var serialFileDescriptor: Int32 = -1
    private var isReadingSerial: Bool = false
    private let serialQueue = DispatchQueue(label: "com.xnet.serial", qos: .userInitiated)
    
    func getAvailableSerialPorts() -> [String] {
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: "/dev") else { return [] }
        return items.filter { $0.hasPrefix("cu.") }.map { "/dev/\($0)" }.sorted()
    }
    
    func connectSSH(host: String, port: String, user: String) {
        logs += "Starting SSH session...\n"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
        
        var args = ["-q", "/dev/null", "/usr/bin/ssh", "-p", port]
        if !user.isEmpty {
            args.append("\(user)@\(host)")
        } else {
            args.append(host)
        }
        
        args.append("-o")
        args.append("StrictHostKeyChecking=accept-new")
        args.append("-o")
        args.append("LogLevel=ERROR")
        args.append("-tt")
        
        process.arguments = args
        
        pipeIn = Pipe()
        pipeOut = Pipe()
        pipeErr = Pipe()
        
        process.standardInput = pipeIn
        process.standardOutput = pipeOut
        process.standardError = pipeErr
        
        pipeOut?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let str = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
            DispatchQueue.main.async {
                self?.processIncomingData(str)
            }
        }
        
        pipeErr?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let str = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
            DispatchQueue.main.async {
                self?.processIncomingData(str)
            }
        }
        
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isConnected = false
                self?.logs += "\n[SSH Process Terminated]\n"
                self?.pipeOut?.fileHandleForReading.readabilityHandler = nil
                self?.pipeErr?.fileHandleForReading.readabilityHandler = nil
            }
        }
        
        do {
            try process.run()
            self.sshProcess = process
            self.isConnected = true
        } catch {
            logs += "Failed to start SSH: \(error.localizedDescription)\n"
            self.isConnected = false
        }
    }
    
    func connectTelnet(host: String, port: String) {
        logs += "Starting Telnet session...\n"
        
        let hostEndpoint = NWEndpoint.Host(host)
        guard let portEndpoint = NWEndpoint.Port(port) else {
            logs += "Invalid port.\n"
            return
        }
        
        let parameters = NWParameters.tcp
        telnetConnection = NWConnection(host: hostEndpoint, port: portEndpoint, using: parameters)
        
        telnetConnection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.logs += "[Telnet Connected]\n"
                    self?.receiveTelnetData()
                case .failed(let error):
                    self?.isConnected = false
                    self?.logs += "[Telnet Error]: \(error.localizedDescription)\n"
                case .cancelled:
                    self?.isConnected = false
                    self?.logs += "[Telnet Cancelled]\n"
                default:
                    break
                }
            }
        }
        
        telnetConnection?.start(queue: .global())
    }
    
    func connectSerial(portPath: String, baudRate: Int) {
        logs += "Starting Serial session on \(portPath) at \(baudRate) baud...\n"
        
        serialFileDescriptor = open(portPath.cString(using: .utf8)!, O_RDWR | O_NOCTTY | O_NONBLOCK)
        
        guard serialFileDescriptor != -1 else {
            logs += "Failed to open port \(portPath). Error: \(String(cString: strerror(errno)))\n"
            return
        }
        
        // Configure port
        var settings = termios()
        if tcgetattr(serialFileDescriptor, &settings) != 0 {
            logs += "Warning: tcgetattr failed.\n"
        }
        
        cfsetspeed(&settings, speed_t(baudRate))
        
        settings.c_cflag &= ~UInt(CSIZE)
        settings.c_cflag |= UInt(CS8)
        settings.c_cflag &= ~UInt(PARENB)
        settings.c_cflag &= ~UInt(CSTOPB)
        settings.c_cflag |= UInt(CREAD | CLOCAL)
        
        settings.c_lflag &= ~UInt(ICANON | ECHO | ECHOE | ISIG)
        settings.c_oflag &= ~UInt(OPOST)
        
        if tcsetattr(serialFileDescriptor, TCSANOW, &settings) != 0 {
            logs += "Warning: tcsetattr failed.\n"
        }
        
        isConnected = true
        isReadingSerial = true
        
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            var buffer = [UInt8](repeating: 0, count: 1024)
            while self.isReadingSerial {
                let bytesRead = read(self.serialFileDescriptor, &buffer, buffer.count)
                if bytesRead > 0 {
                    let data = Data(buffer[0..<bytesRead])
                    if let str = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) {
                        DispatchQueue.main.async {
                            self.processIncomingData(str)
                        }
                    }
                } else if bytesRead == 0 {
                    // EOF
                    DispatchQueue.main.async {
                        self.logs += "\n[Serial Connection Closed]\n"
                        self.disconnect()
                    }
                    break
                } else if bytesRead < 0 && errno != EAGAIN && errno != EWOULDBLOCK {
                    DispatchQueue.main.async {
                        self.logs += "\n[Serial Read Error: \(String(cString: strerror(errno)))]\n"
                        self.disconnect()
                    }
                    break
                }
                usleep(10000) // 10ms CPU sleep
            }
        }
    }
    
    private func processIncomingData(_ newString: String) {
        var current = self.logs
        for scalar in newString.unicodeScalars {
            switch scalar.value {
            case 8, 127:
                if !current.isEmpty {
                    current.removeLast()
                }
            case 13:
                if !current.hasSuffix("\n") {
                    current.append("\n")
                }
            default:
                current.unicodeScalars.append(scalar)
            }
        }
        self.logs = current
    }

    private func filterTelnetCommands(from data: Data) -> Data {
        let bytes = [UInt8](data)
        var filteredBytes = [UInt8]()
        var i = 0
        while i < bytes.count {
            if bytes[i] == 255 { // IAC
                 if i + 1 < bytes.count {
                     let command = bytes[i+1]
                     if command >= 251 && command <= 254 { // WILL, WONT, DO, DONT
                         i += 3
                     } else if command == 250 { // SB (Subnegotiation)
                         i += 2
                         while i + 1 < bytes.count && !(bytes[i] == 255 && bytes[i+1] == 240) {
                             i += 1
                         }
                         i += 2 // Skip IAC SE
                     } else if command == 255 { // Escaped 255
                         filteredBytes.append(255)
                         i += 2
                     } else {
                         i += 2 // Other simple commands
                     }
                 } else {
                     i += 1
                 }
            } else {
                 filteredBytes.append(bytes[i])
                 i += 1
            }
        }
        return Data(filteredBytes)
    }

    private func receiveTelnetData() {
        telnetConnection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, context, isComplete, error in
            if let data = data, !data.isEmpty {
                if let filtered = self?.filterTelnetCommands(from: data) {
                    let str = String(data: filtered, encoding: .utf8) ?? String(data: filtered, encoding: .isoLatin1) ?? ""
                    DispatchQueue.main.async {
                        self?.processIncomingData(str)
                    }
                }
            }
            if let error = error {
                DispatchQueue.main.async {
                    self?.isConnected = false
                    self?.logs += "\n[Telnet Receive Error]: \(error.localizedDescription)\n"
                }
                return
            }
            if isComplete {
                DispatchQueue.main.async {
                    self?.isConnected = false
                    self?.logs += "\n[Telnet Connection Closed by Remote]\n"
                }
                return
            }
            // Continue receiving
            self?.receiveTelnetData()
        }
    }
    
    func sendRaw(_ string: String) {
        if let data = string.data(using: .utf8) {
            if let process = sshProcess, process.isRunning {
                pipeIn?.fileHandleForWriting.write(data)
            } else if telnetConnection != nil && telnetConnection?.state == .ready {
                telnetConnection?.send(content: data, completion: .contentProcessed({ error in
                    if let error = error {
                        DispatchQueue.main.async {
                            self.logs += "Send error: \(error.localizedDescription)\n"
                        }
                    }
                }))
            } else if serialFileDescriptor != -1 {
                data.withUnsafeBytes { ptr in
                    if let baseAddress = ptr.baseAddress {
                        write(serialFileDescriptor, baseAddress, data.count)
                    }
                }
            }
        }
    }
    
    // Kept for compatibility if needed, but not used by interactive terminal
    func sendCommand(_ command: String) {
        sendRaw(command + "\n")
    }
    
    func disconnect() {
        if let process = sshProcess, process.isRunning {
            process.terminate()
        }
        sshProcess = nil
        
        telnetConnection?.cancel()
        telnetConnection = nil
        
        if serialFileDescriptor != -1 {
            isReadingSerial = false
            close(serialFileDescriptor)
            serialFileDescriptor = -1
        }
        
        isConnected = false
    }
}
