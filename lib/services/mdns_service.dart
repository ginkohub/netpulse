import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bonsoir/bonsoir.dart';
import 'log_service.dart';

class ServiceInfo {
  final String name;
  final String type;
  final String? host;
  final int? port;
  final Map<String, String> txt;
  final DateTime discoveredAt;

  ServiceInfo({
    required this.name,
    required this.type,
    this.host,
    this.port,
    this.txt = const {},
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  String get displayType {
    if (type.contains('_http')) return 'Web';
    if (type.contains('_https')) return 'HTTPS';
    if (type.contains('_ssh')) return 'SSH';
    if (type.contains('_smb')) return 'SMB';
    if (type.contains('_printer')) return 'Printer';
    if (type.contains('_airplay')) return 'AirPlay';
    if (type.contains('_googlecast')) return 'Chromecast';
    if (type.contains('_raop')) return 'Audio';
    if (type.contains('_homekit')) return 'HomeKit';
    if (type.contains('_spotify')) return 'Spotify';
    return type.replaceAll('._tcp', '').replaceAll('_', ' ');
  }
}

class MdnsProvider extends ChangeNotifier {
  final LogProvider? logger;
  final List<ServiceInfo> _services = [];
  final List<BonsoirBroadcast> _broadcasts = [];
  BonsoirDiscovery? _discovery;
  bool _isScanning = false;
  String? _error;
  String _serviceType = '_http._tcp';

  MdnsProvider({this.logger});

  List<ServiceInfo> get services => _services;
  bool get isScanning => _isScanning;
  String? get error => _error;
  String get serviceType => _serviceType;

  final List<String> _presetTypes = [
    '_http._tcp',
    '_https._tcp',
    '_ssh._tcp',
    '_smb._tcp',
    '_printer._tcp',
    '_airplay._tcp',
    '_googlecast._tcp',
    '_raop._tcp',
    '_homekit._tcp',
    '_spotify-connect._tcp',
  ];

  List<String> get presetTypes => _presetTypes;

  void setServiceType(String type) {
    _serviceType = type;
    notifyListeners();
  }

  Future<void> startScan() async {
    if (_isScanning) return;

    _isScanning = true;
    _error = null;
    _services.clear();
    notifyListeners();

    logger?.addLog('[mDNS] Starting scan for $_serviceType');

    try {
      _discovery = BonsoirDiscovery(type: _serviceType);
      await _discovery!.initialize();

      _discovery!.eventStream!.listen((event) {
        if (event is BonsoirDiscoveryServiceFoundEvent) {
          event.service.resolve(_discovery!.serviceResolver);
        } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
          final service = event.service;
          final info = ServiceInfo(
            name: service.name,
            type: service.type,
            host: service.host,
            port: service.port,
            txt: service.attributes,
          );
          if (!_services.any((s) => s.name == info.name && s.type == info.type)) {
            _services.add(info);
            notifyListeners();
            logger?.addLog('[mDNS] Found: ${info.name} (${info.displayType})');
          }
        } else if (event is BonsoirDiscoveryServiceLostEvent) {
_services.removeWhere((s) => s.name == event.service.name);
          notifyListeners();
        }
      });

      await _discovery!.start();

      await Future.delayed(const Duration(seconds: 10));
      await stopScan();
    } catch (e) {
      _error = e.toString();
      logger?.addLog('[mDNS] Error: $e', level: 'ERROR');
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    if (_discovery != null) {
      await _discovery!.stop();
      _discovery = null;
    }
    _isScanning = false;
    logger?.addLog('[mDNS] Scan stopped. Found ${_services.length} services.');
    notifyListeners();
  }

  Future<void> publishService(String name, int port) async {
    try {
      final broadcast = BonsoirBroadcast(
        service: BonsoirService(
          name: name,
          type: _serviceType,
          port: port,
        ),
      );
      _broadcasts.add(broadcast);
      await broadcast.initialize();
      await broadcast.start();
      logger?.addLog('[mDNS] Published: $name on port $port');
      notifyListeners();
    } catch (e) {
      logger?.addLog('[mDNS] Publish error: $e', level: 'ERROR');
    }
  }

  void clear() {
    _services.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    stopScan();
    super.dispose();
  }
}