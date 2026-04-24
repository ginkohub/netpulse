import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:routeros_api/routeros_api.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/mikrotik.dart';
import '../database/database.dart';
import '../utils/parser.dart';
import '../utils/formater.dart';
import 'log_service.dart';

class MikrotikInstance extends ChangeNotifier {
  final String key;
  final LogProvider? logger;

  MikrotikConfig _config = const MikrotikConfig();
  bool _isConnected = false;
  bool _isLoading = false;
  bool _isFetching = false;
  String _status = 'Disconnected';
  int _activeUsersCount = 0;
  int _cpuLoad = 0;
  List<MikrotikUser> _activeUsers = [];
  List<InterfaceStat> _interfaceStats = [];
  MikrotikSystem? _system;

  RouterOSClient? _client;
  Timer? _timer;
  final Map<String, int> _prevBytesIn = {};
  final Map<String, int> _prevBytesOut = {};

  MikrotikConfig get config => _config;
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  String get status => _status;
  int get activeUsersCount => _activeUsersCount;
  int get cpuLoad => _cpuLoad;
  List<MikrotikUser> get activeUsers => _activeUsers;
  List<InterfaceStat> get interfaceStats => _interfaceStats;
  MikrotikSystem? get system => _system;

  MikrotikInstance({required this.key, this.logger});

  Future<void> loadConfig() async {
    final card = await AppDatabase.getMikrotikCard(key);
    _config = MikrotikConfig(
      host: card?['host'] ?? '',
      port: card?['port'] ?? 8728,
      user: card?['user'] ?? '',
      pass: card?['pass'] ?? '',
      monitoredInterfaces: card?['ifaces'] ?? '',
      refreshInterval: card?['refresh'] ?? 2,
      isMonitoring: card?['monitor'] ?? false,
      isDemoMode: card?['demo'] ?? false,
    );
    notifyListeners();

    if (_config.isMonitoring &&
        (_config.host.isNotEmpty || _config.isDemoMode)) {
      if (_config.isDemoMode) {
        startDemoMode();
      } else {
        connect();
      }
    }
  }

  Future<void> saveConfig(MikrotikConfig newConfig) async {
    _config = newConfig;
    await AppDatabase.setMikrotikCard(key, {
      'host': _config.host,
      'port': _config.port,
      'user': _config.user,
      'pass': _config.pass,
      'ifaces': _config.monitoredInterfaces,
      'refresh': _config.refreshInterval,
      'monitor': _config.isMonitoring,
      'demo': _config.isDemoMode,
    });
    notifyListeners();
  }

  void startDemoMode() {
    _timer?.cancel();
    _isConnected = true;
    _status = 'Demo Mode';
    notifyListeners();

    _generateDemoData();
    _timer = Timer.periodic(
      Duration(seconds: _config.refreshInterval),
      (_) => _generateDemoData(),
    );
  }

  void _generateDemoData() {
    final random = DateTime.now().millisecondsSinceEpoch;
    final userCount = 5 + (random % 50);
    final interfaces = _config.monitoredInterfaces
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final seen = <String>{};
    final ifStats = interfaces.where((name) => seen.add(name)).map((name) {
      final rx = (random % 100000000) + 1000000;
      final tx = (random % 50000000) + 500000;
      return InterfaceStat(
        name: name,
        rxRate: formatSpeed(rx),
        txRate: formatSpeed(tx),
        enabled: true,
      );
    }).toList();

    final users = List.generate(userCount.clamp(0, 20), (i) {
      final idx = (random + i * 7) % 100;
      return MikrotikUser(
        id: 'demo_$i',
        name: 'user$i',
        address: '192.168.1.${10 + idx}',
        uptime: '${(random ~/ 3600) % 24}h${(random ~/ 60) % 60}m',
        bytesIn: formatBytes(random * 1000),
        bytesOut: formatBytes(random * 500),
        rxRate: formatSpeed(random % 10000),
        txRate: formatSpeed(random % 5000),
      );
    });

    _activeUsersCount = userCount;
    _interfaceStats = ifStats;
    _activeUsers = users;
    _system = MikrotikSystem(
      name: 'Demo-MikroTik',
      uptime: '${(random ~/ 3600) % 24}h${(random ~/ 60) % 60}m',
      version: '7.15.5',
      buildTime: '2024-01-15',
      factorySoftware: '7.14.1',
      boardName: 'RB760iGS',
      architectureName: 'arm',
      cpu: 'ARMv7',
      cpuCount: 4,
      cpuLoad: random % 100,
      freeHdd: (random % 100) * 1024 * 1024,
      totalHdd: 256 * 1024 * 1024,
      freeRam: (random % 200) * 1024 * 1024,
      totalRam: 512 * 1024 * 1024,
      interfaces: {"ISP1": true, "ISP2": false},
    );
    _cpuLoad = random % 100;
    _status = 'Active: $userCount users';
    notifyListeners();
  }

