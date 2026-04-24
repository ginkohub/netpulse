import 'dart:async';
import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';
import '../database/database.dart' show AppDatabase;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'log_service.dart';

class PingResultModel {
  final String id;
  String host;
  String? name;
  int? latency;
  bool isOnline;
  String? error;
  bool isPaused;
  int interval;
  DateTime? lastPingTime;
  List<int> history;

  PingResultModel({
    required this.id,
    required this.host,
    this.name,
    this.latency,
    this.isOnline = false,
    this.error,
    this.isPaused = false,
    this.interval = 1,
    this.lastPingTime,
    List<int>? history,
  }) : history = history ?? [];
}

enum DashboardItemType { wifi, mikrotik, speedtest, ping }

class DashboardItem {
  final DashboardItemType type;
  final String? value;

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

class PingProvider extends ChangeNotifier with WidgetsBindingObserver {
  final LogProvider? logger;
  final Map<String, PingResultModel> _results = {};
  List<DashboardItem> _items = [];
  static const String _storageKey = 'cards';
  static const String _reorderEnabledKey = 'reorder_enabled';
  static const String _pingIntervalKey = 'ping_interval';
  static const String _pauseOnBackgroundKey = 'pause_on_background';
  static const String _demoModeKey = 'demo_mode';

  bool _isReorderEnabled = false;
  bool get isReorderEnabled => _isReorderEnabled;

  bool _isDemoMode = false;
  bool get isDemoMode => _isDemoMode;

  int _pingInterval = 1;
  int get pingInterval => _pingInterval;

  bool _pauseOnBackground = true;
  bool get pauseOnBackground => _pauseOnBackground;

  bool _isLooping = false;
  bool _isBackgrounded = false;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySub;
  bool _hasNetwork = true;

  List<DashboardItem> get items => _items;

  PingResultModel? getResult(String id) => _results[id];

  PingProvider({this.logger}) {
    WidgetsBinding.instance.addObserver(this);
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
    _pingInterval = await AppDatabase.getSetting<int>(_pingIntervalKey) ?? 1;
    _pauseOnBackground =
        await AppDatabase.getSetting<bool>(_pauseOnBackgroundKey) ?? true;
    _isDemoMode = await AppDatabase.getSetting<bool>(_demoModeKey) ?? false;

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
          _results[item.value!] = PingResultModel(
            id: item.value!,
            name: config?['name'],
            host: host,
            isPaused: config?['isPaused'] ?? false,
            interval: config?['interval'] ?? _pingInterval,
            history: [],
          );
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

    // Check if host already exists to reset history instead of adding duplicate
    String? existingId;
    for (var entry in _results.entries) {
      if (entry.value.host.toLowerCase() == host.toLowerCase()) {
        existingId = entry.key;
        break;
      }
    }

    if (existingId != null) {
      final existing = _results[existingId]!;
      _results[existingId] = PingResultModel(
        id: existing.id,
        host: existing.host,
        name: existing.name,
        isPaused: existing.isPaused,
        interval: existing.interval,
      );
      if (save) {
        await AppDatabase.setPingCard(existingId, {
          'host': existing.host,
          'name': existing.name,
          'isPaused': existing.isPaused,
          'interval': existing.interval,
        });
      }
      notifyListeners();
      return;
    }

    final id = 'ping_${DateTime.now().millisecondsSinceEpoch}';
    _results[id] = PingResultModel(id: id, host: host, interval: _pingInterval);
    _items.add(DashboardItem(type: DashboardItemType.ping, value: id));
    if (save) {
      await AppDatabase.setPingCard(id, {
        'host': host,
        'isPaused': false,
        'interval': _pingInterval,
      });
      _saveToPrefs();
    }
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isBackgrounded = state == AppLifecycleState.paused;
    if (_pauseOnBackground) {
      if (_isBackgrounded) {
        logger?.addLog('App backgrounded: Pausing Ping Loop');
      } else {
        logger?.addLog('App foregrounded: Resuming Ping Loop');
      }
    }
  }

