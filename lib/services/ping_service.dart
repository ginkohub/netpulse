import 'dart:async';
import 'dart:convert';
import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class PingResultModel {
  final String host;
  int? latency;
  bool isOnline;
  String? error;
  bool isPaused;

  PingResultModel({
    required this.host,
    this.latency,
    this.isOnline = false,
    this.error,
    this.isPaused = false,
  });
}

enum DashboardItemType { wifi, mikrotik, speedtest, ping }

class DashboardItem {
  final DashboardItemType type;
  final String? value; // host for ping, null for others

  DashboardItem({required this.type, this.value});

  Map<String, dynamic> toJson() => {'type': type.index, 'value': value};

  factory DashboardItem.fromJson(Map<String, dynamic> json) => DashboardItem(
    type: DashboardItemType.values[json['type']],
    value: json['value'],
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashboardItem &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          value == other.value;

  @override
  int get hashCode => type.hashCode ^ value.hashCode;
}

class PingProvider extends ChangeNotifier {
  final Map<String, PingResultModel> _results = {};
  List<DashboardItem> _items = [];
  static const String _storageKey = 'dashboard_items';
  static const String _reorderEnabledKey = 'reorder_enabled';

  bool _isReorderEnabled = false;
  bool get isReorderEnabled => _isReorderEnabled;

  bool _isLooping = false;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySub;
  bool _hasNetwork = true;

  List<DashboardItem> get items => _items;

  PingResultModel? getResult(String host) => _results[host];

  PingProvider() {
    _loadDashboard();
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      _checkConnectivity(results);
    });
  }

  Future<void> _checkConnectivity(List<ConnectivityResult> results) async {
    _hasNetwork =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);
    if (!_hasNetwork) {
      for (var result in _results.values) {
        result.isOnline = false;
        result.latency = null;
        result.error = 'No Network';
      }
      notifyListeners();
    }
  }

  void toggleReorder() async {
    _isReorderEnabled = !_isReorderEnabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reorderEnabledKey, _isReorderEnabled);
  }

  Future<void> _loadDashboard() async {
    final prefs = await SharedPreferences.getInstance();
    _isReorderEnabled = prefs.getBool(_reorderEnabledKey) ?? false;

    final saved = prefs.getStringList(_storageKey);

    if (saved == null || saved.isEmpty) {
      _items = [];
    } else {
      _items = saved.map((s) => DashboardItem.fromJson(jsonDecode(s))).toList();
      for (var item in _items) {
        if (item.type == DashboardItemType.ping) {
          _results[item.value!] = PingResultModel(host: item.value!);
        }
      }
    }
    _startGlobalPingLoop();
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _items.map((i) => jsonEncode(i.toJson())).toList();
    await prefs.setStringList(_storageKey, data);
  }

  void addHost(String host, {bool save = true}) {
    if (_results.containsKey(host) || host.isEmpty) return;
    _results[host] = PingResultModel(host: host);
    _items.add(DashboardItem(type: DashboardItemType.ping, value: host));
    if (save) _saveToPrefs();
    notifyListeners();
  }

  void removeHost(String host) {
    _results.remove(host);
    _items.removeWhere(
      (i) => i.type == DashboardItemType.ping && i.value == host,
    );
    _saveToPrefs();
    notifyListeners();
  }

  void removeItem(DashboardItemType type, {String? value, int? index}) {
    if (type == DashboardItemType.ping && value != null) {
      removeHost(value);
    } else if (index != null && index >= 0 && index < _items.length) {
      _items.removeAt(index);
      _saveToPrefs();
      notifyListeners();
    } else {
      final idx = _items.indexWhere((i) => i.type == type && i.value == value);
      if (idx != -1) {
        _items.removeAt(idx);
        _saveToPrefs();
        notifyListeners();
      }
    }
  }

  void addItem(DashboardItemType type, {String? value}) {
    if (type == DashboardItemType.ping) {
      if (value != null && value.isNotEmpty) {
        addHost(value);
      }
    } else if (type == DashboardItemType.wifi ||
        type == DashboardItemType.speedtest) {
      if (!_items.any((i) => i.type == type)) {
        _items.add(DashboardItem(type: type, value: value));
        _saveToPrefs();
        notifyListeners();
      }
    } else {
      final newValue =
          value ?? '${type.name}_${DateTime.now().millisecondsSinceEpoch}';
      _items.add(DashboardItem(type: type, value: newValue));
      _saveToPrefs();
      notifyListeners();
    }
  }

  void removeAllHosts() {
    _results.clear();
    _items.removeWhere((i) => i.type == DashboardItemType.ping);
    _saveToPrefs();
    notifyListeners();
  }

  void updateHost(String oldHost, String newHost) {
    final existing = _results.remove(oldHost);
    if (existing != null) {
      _results[newHost] = PingResultModel(
        host: newHost,
        latency: existing.latency,
        isOnline: existing.isOnline,
      );
      final idx = _items.indexWhere(
        (i) => i.type == DashboardItemType.ping && i.value == oldHost,
      );
      if (idx != -1) {
        _items[idx] = DashboardItem(
          type: DashboardItemType.ping,
          value: newHost,
        );
      }
      _saveToPrefs();
      notifyListeners();
    }
  }

  void reorderItems(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
    _saveToPrefs();
    notifyListeners();
  }

  void toggleHost(String host) {
    _results[host]?.isPaused = !(_results[host]?.isPaused ?? false);
    notifyListeners();
  }

  void pauseHost(String host) {
    _results[host]?.isPaused = true;
    notifyListeners();
  }

  void resumeHost(String host) {
    _results[host]?.isPaused = false;
    notifyListeners();
  }

  Future<void> reloadHosts() async {
    _results.clear();
    _items.clear();
    await _loadDashboard();
    notifyListeners();
  }

  void _startGlobalPingLoop() {
    if (_isLooping) return;
    _isLooping = true;
    _runNextPingBatch();
  }

  Future<void> _runNextPingBatch() async {
    while (_isLooping) {
      if (!_hasNetwork) {
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }

      final hosts = _results.keys.toList();
      if (hosts.isEmpty) {
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }

      for (int i = 0; i < hosts.length; i += 3) {
        if (!_hasNetwork) break;
        final batch = hosts.skip(i).take(3);
        final futures = batch.map((h) => _pingSingleHost(h)).toList();
        await Future.wait(futures);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> _pingSingleHost(String host) async {
    final result = _results[host];
    if (result == null || result.isPaused || !_hasNetwork) return;

    try {
      final ping = Ping(host, count: 1, timeout: 2);
      final completer = Completer<void>();
      bool hasSuccess = false;

      ping.stream.listen(
        (event) {
          if (event.response != null && event.response!.time != null) {
            result.latency = event.response!.time!.inMilliseconds;
            result.isOnline = true;
            result.error = null;
            hasSuccess = true;
          } else if (event.error != null) {
            result.isOnline = false;
            result.latency = null;
            result.error = 'Unreachable';
            hasSuccess = false;
          }
        },
        onDone: () {
          if (!hasSuccess) {
            result.isOnline = false;
            result.latency = null;
          }
          completer.complete();
        },
      );

      await completer.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          if (!hasSuccess) {
            result.isOnline = false;
            result.latency = null;
            result.error = 'Timeout';
          }
        },
      );
      notifyListeners();
    } catch (_) {
      result.isOnline = false;
      result.latency = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isLooping = false;
    _connectivitySub?.cancel();
    super.dispose();
  }
}
