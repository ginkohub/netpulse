import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'log_service.dart';
import '../database/database.dart';

class PortScanResult {
  final int port;
  final bool isOpen;
  final String? service;

  PortScanResult({required this.port, required this.isOpen, this.service});
}

class PortScannerProvider extends ChangeNotifier {
  final LogProvider? logger;

  static const String _lastHostKey = 'port_scanner_last_host';
  static const String _lastStartPortKey = 'port_scanner_last_start_port';
  static const String _lastEndPortKey = 'port_scanner_last_end_port';

  String _lastHost = '';
  String get lastHost => _lastHost;

  int _lastStartPort = 1;
  int get lastStartPort => _lastStartPort;

  int _lastEndPort = 1024;
  int get lastEndPort => _lastEndPort;

  static const Map<int, String> commonPorts = {
    20: 'FTP-DATA',
    21: 'FTP',
    22: 'SSH',
    23: 'Telnet',
    25: 'SMTP',
    53: 'DNS',
    80: 'HTTP',
    110: 'POP3',
    143: 'IMAP',
    161: 'SNMP',
    443: 'HTTPS',
    445: 'SMB',
    587: 'SMTP',
    993: 'IMAPS',
    995: 'POP3S',
    1433: 'MSSQL',
    3306: 'MySQL',
    3389: 'RDP',
    5432: 'PostgreSQL',
    5900: 'VNC',
    6379: 'Redis',
    8080: 'HTTP-Alt',
    8443: 'HTTPS-Alt',
  };

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  double _progress = 0;
  double get progress => _progress;

  List<PortScanResult> _openPorts = [];
  List<PortScanResult> get openPorts => _openPorts;

  int _currentPort = 0;
  int get currentPort => _currentPort;

  bool _isDemoMode = false;
  bool get isDemoMode => _isDemoMode;

  PortScannerProvider({this.logger}) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _isDemoMode = await AppDatabase.getSetting<bool>('demo_mode') ?? false;
    _lastHost = await AppDatabase.getSetting<String>(_lastHostKey) ?? '';
    _lastStartPort = await AppDatabase.getSetting<int>(_lastStartPortKey) ?? 1;
    _lastEndPort = await AppDatabase.getSetting<int>(_lastEndPortKey) ?? 1024;
    notifyListeners();
  }

  void setDemoMode(bool value) {
    _isDemoMode = value;
    notifyListeners();
  }

  Future<void> scanRange(
    String host,
    int startPort,
    int endPort, {
    int timeoutMs = 200,
  }) async {
    if (_isScanning) return;

    _lastHost = host;
    _lastStartPort = startPort;
    _lastEndPort = endPort;
    AppDatabase.setSetting(_lastHostKey, _lastHost);
    AppDatabase.setSetting(_lastStartPortKey, _lastStartPort);
    AppDatabase.setSetting(_lastEndPortKey, _lastEndPort);

    _isScanning = true;
    _progress = 0;
    _openPorts = [];
    _currentPort = startPort;
    notifyListeners();

    logger?.addLog(
      'Starting port scan on $host: $startPort-$endPort${_isDemoMode ? " (Demo Mode)" : ""}',
    );

    int total = endPort - startPort + 1;
    int scanned = 0;

    if (_isDemoMode) {
      for (int i = startPort; i <= endPort; i++) {
        if (!_isScanning) break;
        _currentPort = i;
        if (i % 80 == 0 || i % 443 == 0 || i % 22 == 0) {
          _openPorts.add(
            PortScanResult(port: i, isOpen: true, service: commonPorts[i]),
          );
        }
        scanned++;
        _progress = scanned / total;
        if (scanned % 10 == 0) notifyListeners();
        await Future.delayed(const Duration(milliseconds: 5));
      }
    } else {
      const int batchSize = 50;
      for (int i = startPort; i <= endPort; i += batchSize) {
        if (!_isScanning) break;

        List<Future<void>> futures = [];
        for (int j = i; j < i + batchSize && j <= endPort; j++) {
          futures.add(_scanPort(host, j, timeoutMs));
        }

        await Future.wait(futures);
        scanned += futures.length;
        _progress = scanned / total;
        notifyListeners();
      }
    }

    _isScanning = false;
    _progress = 1.0;
    notifyListeners();
    logger?.addLog(
      'Port scan on $host finished. Found ${_openPorts.length} open ports.',
    );
  }

  Future<void> _scanPort(String host, int port, int timeoutMs) async {
    try {
      _currentPort = port;
      final socket = await Socket.connect(
        host,
        port,
        timeout: Duration(milliseconds: timeoutMs),
      );
      _openPorts.add(
        PortScanResult(port: port, isOpen: true, service: commonPorts[port]),
      );
      socket.destroy();
    } catch (_) {}
  }

  void stopScan() {
    _isScanning = false;
    notifyListeners();
  }

  void clearResults() {
    _openPorts = [];
    _progress = 0;
    _currentPort = 0;
    notifyListeners();
  }

  String _prefilledHost = '';
  String get prefilledHost => _prefilledHost;

  void prefillHost(String host) {
    _prefilledHost = host;
    notifyListeners();
  }
}