  Future<void> connect() async {
    if (_config.host.isEmpty || _isLoading) return;
    _isLoading = true;
    _status = 'Connecting...';
    notifyListeners();

    try {
      _client?.close();
      await Future.delayed(const Duration(milliseconds: 200));
      _client = RouterOSClient(
        host: _config.host,
        port: _config.port,
        user: _config.user,
        password: _config.pass,
      );
      await _client!.connect();
      _isConnected = true;
      _status = 'Connected';
      notifyListeners();

      await _loadSystemInfo();
      _startPolling();
    } catch (e) {
      logger?.addLog(
        'Mikrotik(${_config.host}): ${e.toString()}',
        level: 'ERROR',
      );
      _isConnected = false;
      _status = 'Auth Failed';
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void disconnect() {
    _timer?.cancel();
    _client?.close();
    _client = null;
    _isConnected = false;
    _status = 'Disconnected';
    _activeUsers = [];
    _interfaceStats = [];
    notifyListeners();
  }

  void _startPolling() {
    _timer?.cancel();
    if (!_config.isMonitoring) return;
    _timer = Timer.periodic(
      Duration(seconds: _config.refreshInterval),
      (_) => _fetchUpdates(),
    );
    if (_isConnected) {
      _fetchUpdates();
      _loadUsers();
    }
  }

  Future<void> _loadUsers() async {
    if (!_isConnected || _client == null || _activeUsers.isNotEmpty) return;
    try {
      final hsActive = await _client!.talk(['/ip/hotspot/active/print']);
      final users = <MikrotikUser>[];
      for (var item in hsActive) {
        final u = _mapToUser(item);
        if (u != null) users.add(u);
      }
      _activeUsers = users;
      notifyListeners();
    } catch (e) {
      logger?.addLog(
        'Mikrotik(${_config.host}): ${e.toString()}',
        level: 'ERROR',
      );
    }
  }

  Future<void> _loadSystemInfo() async {
    if (!_isConnected || _client == null) return;
    try {
      final identity = await _client!.talk(['/system/identity/print']);
      final resource = await _client!.talk(['/system/resource/print']);
      final ifaces = await _client!.talk(['/interface/print']);

      final Map<String, bool> interfaces = {};
      for (var item in ifaces) {
        if (item['name'] != null) {
          interfaces[item['name']!] =
              item['running'] == 'true' && item['disabled'] == 'false';
        }
      }

      if (identity.isNotEmpty && resource.isNotEmpty) {
        final id = identity.first;
        final res = resource.first;
        _system = MikrotikSystem(
          name: id['name'] ?? '-',
          uptime: res['uptime'] ?? '-',
          version: res['version'] ?? '-',
          buildTime: res['build-time'] ?? '-',
          factorySoftware: res['factory-software'] ?? '-',
          boardName: res['board-name'] ?? '-',
          architectureName: res['architecture-name'] ?? '-',
          cpu: res['cpu'] ?? '-',
          cpuCount: parseIntSafe(res['cpu-count']),
          cpuLoad: parseIntSafe(res['cpu-load']),
          freeHdd: parseIntSafe(res['free-hdd-space']),
          totalHdd: parseIntSafe(res['total-hdd-space']),
          freeRam: parseIntSafe(res['free-memory']),
          totalRam: parseIntSafe(res['total-memory']),
          interfaces: interfaces,
        );
        notifyListeners();
      }
    } catch (e) {
      logger?.addLog(
        'Mikrotik(${_config.host}): ${e.toString()}',
        level: 'ERROR',
      );
    }
  }

  Future<void> _fetchUpdates() async {
    if (!_isConnected || _client == null || _isFetching) return;
    _isFetching = true;
    try {
      final countResult = await _client!.talk([
        '/ip/hotspot/active/print',
        '=count-only=',
      ]);
      final hsActiveCount = parseCountOnly(countResult.first['ret']);

      final resources = await _client!.execute(
        '/system/resource/print',
        proplist: ['cpu-load', 'free-memory'],
      );
      final cpuLoad = parseIntSafe(resources.first['cpu-load']);
      final freeRAM = parseIntSafe(resources.first['free-memory']);

      List<InterfaceStat> ifStats = [];
      Map<String, bool> interfaces = {};
      if (_system != null) {
        interfaces = _system!.interfaces;
      }

      if (interfaces.isNotEmpty) {
        for (final item in interfaces.entries) {
          final iface = item.key;
          if (!item.value) {
            ifStats.add(
              InterfaceStat(
                name: iface,
                rxRate: '-',
                txRate: '-',
                enabled: false,
              ),
            );
          } else {
            try {
              final tr = await _client!.talk([
                '/interface/monitor-traffic',
                '=interface=$iface',
                '=once=',
              ]);
              if (tr.isNotEmpty) {
                final item = tr.first;
                ifStats.add(
                  InterfaceStat(
                    name: item['name'] ?? iface,
                    rxRate: formatSpeed(
                      parseIntSafe(item['rx-bits-per-second']),
                    ),
                    txRate: formatSpeed(
                      parseIntSafe(item['tx-bits-per-second']),
                    ),
                    enabled: true,
                  ),
                );
              }
            } catch (_) {}
          }
        }
      }

      _activeUsersCount = hsActiveCount;
      _cpuLoad = cpuLoad;
      _interfaceStats = ifStats;
      _status = 'Active: $hsActiveCount users';

      if (_system != null) {
        _system!.cpuLoad = cpuLoad;
        _system!.freeRam = freeRAM;
      }
      notifyListeners();
    } catch (e) {
      _status = 'Disconnected';
      _isConnected = false;
      _client = null;
      notifyListeners();
    }
    _isFetching = false;
  }

  MikrotikUser? _mapToUser(Map<String, String> item) {
    final user = item['user'];
    if (user == null || user.isEmpty) return null;
    final addr = item['address'] ?? '-';
    final id = item['.id'] ?? user;
    final bIn = int.tryParse(item['bytes-in'] ?? '0') ?? 0;
    final bOut = int.tryParse(item['bytes-out'] ?? '0') ?? 0;

    String rx = '0 b', tx = '0 b';
    if (_prevBytesIn.containsKey(id)) {
      rx = formatSpeed(
        parseIntSafe((bIn - _prevBytesIn[id]!) * 8 / _config.refreshInterval),
      );
      tx = formatSpeed(
        parseIntSafe((bOut - _prevBytesOut[id]!) * 8 / _config.refreshInterval),
      );
    }
    _prevBytesIn[id] = bIn;
    _prevBytesOut[id] = bOut;

    return MikrotikUser(
      id: id,
      name: item['user'] ?? 'Unknown',
      address: addr,
      uptime: item['uptime'] ?? '',
      bytesIn: formatBytes(parseIntSafe(bIn.toString())),
      bytesOut: formatBytes(parseIntSafe(bOut.toString())),
      rxRate: rx,
      txRate: tx,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _client?.close();
    super.dispose();
  }
}

class MikrotikProvider extends ChangeNotifier {
  final LogProvider? logger;
  final Map<String, MikrotikInstance> _instances = {};

  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySub;
  bool _hasNetwork = true;

  MikrotikProvider({this.logger}) {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      _hasNetwork =
          results.isNotEmpty && !results.contains(ConnectivityResult.none);
      if (_hasNetwork) {
        for (final instance in _instances.values) {
          if (instance.config.isMonitoring &&
              !instance.isConnected &&
              !instance.isLoading) {
            instance.connect();
          }
        }
      }
    });
  }

  MikrotikInstance getInstance(String key) {
    if (!_instances.containsKey(key)) {
      _instances[key] = MikrotikInstance(key: key, logger: logger)
        ..loadConfig();
    }
    return _instances[key]!;
  }

  void removeInstance(String key) {
    _instances[key]?.dispose();
    _instances.remove(key);
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    for (final instance in _instances.values) {
      instance.dispose();
    }
    super.dispose();
  }
}