  Future<void> setPingInterval(int seconds) async {
    _pingInterval = seconds;
    notifyListeners();
    await AppDatabase.setSetting(_pingIntervalKey, seconds);
  }

  Future<void> setPauseOnBackground(bool value) async {
    _pauseOnBackground = value;
    notifyListeners();
    await AppDatabase.setSetting(_pauseOnBackgroundKey, value);
  }

  Future<void> setDemoMode(bool value) async {
    _isDemoMode = value;
    notifyListeners();
    await AppDatabase.setSetting(_demoModeKey, value);
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

  void updatePing(
    String id, {
    String? name,
    String? host,
    int? interval,
  }) async {
    final existing = _results[id];
    if (existing != null) {
      bool hostChanged =
          host != null && host.toLowerCase() != existing.host.toLowerCase();

      existing.name = name ?? existing.name;
      existing.interval = interval ?? existing.interval;
      if (host != null) {
        existing.host = host;
        if (hostChanged) {
          existing.history.clear();
          existing.latency = null;
        }
      }

      await AppDatabase.setPingCard(id, {
        'name': existing.name,
        'host': existing.host,
        'isPaused': existing.isPaused,
        'interval': existing.interval,
      });
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

  void _updatePausedState(String id, bool paused) async {
    final result = _results[id];
    if (result != null) {
      result.isPaused = paused;
      await AppDatabase.setPingCard(id, {
        'name': result.name,
        'host': result.host,
        'isPaused': result.isPaused,
      });
      notifyListeners();
    }
  }

  void toggleHost(String id) {
    final current = _results[id]?.isPaused ?? false;
    _updatePausedState(id, !current);
  }

  void pauseHost(String id) {
    _updatePausedState(id, true);
  }

  void resumeHost(String id) {
    _updatePausedState(id, false);
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
      if (!_hasNetwork || (_pauseOnBackground && _isBackgrounded)) {
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }

      final now = DateTime.now();
      final idsDue = _results.entries
          .where((e) {
            final r = e.value;
            if (r.isPaused) return false;
            if (r.lastPingTime == null) return true;
            return now.difference(r.lastPingTime!).inSeconds >= r.interval;
          })
          .map((e) => e.key)
          .toList();

      if (idsDue.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }

      for (int i = 0; i < idsDue.length; i += 3) {
        if (!_hasNetwork || (_pauseOnBackground && _isBackgrounded)) break;
        final batch = idsDue.skip(i).take(3);
        final futures = batch.map((id) => _pingSingleHost(id)).toList();
        await Future.wait(futures);
        await Future.delayed(const Duration(milliseconds: 50));
      }

      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _pingSingleHost(String id) async {
    final result = _results[id];
    if (result == null || result.isPaused) return;
    if (!_isDemoMode && !_hasNetwork) return;

    result.lastPingTime = DateTime.now();

    if (_isDemoMode) {
      final rand = DateTime.now().millisecondsSinceEpoch + id.hashCode;
      final latency = 5 + (rand % 45);
      result.latency = latency;
      result.isOnline = true;
      result.error = null;
      result.history.add(latency);
      if (result.history.length > 60) {
        result.history.removeAt(0);
      }
      _throttledNotify();
      return;
    }

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
        onDone: () async {
          if (!hasSuccess) {
            result.isOnline = false;
            result.latency = null;
            result.error ??= 'No Response';

            // Record failure as 0 for heatmap
            result.history.add(0);
          } else {
            // Update history with latency
            result.history.add(result.latency!);
          }

          if (result.history.length > 60) {
            result.history.removeAt(0);
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
      _throttledNotify();
    } catch (_) {
      result.isOnline = false;
      result.latency = null;
      _throttledNotify();
    }
  }

  DateTime? _lastNotify;
  void _throttledNotify() {
    final now = DateTime.now();
    if (_lastNotify == null ||
        now.difference(_lastNotify!) > const Duration(milliseconds: 200)) {
      _lastNotify = now;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isLooping = false;
    _connectivitySub?.cancel();
    super.dispose();
  }
}
