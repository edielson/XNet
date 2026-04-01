# XNet› 🚀

**XNet›** is a native, high-performance macOS utility suite designed specifically for Network Operations Center (NOC) professionals and network engineers. Built 100% in Swift and SwiftUI, it provides a comprehensive set of diagnostic and remote management tools in a clean, modern interface.

![XNet Icon](https://img.shields.io/badge/Platform-macOS%2015.0+-blue.svg)
![Swift Version](https://img.shields.io/badge/Swift-6.0-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

---

## ✨ Features

### 🔍 Diagnostics
- **IP Scanner**: High-speed discovery of devices on local and public networks.
- **Port Scanner**: Rapidly identify open services and potential vulnerabilities.
- **Visual Ping**: Real-time ICMP monitoring with latency statistics.
- **Traceroute**: Map network hops and identify routing bottlenecks.

### 📐 Planning & Infrastructure (NetBox)
- **NetBox Dashboard (DCIM & IPAM)**: 
  - **Site Management**: Physical PoP and node organization.
  - **Hardware Inventory**: Integrated DCIM for routers, switches, and servers.
  - **IPAM (Global Subnets)**: Hierarchical IPv4 IP management with prefix allocation.
  - **Multi-IP Support**: Link multiple IP addresses (WAN, LAN, Loopback) to a single device.
  - **Searchable Inventory**: High-performance device selector for rapid IP assignment.
  - **SwiftData Persistence**: Fully persistent local database with automatic synchronization.

- **Subnet Calculator (The Planner)**: 
  - Advanced IPv4 bitwise calculations.
  - Real-time updates for Network, Broadcast, Mask, and Wildcard info.
  - **Binary Visualizer**: See the exact bit-level split between network and host portions.

### 🖥️ Remote Access
- **Unified Terminal**: A single, powerful interface for remote sessions.
- **SSH & Telnet**: Secure and interactive terminal sessions.
- **Native Serial/COM Port**: Complete POSIX-based serial communication (8N1) for configuring routers, switches, and IoT devices (Arduino, ESP32, etc.) directly via USB-Serial.

### 📁 File Transfer
- **FTP/SFTP Client**: Integrated file management for remote servers with a dual-pane-inspired experience.

---

## 🛠️ Architecture

XNet› follows a **Feature-Based Modular Architecture**, ensuring high scalability and maintainability:

- **App**: Core application lifecycle and routing logic.
- **Core**: Shared models, common diagnostic types, and navigation definitions.
- **Features**: Completely isolated modules for each tool (Ping, Subnet Calculator, Terminal, etc.), containing their own Views and Services.

---

## 🚀 Installation & Distribution

XNet› is designed for distribution outside the Mac App Store to allow for low-level system access (POSIX sockets and serial ports).

### Prerequisites
- macOS 15.0 or later.
- Xcode 16.0+ (to build from source).

### Building from Source
1. Clone the repository:
   ```bash
   git clone https://github.com/kaua-alves-queiros/XNet.git
   ```
2. Open `XNet›.xcodeproj` in Xcode.
3. Select your target and run (`Cmd + R`).

---

## 🏗️ Tech Stack
- **Languages**: Swift 6.0
- **Frameworks**: SwiftUI (Observation API), Network.framework, SwiftData (planned).
- **APIs**: POSIX (termios, sockets) for low-level network and serial access.

---

## 🤝 Contribution

Contributions are welcome! Whether it's adding new NOC tools or improving UI/UX, feel free to open a Pull Request or Issue.

---

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.

---

*“Design is not just what it looks like and feels like. Design is how it works.”* – **XNet›**
