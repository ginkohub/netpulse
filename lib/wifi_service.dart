import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class WifiProvider extends ChangeNotifier {
  final NetworkInfo _networkInfo = NetworkInfo();
  final Connectivity _connectivity = Connectivity();

  int? _signalStrength;
  String _status = 'Disconnected';
  String? _ssid;
  String? _bssid;
  String? _ip;
  String? _clientMac;

  bool _isMonitoring = true;
  int _refreshInterval = 5;
  Timer? _timer;
  StreamSubscription? _connectivitySub;

  int? get signalStrength => _signalStrength;
  String get status => _status;
  String? get ssid => _ssid;
  String? get bssid => _bssid;
  String? get ip => _ip;
  String? get clientMac => _clientMac;
  bool get isMonitoring => _isMonitoring;
  int get refreshInterval => _refreshInterval;

  WifiProvider() {
    _loadConfig();
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      updateWifiDetails();
    });
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _refreshInterval = prefs.getInt('wifi_refresh') ?? 5;
    _isMonitoring = prefs.getBool('wifi_monitor') ?? true;

    if (Platform.isAndroid) {
      await Permission.location.request();
    }

    if (_isMonitoring) {
      _startMonitoring();
    } else {
      updateWifiDetails();
    }
  }

  Future<void> setRefreshInterval(int seconds) async {
    _refreshInterval = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('wifi_refresh', seconds);
    if (_isMonitoring) {
      _startMonitoring();
    }
    notifyListeners();
  }

  void toggleMonitoring() async {
    _isMonitoring = !_isMonitoring;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wifi_monitor', _isMonitoring);

    if (_isMonitoring) {
      _startMonitoring();
    } else {
      _timer?.cancel();
    }
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
        _signalStrength = await WiFiForIoTPlugin.getCurrentSignalStrength();
        _status = 'Connected';
        _ssid = await _networkInfo.getWifiName();
        _bssid = await _networkInfo.getWifiBSSID();
        _ip = await _networkInfo.getWifiIP();
        _clientMac = "Protected";
      } else {
        _resetDetails();
      }
    } else if (Platform.isLinux) {
      try {
        var result = await Process.run('nmcli', ['-t', '-f', 'ACTIVE,SSID,BSSID,SIGNAL', 'dev', 'wifi']);
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
            var ifaceResult = await Process.run('nmcli', ['-t', '-f', 'DEVICE,TYPE,STATE,IP4.ADDRESS', 'dev', 'show']);
            if (ifaceResult.exitCode == 0) {
              var output = ifaceResult.stdout.toString();
              var blocks = output.split('\n\n');
              for (var block in blocks) {
                if (block.contains('TYPE:wifi') && block.contains('STATE:connected')) {
                  RegExp ipRegex = RegExp(r'IP4.ADDRESS\[\d+\]:(.+)/');
                  var ipMatch = ipRegex.firstMatch(block);
                  if (ipMatch != null) _ip = ipMatch.group(1);

                  RegExp devRegex = RegExp(r'GENERAL.DEVICE:(.+)');
                  var devMatch = devRegex.firstMatch(block);
                  if (devMatch != null) {
                    var device = devMatch.group(1)!.trim();
                    var macRes = await Process.run('cat', ['/sys/class/net/$device/address']);
                    if (macRes.exitCode == 0) _clientMac = macRes.stdout.toString().trim();
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
    _clientMac = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
