import 'dart:async';
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

class PingProvider extends ChangeNotifier {
  final Map<String, PingResultModel> _results = {};
  static const String _storageKey = 'saved_hosts';

  bool _isLooping = false;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySub;
  bool _hasNetwork = true;

  List<PingResultModel> get results => _results.values.toList();

  PingProvider() {
    _loadHosts();
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      _checkConnectivity(results);
    });
  }

  Future<void> _checkConnectivity(List<ConnectivityResult> results) async {
    _hasNetwork = results.isNotEmpty && !results.contains(ConnectivityResult.none);
    if (!_hasNetwork) {
      for (var result in _results.values) {
        result.isOnline = false;
        result.latency = null;
        result.error = 'No Network';
      }
      notifyListeners();
    }
  }

  Future<void> _loadHosts() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHosts = prefs.getStringList(_storageKey);

    if (savedHosts == null || savedHosts.isEmpty) {
      addHost('8.8.8.8', save: false);
      addHost('1.1.1.1', save: false);
      addHost('google.com', save: false);
      _saveToPrefs();
    } else {
      for (var host in savedHosts) {
        addHost(host, save: false);
      }
    }
    _startGlobalPingLoop();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, _results.keys.toList());
  }

  void addHost(String host, {bool save = true}) {
    if (_results.containsKey(host) || host.isEmpty) return;
    _results[host] = PingResultModel(host: host);
    if (save) _saveToPrefs();
    notifyListeners();
  }

  void removeHost(String host) {
    _results.remove(host);
    _saveToPrefs();
    notifyListeners();
  }

  void removeAllHosts() {
    _results.clear();
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

      ping.stream.listen((event) {
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
      }, onDone: () {
        if (!hasSuccess) {
          result.isOnline = false;
          result.latency = null;
        }
        completer.complete();
      });

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
