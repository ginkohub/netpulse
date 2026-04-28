<p align="center">
  <img src="netpulse.png" width="240">
</p>

# NetPulse

NetPulse is a lightweight and powerful network diagnostic tool built with Flutter. It provides essential tools for monitoring host availability, analyzing WiFi connections, performing speed tests, and managing MikroTik routers.

## Features

- **Multi-Host Ping Monitor**: Monitor multiple IP addresses or domains simultaneously with real-time latency updates, status history, and configurable intervals.
- **Network Scanning**: 
  - **IP Scanner**: Quickly discover active devices on your local network, including IP addresses, MAC addresses, and vendor information.
  - **Port Scanner**: Scan specific hosts for open ports to identify available services and potential security vulnerabilities.
- **WiFi Insights**: Get detailed information about your current WiFi connection, including SSID, BSSID, Signal Strength, and local IP using modern discovery protocols.
- **Speed Test**: Measure your download, upload, latency, and jitter. Includes a searchable server list and interactive performance charts.
- **Advanced MikroTik Monitoring**: Track traffic rates (RX/TX), system resources (CPU, Memory, Uptime), and active hotspot users for MikroTik routers via API.
- **Global Demo Mode**: A privacy-focused mode that anonymizes sensitive data and simulates active network traffic for demonstrations or testing.
- **Internal Logs & Diagnostics**: Built-in logging system to monitor application performance and troubleshoot network service issues.
- **Software Updates**: Stay up-to-date with integrated GitHub release checking and one-click access to the latest versions.
- **Backup & Restore**: Comprehensive export and import functionality to secure your configurations and monitored hosts.
- **Modern UI**: Dark-themed Material 3 interface optimized for both Android and Linux.

## Getting Started

### Prerequisites

- Flutter SDK (v3.10.7 or higher)
- Android Studio / VS Code with Flutter extension
- For Linux: `libnm` and other standard development headers

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/ginkohub/netpulse.git
   cd netpulse
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the application:**
   ```bash
   # Run on connected device or emulator
   flutter run
   ```

### Building for Production

#### Android
```bash
flutter build apk --release
```

#### Linux
```bash
flutter build linux --release
```

## Technologies Used

- **Framework**: [Flutter](https://flutter.dev)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Network Tools**:
  - `dart_ping` for ICMP monitoring.
  - `routeros_api` for MikroTik router communication.
  - `wifi_iot` & `network_info_plus` for advanced WiFi details.
  - `bonsoir` for mDNS/Zeroconf discovery.
  - `connectivity_plus` for network state monitoring.
  - `http` for API requests and update checking.
- **UI & Visualization**:
  - `fl_chart` for real-time performance graphs.
- **Storage & Persistence**:
  - `path_provider` for JSON-based local data management.
  - `file_picker` & `share_plus` for backup/restore operations.
- **System Utilities**:
  - `package_info_plus` for version tracking.
  - `url_launcher` for external links and updates.
  - `permission_handler` for managing system permissions.

## Screenshot
<img src="docs/screenshot-home-page.png" width="300px">

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request or open an issue for bugs and feature requests.

## License

This project is licensed under the Mozilla Public License, Version 2.0 - see the [LICENSE](LICENSE) file for details.
