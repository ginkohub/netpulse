import 'dart:async';
import 'dart:io';
import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';
import '../database/database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'log_service.dart';

class PingResultModel {
  final String id;
  String host;
  String? name;
  int? latency;
  bool isOnline;
  String? error;
  bool isPaused;
  bool keepAliveInBackground;
  bool notifyOnTimeout;
  bool notifyOnHighLatency;
  int latencyThresholdPercent;
  int interval;
  DateTime? lastPingTime;
  DateTime? lastNotifyTime;
  String? lastAlertedState;
  List<int> history;

  PingResultModel({
    required this.id,
    required this.host,
    this.name,
    this.latency,
    this.isOnline = false,
    this.error,
    this.isPaused = false,
    this.keepAliveInBackground = false,
    this.notifyOnTimeout = false,
    this.notifyOnHighLatency = false,
    this.latencyThresholdPercent = 50,
    this.interval = 1,
    this.lastPingTime,
    this.lastNotifyTime,
    this.lastAlertedState,
    List<int>? history,
  }) : history = history ?? [];

  String get displayName => (name != null && name!.isNotEmpty) ? name! : host;

  double get averageLatency {
    final validPings = history.where((l) => l >= 0).toList();
    if (validPings.isEmpty) return 0;
    return validPings.reduce((a, b) => a + b) / validPings.length;
  }
}

class PingProvider extends ChangeNotifier with WidgetsBindingObserver {
  final LogProvider? logger;
  final Map<String, PingResultModel> _results = {};
  
  static const String _pingIntervalKey = 'ping_interval';
  static const String _pauseOnBackgroundKey = 'pause_on_background';
  static const String _demoModeKey = 'demo_mode';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _groupKey = 'com.ginkohub.netpulse.PING_ALERTS';

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

  PingResultModel? getResult(String id) => _results[id];
  List<PingResultModel> get allResults => _results.values.toList();

