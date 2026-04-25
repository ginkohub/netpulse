import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'log_service.dart';
import 'wifi_service.dart';
import '../database/database.dart';
import 'package:dart_ping/dart_ping.dart';

class HostInfo {
  final String ip;
  final bool isAlive;
  final String? hostname;
  final String? mac;
  final String? vendor;

  HostInfo({
    required this.ip,
    this.isAlive = false,
    this.hostname,
    this.mac,
    this.vendor,
  });
}

class IPScannerProvider extends ChangeNotifier {
  final LogProvider? logger;

  static const String _lastStartKey = 'ip_scanner_last_start';
  static const String _lastEndKey = 'ip_scanner_last_end';

  String _lastStartIp = '';
  String get lastStartIp => _lastStartIp;

  String _lastEndIp = '';
  String get lastEndIp => _lastEndIp;

  static int ipToInt(String ip) {
    try {
      final parts = ip.split('.').map(int.parse).toList();
      if (parts.length != 4) return 0;
      return ((parts[0] << 24) |
              (parts[1] << 16) |
              (parts[2] << 8) |
              parts[3]) &
          0xFFFFFFFF;
    } catch (_) {
      return 0;
    }
  }

  static String intToIp(int ip) {
    return "${(ip >> 24) & 0xFF}.${(ip >> 16) & 0xFF}.${(ip >> 8) & 0xFF}.${ip & 0xFF}";
  }

  static List<int> calculateRange(String ip, int prefixLength) {
    int ipInt = ipToInt(ip);
    if (ipInt == 0) return [0, 0];
    if (prefixLength >= 32) return [ipInt, ipInt];

    int mask = (0xFFFFFFFF << (32 - prefixLength)) & 0xFFFFFFFF;
    int network = ipInt & mask;
    int broadcast = network | (~mask & 0xFFFFFFFF);

    if (prefixLength <= 30) {
      return [network + 1, broadcast - 1];
    }
    return [network, broadcast];
  }

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  double _progress = 0;
  double get progress => _progress;

  int _scannedCount = 0;
  int get scannedCount => _scannedCount;

  int _totalCount = 0;
  int get totalCount => _totalCount;

  List<HostInfo> _discoveredHosts = [];
  List<HostInfo> get discoveredHosts => _discoveredHosts;

  String _currentIp = '';
  String get currentIp => _currentIp;

  bool _isDemoMode = false;
  bool get isDemoMode => _isDemoMode;

  IPScannerProvider({this.logger}) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _isDemoMode = await AppDatabase.getSetting<bool>('demo_mode') ?? false;
    _lastStartIp = await AppDatabase.getSetting<String>(_lastStartKey) ?? '';
    _lastEndIp = await AppDatabase.getSetting<String>(_lastEndKey) ?? '';
    notifyListeners();
  }

  void setDemoMode(bool value) {
    _isDemoMode = value;
    notifyListeners();
  }

  Future<String?> getLocalSubnet() async {
    try {
      final ip = await WifiService.getIpAddress();
      if (ip != null && ip.contains('.')) {
        return ip.substring(0, ip.lastIndexOf('.'));
      }
    } catch (e) {
      logger?.addLog(
        'Platform getIpAddress not available, using fallback: $e',
        level: 'DEBUG',
      );
    }

    try {
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address.substring(0, addr.address.lastIndexOf('.'));
          }
        }
      }
    } catch (_) {}

    return null;
  }

  Future<void> scanRange(String subnet, int start, int end) async {
    final startIp = ipToInt('$subnet.$start');
    final endIp = ipToInt('$subnet.$end');
    await scanFullRange(startIp, endIp);
  }

  Future<void> scanFullRange(int startIp, int endIp) async {
    if (_isScanning) return;

    _lastStartIp = intToIp(startIp);
    _lastEndIp = intToIp(endIp);
    AppDatabase.setSetting(_lastStartKey, _lastStartIp);
    AppDatabase.setSetting(_lastEndKey, _lastEndIp);

    _isScanning = true;
    _progress = 0;
    _scannedCount = 0;
    _discoveredHosts = [];

    int total = endIp - startIp + 1;
    if (total <= 0) {
      _isScanning = false;
      notifyListeners();
      return;
    }

    if (total > 5000 && !_isDemoMode) {
      logger?.addLog(
        'Scan range too large ($total IPs). Limiting to first 5000.',
        level: 'WARN',
      );
      total = 5000;
      endIp = startIp + 4999;
    }

    _totalCount = total;
    notifyListeners();

    final startStr = intToIp(startIp);
    final endStr = intToIp(endIp);
    logger?.addLog(
      'Starting IP scan: $startStr - $endStr${_isDemoMode ? " (Demo Mode)" : ""}',
    );

    if (_isDemoMode) {
      int demoLimit = total > 254 ? 254 : total;
      _totalCount = demoLimit;
      for (int i = 0; i < demoLimit; i++) {
        if (!_isScanning) break;
        int current = startIp + i;
        _currentIp = intToIp(current);
        if (i == 0 || i == 9 || i == 49 || i == 99) {
          _discoveredHosts.add(
            HostInfo(
              ip: _currentIp,
              isAlive: true,
              hostname: i == 0 ? 'Gateway' : 'Device-$i',
            ),
          );
        }
        _scannedCount++;
        _progress = _scannedCount / demoLimit;
        if (_scannedCount % 10 == 0) notifyListeners();
        await Future.delayed(const Duration(milliseconds: 10));
      }
    } else {
      const int batchSize = 25;
      for (int i = startIp; i <= endIp; i += batchSize) {
        if (!_isScanning) break;

        List<Future<void>> futures = [];
        for (int j = i; j < i + batchSize && j <= endIp; j++) {
          futures.add(_checkHost(intToIp(j)));
        }

        await Future.wait(futures);
        _scannedCount += futures.length;
        _progress = _scannedCount / total;
        notifyListeners();
      }
    }

    _isScanning = false;
    _progress = 1.0;
    _scannedCount = _totalCount;
    notifyListeners();
    logger?.addLog(
      'IP scan finished. Found ${_discoveredHosts.length} active hosts.',
    );
  }

  Future<void> _checkHost(String ip) async {
    _currentIp = ip;
    bool alive = false;

    try {
      final ping = Ping(ip, count: 1, timeout: 1);
      final completer = Completer<bool>();

      final subscription = ping.stream.listen((event) {
        if (event.response != null && event.response!.time != null) {
          if (!completer.isCompleted) completer.complete(true);
        }
      });

      alive = await completer.future.timeout(
        const Duration(milliseconds: 1200),
        onTimeout: () {
          subscription.cancel();
          return false;
        },
      );
      await subscription.cancel();
    } catch (_) {}

    if (!alive) {
      try {
        final ports = [80, 443, 22, 135, 445];
        for (var port in ports) {
          try {
            final socket = await Socket.connect(
              ip,
              port,
              timeout: const Duration(milliseconds: 100),
            );
            alive = true;
            socket.destroy();
            break;
          } catch (_) {}
        }
      } catch (_) {}
    }

    if (alive) {
      _discoveredHosts.add(HostInfo(ip: ip, isAlive: true));
    }
  }

  void stopScan() {
    _isScanning = false;
    notifyListeners();
  }

  void clearResults() {
    _discoveredHosts = [];
    _progress = 0;
    _currentIp = '';
    notifyListeners();
  }
}
