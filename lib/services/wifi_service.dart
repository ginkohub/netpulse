import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database/database.dart' show AppDatabase;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'log_service.dart';

class WifiService {
  static const _channel = MethodChannel('com.ginkohub.netpulse');
  static LogProvider? _logger;

  static void setLogger(LogProvider logger) {
    _logger = logger;
  }

  static void _logError(String method, String? error) {
    final msg = 'WifiService $method: $error';
    _logger?.addLog(msg, level: 'ERROR');
  }

  static Future<int?> getLinkSpeed() async {
    try {
      final int speed = await _channel.invokeMethod('getLinkSpeed');
      return speed;
    } on PlatformException catch (e) {
      _logError('getLinkSpeed', e.message);
      return null;
    }
  }

  static Future<int?> getFrequency() async {
    try {
      final int frequency = await _channel.invokeMethod('getFrequency');
      return frequency;
    } on PlatformException catch (e) {
      _logError('getFrequency', e.message);
      return null;
    }
  }

  static Future<int?> getRssi() async {
    try {
      final int rssi = await _channel.invokeMethod('getRssi');
      return rssi;
    } on PlatformException catch (e) {
      _logError('getRssi', e.message);
      return null;
    }
  }

  static Future<String?> getMacAddress() async {
    try {
      final String mac = await _channel.invokeMethod('getMacAddress');
      return mac;
    } on PlatformException catch (e) {
      _logError('getMacAddress', e.message);
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getWifiInfo() async {
    try {
      final Map<dynamic, dynamic> info = await _channel.invokeMethod(
        'getWifiInfo',
      );
      final result = info.cast<String, dynamic>();
      final error = result['error'] as String?;
      if (error != null) {
        _logError('getWifiInfo', error);
      }
      return result;
    } on PlatformException catch (e) {
      _logError('getWifiInfo', e.message);
      return null;
    }
  }

  static Future<String?> getIpAddress() async {
    try {
      final String ip = await _channel.invokeMethod('getIpAddress');
      return ip;
    } on PlatformException catch (e) {
      _logError('getIpAddress', e.message);
      return null;
    }
  }

  static Future<String?> getGateway() async {
    try {
      final String gateway = await _channel.invokeMethod('getGateway');
      return gateway;
    } on PlatformException catch (e) {
      _logError('getGateway', e.message);
      return null;
    }
  }

  static Future<String?> getDns() async {
    try {
      final String dns = await _channel.invokeMethod('getDns');
      return dns;
    } on PlatformException catch (e) {
      _logError('getDns', e.message);
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getConnectivityInfo() async {
    try {
      final Map<dynamic, dynamic> info = await _channel.invokeMethod(
        'getConnectivityInfo',
      );
      final result = info.cast<String, dynamic>();
      final error = result['error'] as String?;
      if (error != null) {
        _logError('getConnectivityInfo', error);
      }
      return result;
    } on PlatformException catch (e) {
      _logError('getConnectivityInfo', e.message);
      return null;
    }
  }
}

class WifiProvider extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  final LogProvider? logger;

  int? _signalStrength;
  String _status = 'Disconnected';
  String? _ssid;
  String? _bssid;
  String? _ip;
  String? _gateway;
  String? _dns;
  String? _clientMac;
  int? _speed;
  int? _frequency;
  int? _rssi;
  int? _channel;
  String? _band;
  String? _security;
  String? _standard;
  int? _txSpeed;
  int? _rxSpeed;

  String? _connectionType;
  String? _connectionStatus;
  bool? _isConnected;
  List<String>? _capabilities;
  int? _downstreamBandwidth;
  int? _upstreamBandwidth;
  bool? _isMetered;

  bool _isMonitoring = true;
  bool _isDemoMode = false;
  int _refreshInterval = 5;
  Timer? _timer;
  StreamSubscription? _connectivitySub;

  int? get signalStrength => _signalStrength;
  String get status => _status;
  String? get ssid => _ssid;
  String? get bssid => _bssid;
  String? get ip => _ip;
  String? get gateway => _gateway;
  String? get dns => _dns;
  String? get clientMac => _clientMac;
  bool get isMonitoring => _isMonitoring;
  int get refreshInterval => _refreshInterval;
  int? get speed => _speed;
  int? get frequency => _frequency;
  int? get rssi => _rssi;
  int? get channel => _channel;
  String? get band => _band;
  String? get security => _security;
  String? get standard => _standard;
  int? get txSpeed => _txSpeed;
  int? get rxSpeed => _rxSpeed;

  String? get connectionType => _connectionType;
  String? get connectionStatus => _connectionStatus;
  bool? get isConnectedNet => _isConnected;
  List<String>? get capabilities => _capabilities;
  int? get downstreamBandwidth => _downstreamBandwidth;
  int? get upstreamBandwidth => _upstreamBandwidth;
  bool? get isMetered => _isMetered;
  bool get isDemoMode => _isDemoMode;

  WifiProvider({this.logger}) {
    if (logger != null) {
      WifiService.setLogger(logger!);
    }
    _loadConfig();
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      updateWifiDetails();
    });
  }

  Future<void> _loadConfig() async {
    _refreshInterval = await AppDatabase.getWifiSetting<int>('interval') ?? 5;
    _isMonitoring = await AppDatabase.getWifiSetting<bool>('monitor') ?? true;
    _isDemoMode = await AppDatabase.getWifiSetting<bool>('demo') ?? false;

    if (_isDemoMode) {
      _startDemoMode();
      return;
    }

    if (Platform.isAndroid) {
      await Permission.location.request();
    }

    if (_isMonitoring) {
      _startMonitoring();
    } else {
      updateWifiDetails();
    }
  }

  Future<void> _saveConfig() async {
    await AppDatabase.setWifiSetting('interval', _refreshInterval);
    await AppDatabase.setWifiSetting('monitor', _isMonitoring);
    await AppDatabase.setWifiSetting('demo', _isDemoMode);
  }

  void _startDemoMode() {
    final random = DateTime.now().millisecondsSinceEpoch;
    _status = 'Connected';
    _ssid = 'Demo-Network';
    _bssid = 'AA:BB:CC:DD:EE:FF';
    _ip = '192.168.1.${100 + (random % 100)}';
    _gateway = '192.168.1.1';
    _dns = '8.8.8.8, 8.8.4.4';
    _clientMac = 'AA:BB:CC:DD:EE:FF';
    _signalStrength = -30 - (random % 50);
    _speed = 72 + (random % 200);
    _frequency = random % 2 == 0 ? 5180 : 2437;
    final freq = _frequency!;
    _channel = freq > 3000 ? 36 + (random % 5) : 1 + (random % 11);
    _band = freq > 3000 ? '5 GHz' : '2.4 GHz';
    _security = 'WPA2-PSK';
    _standard = '802.11ax (Wi-Fi 6)';
    _txSpeed = 1200 + (random % 200);
    _rxSpeed = 1200 + (random % 200);
    _connectionType = 'WIFI';
    _connectionStatus = 'Connected';
    _isConnected = true;
    _isMetered = false;
    _capabilities = ['INTERNET', 'NOT_METERED', 'VALIDATED'];
    _downstreamBandwidth = 1000000;
    _upstreamBandwidth = 1000000;
    notifyListeners();
  }

  void _startMonitoring() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: _refreshInterval), (timer) {
      updateWifiDetails();
    });
    updateWifiDetails();
  }

  Future<void> updateWifiDetails() async {
    if (Platform.isAndroid) {
      bool isConnected = await WiFiForIoTPlugin.isConnected();
      if (isConnected) {
        _status = 'Connected';

        final wifiInfo = await WifiService.getWifiInfo();
        if (wifiInfo != null) {
          _rssi = wifiInfo['rssi'] as int?;
          _signalStrength = _rssi;
          _speed = wifiInfo['linkSpeed'] as int?;
          _frequency = wifiInfo['frequency'] as int?;
          _channel = wifiInfo['channel'] as int?;
          _band = wifiInfo['band'] as String?;
          _security = wifiInfo['security'] as String?;
          _standard = wifiInfo['standard'] as String?;
          _txSpeed = wifiInfo['txLinkSpeed'] as int?;
          _rxSpeed = wifiInfo['rxLinkSpeed'] as int?;
          _bssid = wifiInfo['bssid'] as String?;
          _clientMac = wifiInfo['macAddress'] as String?;

          final ssid = wifiInfo['ssid'] as String?;
          if (ssid != null && ssid != '<unknown ssid>') {
            _ssid = ssid;
          }
        } else {
          _signalStrength = await WiFiForIoTPlugin.getCurrentSignalStrength();
          _speed = await WifiService.getLinkSpeed();
          _frequency = await WifiService.getFrequency();
          _clientMac = await WifiService.getMacAddress();
        }

        final connInfo = await WifiService.getConnectivityInfo();
        if (connInfo != null) {
          _connectionType = connInfo['type'] as String?;
          _connectionStatus = connInfo['status'] as String?;
          _isConnected = connInfo['isConnected'] as bool?;
          _capabilities = (connInfo['capabilities'] as List?)?.cast<String>();
          _downstreamBandwidth = connInfo['downstreamBandwidth'] as int?;
          _upstreamBandwidth = connInfo['upstreamBandwidth'] as int?;
          _isMetered = connInfo['isMetered'] as bool?;
        }

        _ip = await WifiService.getIpAddress();
        _gateway = await WifiService.getGateway();
        _dns = await WifiService.getDns();

        if (_clientMac == null || _clientMac == "02:00:00:00:00:00") {
          _clientMac = "Locked by OS";
        }
      } else {
        _resetDetails();
      }
    } else if (Platform.isLinux) {
      try {
        var result = await Process.run('nmcli', [
          '-t',
          '-f',
          'ACTIVE,SSID,BSSID,SIGNAL',
          'dev',
          'wifi',
        ]);
        if (result.exitCode == 0) {
          var lines = result.stdout.toString().split('\n');
          bool found = false;
          for (var line in lines) {
            if (line.startsWith('yes:')) {
              var parts = line.split(':');
              if (parts.length >= 4) {
                _status = 'Connected';
                _ssid = parts[1];
                _bssid = parts[2].replaceAll('\\', '');
                _signalStrength = int.tryParse(parts[3]);
                found = true;
                break;
              }
            }
          }
          if (!found) {
            _resetDetails();
          } else {
            // Get IP, Gateway, DNS, and MAC from nmcli
            var ifaceResult = await Process.run('nmcli', [
              '-t',
              '-f',
              'DEVICE,TYPE,STATE,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS',
              'dev',
              'show',
            ]);
            if (ifaceResult.exitCode == 0) {
              var output = ifaceResult.stdout.toString();
              var blocks = output.split('\n\n');
              for (var block in blocks) {
                if (block.contains('TYPE:wifi') &&
                    block.contains('STATE:connected')) {
                  // IP
                  RegExp ipRegex = RegExp(r'IP4.ADDRESS\[\d+\]:(.+)/');
                  var ipMatch = ipRegex.firstMatch(block);
                  if (ipMatch != null) _ip = ipMatch.group(1);

                  // Gateway
                  RegExp gwRegex = RegExp(r'IP4.GATEWAY:(.+)');
                  var gwMatch = gwRegex.firstMatch(block);
                  if (gwMatch != null) _gateway = gwMatch.group(1)!.trim();

                  // DNS
                  RegExp dnsRegex = RegExp(r'IP4.DNS\[\d+\]:(.+)');
                  var dnsMatches = dnsRegex.allMatches(block);
                  if (dnsMatches.isNotEmpty) {
                    _dns = dnsMatches.map((m) => m.group(1)!.trim()).join(', ');
                  }

                  // MAC
                  RegExp devRegex = RegExp(r'GENERAL.DEVICE:(.+)');
                  var devMatch = devRegex.firstMatch(block);
                  if (devMatch != null) {
                    var device = devMatch.group(1)!.trim();
                    var macRes = await Process.run('cat', [
                      '/sys/class/net/$device/address',
                    ]);
                    if (macRes.exitCode == 0) {
                      _clientMac = macRes.stdout
                          .toString()
                          .trim()
                          .toUpperCase();
                    }
                  }
                }
              }
            }
          }
        } else {
          _resetDetails();
        }
      } catch (e) {
        _status = 'Unavailable';
      }
    }
    notifyListeners();
  }

  void _resetDetails() {
    _signalStrength = null;
    _status = 'Disconnected';
    _ssid = null;
    _bssid = null;
    _ip = null;
    _gateway = null;
    _dns = null;
    _clientMac = null;
    _speed = null;
    _frequency = null;
    _rssi = null;
    _channel = null;
    _band = null;
    _security = null;
    _standard = null;
    _txSpeed = null;
    _rxSpeed = null;
    _connectionType = null;
    _connectionStatus = null;
    _isConnected = null;
    _capabilities = null;
    _downstreamBandwidth = null;
    _upstreamBandwidth = null;
    _isMetered = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> setDemoMode(bool enabled) async {
    _isDemoMode = enabled;
    await _saveConfig();
    if (enabled) {
      _timer?.cancel();
      _startDemoMode();
    } else {
      await _loadConfig();
    }
  }

  Future<void> setRefreshInterval(int seconds) async {
    _refreshInterval = seconds;
    await _saveConfig();
    if (!_isDemoMode && _isMonitoring) {
      _startMonitoring();
    }
  }
}