  PingProvider({this.logger}) {
    WidgetsBinding.instance.addObserver(this);
    _initNotifications();
    _loadSettings();
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      _checkConnectivity(results);
    });
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open',
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      linux: linuxSettings,
    );
    await _notificationsPlugin.initialize(settings: initSettings);

    if (Platform.isAndroid) {
      final plugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (plugin != null) {
        await plugin.requestNotificationsPermission();
      }
    }
  }

  Future<void> _loadSettings() async {
    _pingInterval = await AppDatabase.getSetting<int>(_pingIntervalKey) ?? 1;
    _pauseOnBackground =
        await AppDatabase.getSetting<bool>(_pauseOnBackgroundKey) ?? true;
    _isDemoMode = await AppDatabase.getSetting<bool>(_demoModeKey) ?? false;

    final pingConfigs = await AppDatabase.getPing();
    pingConfigs.forEach((id, cfg) {
      final config = Map<String, dynamic>.from(cfg);
      _results[id] = PingResultModel(
        id: id,
        name: config['name'],
        host: config['host'] ?? 'unknown',
        isPaused: config['isPaused'] ?? false,
        keepAliveInBackground: config['keepAliveInBackground'] ?? false,
        notifyOnTimeout: config['notifyOnTimeout'] ?? false,
        notifyOnHighLatency: config['notifyOnHighLatency'] ?? false,
        latencyThresholdPercent: config['latencyThresholdPercent'] ?? 50,
        interval: config['interval'] ?? _pingInterval,
        history: [],
      );
    });
    
    _startGlobalPingLoop();
    notifyListeners();
  }

  Future<void> _sendNotification(String title, String body) async {
    const channel = AndroidNotificationChannel(
      'ping_alerts',
      'Ping Alerts',
      description: 'Notifications for ping timeouts and high latency',
      importance: Importance.high,
    );

    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: channel.importance,
      priority: Priority.high,
      groupKey: _groupKey,
    );

    const linuxDetails = LinuxNotificationDetails();
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    await _notificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch.hashCode,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );

    if (Platform.isAndroid) {
      final summaryAndroidDetails = AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: Priority.high,
        groupKey: _groupKey,
        setAsGroupSummary: true,
      );
      final summaryDetails = NotificationDetails(
        android: summaryAndroidDetails,
      );
      await _notificationsPlugin.show(
        id: 0,
        title: 'Network Alerts',
        body: 'Multiple issues detected',
        notificationDetails: summaryDetails,
      );
    }
  }

  Future<void> _checkConnectivity(List<ConnectivityResult> results) async {
    final oldHasNetwork = _hasNetwork;
    _hasNetwork =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);

    if (!_hasNetwork) {
      for (var result in _results.values) {
        result.isOnline = false;
        result.latency = null;
        result.error = 'No Network';
      }
      _throttledNotify();
    } else if (!oldHasNetwork && _hasNetwork) {
      for (var result in _results.values) {
        if (result.error == 'No Network') {
          result.error = null;
        }
      }
      _throttledNotify();
    }
  }

  void addHost(String id, String host, {bool save = true}) async {
    if (host.isEmpty) return;

    _results[id] = PingResultModel(
      id: id,
      host: host,
      interval: _pingInterval,
      notifyOnTimeout: false,
      notifyOnHighLatency: false,
      latencyThresholdPercent: 50,
    );
    
    if (save) {
      await AppDatabase.setPingCard(id, {
        'host': host,
        'isPaused': false,
        'keepAliveInBackground': false,
        'notifyOnTimeout': false,
        'notifyOnHighLatency': false,
        'latencyThresholdPercent': 50,
        'interval': _pingInterval,
      });
    }
    notifyListeners();
  }

  void removeHost(String id) async {
    _results.remove(id);
    await AppDatabase.removePingCard(id);
    notifyListeners();
  }

  void removeAllHosts() async {
    final ids = _results.keys.toList();
    for (var id in ids) {
      await AppDatabase.removePingCard(id);
    }
    _results.clear();
    notifyListeners();
  }

  void updatePing(
    String id, {
    String? name,
    String? host,
    int? interval,
    bool? keepAliveInBackground,
    bool? notifyOnTimeout,
    bool? notifyOnHighLatency,
    int? latencyThresholdPercent,
  }) async {
    final existing = _results[id];
    if (existing != null) {
      bool hostChanged =
          host != null && host.toLowerCase() != existing.host.toLowerCase();

      existing.name = name ?? existing.name;
      existing.interval = interval ?? existing.interval;
      if (keepAliveInBackground != null) {
        existing.keepAliveInBackground = keepAliveInBackground;
      }
      if (notifyOnTimeout != null) {
        existing.notifyOnTimeout = notifyOnTimeout;
      }
      if (notifyOnHighLatency != null) {
        existing.notifyOnHighLatency = notifyOnHighLatency;
      }
      if (latencyThresholdPercent != null) {
        existing.latencyThresholdPercent = latencyThresholdPercent;
      }

      if (hostChanged) {
        existing.host = host;
        existing.latency = null;
        existing.history.clear();
      }

      await AppDatabase.setPingCard(id, {
        'host': existing.host,
        'name': existing.name,
        'isPaused': existing.isPaused,
        'keepAliveInBackground': existing.keepAliveInBackground,
        'notifyOnTimeout': existing.notifyOnTimeout,
        'notifyOnHighLatency': existing.notifyOnHighLatency,
        'latencyThresholdPercent': existing.latencyThresholdPercent,
        'interval': existing.interval,
      });
      notifyListeners();
    }
  }

  void toggleHost(String id) async {
    final result = _results[id];
    if (result != null) {
      result.isPaused = !result.isPaused;
      await AppDatabase.setPingCard(id, {
        'host': result.host,
        'name': result.name,
        'isPaused': result.isPaused,
        'keepAliveInBackground': result.keepAliveInBackground,
        'notifyOnTimeout': result.notifyOnTimeout,
        'notifyOnHighLatency': result.notifyOnHighLatency,
        'latencyThresholdPercent': result.latencyThresholdPercent,
        'interval': result.interval,
      });
      notifyListeners();
    }
  }

  void reloadHosts() async {
    final pingConfigs = await AppDatabase.getPing();
    _results.clear();
    pingConfigs.forEach((id, cfg) {
      final config = Map<String, dynamic>.from(cfg);
      _results[id] = PingResultModel(
        id: id,
        name: config['name'],
        host: config['host'] ?? 'unknown',
        isPaused: config['isPaused'] ?? false,
        keepAliveInBackground: config['keepAliveInBackground'] ?? false,
        notifyOnTimeout: config['notifyOnTimeout'] ?? false,
        notifyOnHighLatency: config['notifyOnHighLatency'] ?? false,
        latencyThresholdPercent: config['latencyThresholdPercent'] ?? 50,
        interval: config['interval'] ?? _pingInterval,
        history: [],
      );
    });
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

  void _startGlobalPingLoop() {
    if (_isLooping) return;
    _isLooping = true;
    _runPingLoop();
  }

  Future<void> _runPingLoop() async {
    while (_isLooping) {
      final now = DateTime.now();

      if (!_hasNetwork && !_isDemoMode) {
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }

      if (_isBackgrounded && _pauseOnBackground && !_isDemoMode) {
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }

      final List<Future<void>> pingTasks = [];

      for (var result in _results.values) {
        if (result.isPaused) continue;

        final bool shouldPing =
            result.lastPingTime == null ||
            now.difference(result.lastPingTime!).inSeconds >= result.interval;

        if (shouldPing) {
          if (_isBackgrounded && !result.keepAliveInBackground && !_isDemoMode) {
            continue;
          }
          pingTasks.add(_pingSingleHost(result.id));
        }
      }

      if (pingTasks.isNotEmpty) {
        await Future.wait(pingTasks);
      }

      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _pingSingleHost(String id) async {
    final result = _results[id];
    if (result == null || result.isPaused) return;
    
    result.lastPingTime = DateTime.now();

    if (_isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 100));
      result.isOnline = true;
      result.latency = 20 + (DateTime.now().millisecond % 50);
      result.error = null;
      result.history.add(result.latency!);
      if (result.history.length > 60) result.history.removeAt(0);
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
          final now = DateTime.now();
          final avg = result.averageLatency;
          String currentState = 'normal';

          if (!hasSuccess) {
            currentState = 'timeout';
          } else if (result.notifyOnHighLatency && avg > 0) {
            final threshold = avg * (1 + result.latencyThresholdPercent / 100);
            if (result.latency! >= threshold) {
              currentState = 'high_latency';
            }
          }

          bool shouldNotify = false;
          String alertTitle = '';
          String alertBody = '';

          if (currentState != result.lastAlertedState) {
            if (currentState == 'timeout' && result.notifyOnTimeout) {
              shouldNotify = true;
              alertTitle = 'Timeout: ${result.displayName}';
              alertBody = 'Device is unreachable';
            } else if (currentState == 'high_latency' &&
                result.notifyOnHighLatency) {
              shouldNotify = true;
              alertTitle = 'High Latency: ${result.displayName}';
              alertBody =
                  '${result.latency}ms (Avg: ${avg.toStringAsFixed(1)}ms)';
            } else if (currentState == 'normal' &&
                result.lastAlertedState != null &&
                result.lastAlertedState != 'normal' &&
                (result.notifyOnTimeout || result.notifyOnHighLatency)) {
              shouldNotify = true;
              alertTitle = 'Recovered: ${result.displayName}';
              alertBody = 'Connection is back to normal (${result.latency}ms)';
            }
            result.lastAlertedState = currentState;
          } else if (currentState != 'normal') {
            bool toggleOn = (currentState == 'timeout' && result.notifyOnTimeout) ||
                            (currentState == 'high_latency' && result.notifyOnHighLatency);
            
            if (toggleOn && (result.lastNotifyTime == null ||
                now.difference(result.lastNotifyTime!) >
                    const Duration(minutes: 5))) {
              shouldNotify = true;
              if (currentState == 'timeout') {
                alertTitle = 'Still Timeout: ${result.displayName}';
                alertBody = 'Device remains unreachable';
              } else {
                alertTitle = 'Still High Latency: ${result.displayName}';
                alertBody =
                    '${result.latency}ms (Avg: ${avg.toStringAsFixed(1)}ms)';
              }
            }
          }

          if (shouldNotify) {
            result.lastNotifyTime = now;
            _sendNotification(alertTitle, alertBody);
          }

          if (!hasSuccess) {
            result.history.add(-1);
          } else {
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
    _isLooping = false;
    _connectivitySub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
