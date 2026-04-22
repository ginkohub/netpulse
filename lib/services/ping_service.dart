import 'dart:async';
import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/foundation.dart';
import '../database/database.dart' show AppDatabase;
import 'package:connectivity_plus/connectivity_plus.dart';

class PingResultModel {
  final String id;
  final String host;
  int? latency;
  bool isOnline;
  String? error;
  bool isPaused;

  PingResultModel({
    required this.id,
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
  final String? value; // ID or host

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
  static const String _storageKey = 'cards';
  static const String _reorderEnabledKey = 'reorder_enabled';

  bool _isReorderEnabled = false;
  bool get isReorderEnabled => _isReorderEnabled;

  bool _isLooping = false;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySub;
  bool _hasNetwork = true;

  List<DashboardItem> get items => _items;

  PingResultModel? getResult(String id) => _results[id];

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
    await AppDatabase.setSetting(_reorderEnabledKey, _isReorderEnabled);
  }

  Future<void> _loadDashboard() async {
    _isReorderEnabled =
        await AppDatabase.getSetting<bool>(_reorderEnabledKey) ?? false;

    final saved = await AppDatabase.getSetting<List<dynamic>>(_storageKey);

    if (saved == null || saved.isEmpty) {
      _items = [];
    } else {
      _items = saved
          .map((s) => DashboardItem.fromJson(Map<String, dynamic>.from(s)))
          .toList();
      final pingConfigs = await AppDatabase.getPing();
      for (var item in _items) {
        if (item.type == DashboardItemType.ping) {
          final config = pingConfigs[item.value];
          final host = config?['host'] ?? item.value ?? 'unknown';
          _results[item.value!] = PingResultModel(id: item.value!, host: host);
        }
      }
    }
    _startGlobalPingLoop();
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final data = _items.map((i) => i.toJson()).toList();
    await AppDatabase.setSetting(_storageKey, data);
  }

  void addHost(String host, {bool save = true}) async {
    if (host.isEmpty) return;
    final id = 'ping_${DateTime.now().millisecondsSinceEpoch}';
    _results[id] = PingResultModel(id: id, host: host);
    _items.add(DashboardItem(type: DashboardItemType.ping, value: id));
    if (save) {
      await AppDatabase.setPingCard(id, {'host': host});
      _saveToPrefs();
    }
    notifyListeners();
  }

  void removeHost(String id) async {
    _results.remove(id);
    _items.removeWhere(
      (i) => i.type == DashboardItemType.ping && i.value == id,
    );
    await AppDatabase.removePingCard(id);
    _saveToPrefs();
    notifyListeners();
  }

  void removeItem(DashboardItemType type, {String? value, int? index}) async {
    if (type == DashboardItemType.ping && value != null) {
      removeHost(value);
    } else if (index != null && index >= 0 && index < _items.length) {
      final item = _items[index];
      if (item.type == DashboardItemType.ping && item.value != null) {
        await AppDatabase.removePingCard(item.value!);
        _results.remove(item.value);
      } else if (item.type == DashboardItemType.mikrotik &&
          item.value != null) {
        await AppDatabase.removeMikrotikCard(item.value!);
      }
      _items.removeAt(index);
      _saveToPrefs();
      notifyListeners();
    } else {
      final idx = _items.indexWhere((i) => i.type == type && i.value == value);
      if (idx != -1) {
        final item = _items[idx];
        if (item.type == DashboardItemType.ping && item.value != null) {
          await AppDatabase.removePingCard(item.value!);
          _results.remove(item.value);
        } else if (item.type == DashboardItemType.mikrotik &&
            item.value != null) {
          await AppDatabase.removeMikrotikCard(item.value!);
        }
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

  void removeAllHosts() async {
    for (var item in _items) {
      if (item.type == DashboardItemType.ping && item.value != null) {
        await AppDatabase.removePingCard(item.value!);
      }
    }
    _results.clear();
    _items.removeWhere((i) => i.type == DashboardItemType.ping);
    _saveToPrefs();
    notifyListeners();
  }

  void updateHost(String id, String newHost) async {
    final existing = _results[id];
    if (existing != null) {
      _results[id] = PingResultModel(
        id: id,
        host: newHost,
        latency: existing.latency,
        isOnline: existing.isOnline,
      );
      await AppDatabase.setPingCard(id, {'host': newHost});
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

  void toggleHost(String id) {
    _results[id]?.isPaused = !(_results[id]?.isPaused ?? false);
    notifyListeners();
  }

  void pauseHost(String id) {
    _results[id]?.isPaused = true;
    notifyListeners();
  }

  void resumeHost(String id) {
    _results[id]?.isPaused = false;
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

      final ids = _results.keys.toList();
      if (ids.isEmpty) {
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }

      for (int i = 0; i < ids.length; i += 3) {
        if (!_hasNetwork) break;
        final batch = ids.skip(i).take(3);
        final futures = batch.map((id) => _pingSingleHost(id)).toList();
        await Future.wait(futures);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> _pingSingleHost(String id) async {
    final result = _results[id];
    if (result == null || result.isPaused || !_hasNetwork) return;

    try {
      final ping = Ping(result.host, count: 1, timeout: 2);
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
