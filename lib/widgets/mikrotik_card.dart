import 'dart:async';
import 'package:flutter/material.dart';
import 'package:netpulse/services/log_service.dart';
import 'package:routeros_api/routeros_api.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'base_card.dart';

class MikrotikCard extends StatefulWidget {
  final String? uniqueKey;
  final String? configKey;
  final VoidCallback? onDelete;
  const MikrotikCard({
    super.key,
    this.uniqueKey,
    this.configKey,
    this.onDelete,
  });

  @override
  State<MikrotikCard> createState() => _MikrotikCardState();
}

class _MikrotikCardState extends State<MikrotikCard> {
  String _host = '';
  String _user = '';
  String _pass = '';
  String _monitoredInterfaces = 'ether1';
  int _refreshInterval = 2;
  int _activeUsersCount = 0;
  int _cpuLoad = 0;
  bool _isMonitoring = false;
  bool _isConnected = false;
  bool _isDemoMode = false;
  bool _isLoading = false;
  String _status = 'Disconnected';
  List<_MikrotikUser> _activeUsers = [];
  List<_InterfaceStat> _interfaceStats = [];
  _MikrotikSystem? _system;
  final LogProvider _log = LogProvider();

  RouterOSClient? _client;
  Timer? _timer;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySub;
  bool _hasNetwork = true;
  bool _isFetching = false;
  bool _usersExpanded = false;
  final Map<String, int> _prevBytesIn = {};
  final Map<String, int> _prevBytesOut = {};

  String get _configKey => widget.configKey ?? widget.uniqueKey ?? 'default';

  @override
  void initState() {
    super.initState();
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      _hasNetwork =
          results.isNotEmpty && !results.contains(ConnectivityResult.none);
      if (_hasNetwork && _isMonitoring && !_isConnected && !_isLoading) {
        connect();
      }
    });
    _checkConnectivityAndLoad();
  }

  Future<void> _checkConnectivityAndLoad() async {
    final result = await _connectivity.checkConnectivity();
    _hasNetwork =
        result.isNotEmpty && !result.contains(ConnectivityResult.none);
    await _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'mk_$_configKey';
    setState(() {
      _host = prefs.getString('${key}_host') ?? '';
      _user = prefs.getString('${key}_user') ?? '';
      _pass = prefs.getString('${key}_pass') ?? '';
      _monitoredInterfaces = prefs.getString('${key}_ifaces') ?? 'ether1';
      _refreshInterval = prefs.getInt('${key}_refresh') ?? 2;
      _isMonitoring = prefs.getBool('${key}_monitor') ?? false;
      _isDemoMode = prefs.getBool('${key}_demo') ?? false;
    });
    if (_isMonitoring && (_host.isNotEmpty || _isDemoMode)) {
      if (_isDemoMode) {
        _startDemoMode();
      } else {
        connect();
      }
    }
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'mk_$_configKey';
    await prefs.setString('${key}_host', _host);
    await prefs.setString('${key}_user', _user);
    await prefs.setString('${key}_pass', _pass);
    await prefs.setString('${key}_ifaces', _monitoredInterfaces);
    await prefs.setInt('${key}_refresh', _refreshInterval);
    await prefs.setBool('${key}_monitor', _isMonitoring);
    await prefs.setBool('${key}_demo', _isDemoMode);
  }

  void _startDemoMode() {
    setState(() {
      _isConnected = true;
      _isDemoMode = true;
      _status = 'Demo Mode';
    });
    _generateDemoData();
    _timer = Timer.periodic(
      Duration(seconds: _refreshInterval),
      (_) => _generateDemoData(),
    );
  }

  void _generateDemoData() {
    final random = DateTime.now().millisecondsSinceEpoch;
    final userCount = 5 + (random % 50);
    final interfaces = _monitoredInterfaces
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final seen = <String>{};
    final ifStats = interfaces.where((name) => seen.add(name)).map((name) {
      final rx = (random % 100000000) + 1000000;
      final tx = (random % 50000000) + 500000;
      return _InterfaceStat(
        name: name,
        rxRate: _formatSpeed(rx.toDouble()),
        txRate: _formatSpeed(tx.toDouble()),
      );
    }).toList();
    final users = List.generate(userCount.clamp(0, 20), (i) {
      final idx = (random + i * 7) % 100;
      return _MikrotikUser(
        id: 'demo_$i',
        name: 'user$i',
        address: '192.168.1.${10 + idx}',
        uptime: '${(random ~/ 3600) % 24}h${(random ~/ 60) % 60}m',
        bytesIn: _formatBytes('${random * 1000}'),
        bytesOut: _formatBytes('${random * 500}'),
        rxRate: _formatSpeed((random % 10000).toDouble()),
        txRate: _formatSpeed((random % 5000).toDouble()),
      );
    });
    setState(() {
      _activeUsersCount = userCount;
      _interfaceStats = ifStats;
      _activeUsers = users;
      _system = _MikrotikSystem(
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
      );
      _cpuLoad = random % 100;
      _status = 'Active: $userCount users';
    });
  }

  void _showLoginDialog() {
    final hostCtrl = TextEditingController(text: _host);
    final userCtrl = TextEditingController(text: _user);
    final passCtrl = TextEditingController(text: _pass);
    final ifaceCtrl = TextEditingController(text: _monitoredInterfaces);
    int currentInterval = _refreshInterval;
    bool demoMode = _isDemoMode;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('MikroTik Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: hostCtrl,
                  enabled: !demoMode,
                  decoration: const InputDecoration(
                    labelText: 'IP Address',
                    hintText: '192.168.0.1',
                  ),
                ),
                TextField(
                  controller: userCtrl,
                  enabled: !demoMode,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                TextField(
                  controller: passCtrl,
                  enabled: !demoMode,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                TextField(
                  controller: ifaceCtrl,
                  enabled: !demoMode,
                  decoration: const InputDecoration(
                    labelText: 'Ports',
                    helperText: 'e.g. ether1,bridge',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Refresh Rate:'),
                    DropdownButton<int>(
                      value: currentInterval,
                      items: [2, 5, 10, 30, 60]
                          .map(
                            (v) =>
                                DropdownMenuItem(value: v, child: Text('$v s')),
                          )
                          .toList(),
                      onChanged: demoMode
                          ? null
                          : (v) {
                              if (v != null) {
                                setState(() => currentInterval = v);
                              }
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Demo Mode:'),
                    Switch(
                      value: demoMode,
                      onChanged: (v) => setState(() => demoMode = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                final wasDemo = _isDemoMode;
                setState(() {
                  _host = hostCtrl.text.trim();
                  _user = userCtrl.text.trim();
                  _pass = passCtrl.text.trim();
                  _monitoredInterfaces = ifaceCtrl.text.trim();
                  _refreshInterval = currentInterval;
                  _isMonitoring = true;
                  _isDemoMode = demoMode;
                  if (!demoMode) {
                    _usersExpanded = false;
                    _activeUsers = [];
                    _interfaceStats = [];
                  }
                });
                _saveConfig();
                Navigator.pop(context);
                if (_isDemoMode) {
                  _startDemoMode();
                } else {
                  if (wasDemo) {
                    _timer?.cancel();
                  }
                  connect();
                }
              },
              child: Text(demoMode ? 'START DEMO' : 'SAVE & CONNECT'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> connect() async {
    if (_host.isEmpty || !_hasNetwork || _isLoading) return;
    setState(() {
      _isLoading = true;
      _status = 'Connecting...';
    });

    try {
      _client?.close();
      await Future.delayed(const Duration(milliseconds: 200));
      _client = RouterOSClient(host: _host, user: _user, password: _pass);
      await _client!.connect();
      setState(() {
        _isConnected = true;
        _status = 'Connected';
      });
      _loadSystemInfo();
      _startPolling();
      _saveConfig();
    } catch (e) {
      _log.addLog('Mikrotik($_host): ${e.toString()}', level: 'ERROR');
      setState(() {
        _isConnected = false;
        _status = 'Auth Failed';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startPolling() {
    _timer?.cancel();
    if (!_isMonitoring) return;
    _timer = Timer.periodic(
      Duration(seconds: _refreshInterval),
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
      final users = <_MikrotikUser>[];
      for (var item in hsActive) {
        final u = _mapToUser(item, 'Hotspot');
        if (u != null) users.add(u);
      }
      if (mounted) setState(() => _activeUsers = users);
    } catch (e) {
      _log.addLog('Mikrotik($_host): ${e.toString()}', level: 'ERROR');
    }
  }

  Future<void> _loadSystemInfo() async {
    if (!_isConnected || _client == null) return;
    try {
      final identity = await _client!.talk(['/system/identity/print']);
      final resource = await _client!.talk(['/system/resource/print']);
      if (identity.isNotEmpty && resource.isNotEmpty) {
        final id = identity.first;
        final res = resource.first;
        setState(() {
          _system = _MikrotikSystem(
            name: id['name'] ?? '-',
            uptime: res['uptime'] ?? '-',
            version: res['version'] ?? '-',
            buildTime: res['build-time'] ?? '-',
            factorySoftware: res['factory-software'] ?? '-',
            boardName: res['board-name'] ?? '-',
            architectureName: res['architecture-name'] ?? '-',
            cpu: res['cpu'] ?? '-',
            cpuCount: int.tryParse(res['cpu-count']?.toString() ?? '0') ?? 0,
            cpuLoad: int.tryParse(res['cpu-load']?.toString() ?? '0') ?? 0,
            freeHdd:
                int.tryParse(res['free-hdd-space']?.toString() ?? '0') ?? 0,
            totalHdd:
                int.tryParse(res['total-hdd-space']?.toString() ?? '0') ?? 0,
            freeRam: int.tryParse(res['free-memory']?.toString() ?? '0') ?? 0,
            totalRam: int.tryParse(res['total-memory']?.toString() ?? '0') ?? 0,
          );
        });
      }
    } catch (e) {
      _log.addLog('Mikrotik($_host): ${e.toString()}', level: 'ERROR');
    }
  }

  Future<void> _fetchUpdates() async {
    if (!_isConnected || _client == null || _isFetching) return;
    _isFetching = true;
    try {
      // Get count only
      final countResult = await _client!.talk([
        '/ip/hotspot/active/print',
        '=count-only=',
      ]);
      final hsActiveCount =
          int.tryParse(countResult.first['ret']?.toString() ?? '0') ?? 0;

      final resources = await _client!.execute(
        '/system/resource/print',
        proplist: ['cpu-load', 'free-memory'],
      );
      final cpuLoad =
          int.tryParse(resources.first['cpu-load']?.toString() ?? '0') ?? 0;
      final freeRAM =
          int.tryParse(resources.first['free-memory']?.toString() ?? '0') ?? 0;

      List<_InterfaceStat> ifStats = [];
      final interfaces = _monitoredInterfaces
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (interfaces.isNotEmpty) {
        try {
          for (final iface in interfaces) {
            try {
              final tr = await _client!.talk([
                '/interface/monitor-traffic',
                '=interface=$iface',
                '=once=',
              ]);
              if (tr.isNotEmpty) {
                final item = tr.first;
                ifStats.add(
                  _InterfaceStat(
                    name: item['name'] ?? iface,
                    rxRate: _formatSpeed(item['rx-bits-per-second']),
                    txRate: _formatSpeed(item['tx-bits-per-second']),
                  ),
                );
              }
            } catch (e) {
              _log.addLog(
                'Mikrotik($_host):interface $iface: ${e.toString()}',
                level: 'ERROR',
              );
            }
          }
        } catch (e) {
          _log.addLog(
            'Mikrotik($_host):interface: ${e.toString()}',
            level: 'ERROR',
          );
        }
      }

      setState(() {
        _activeUsersCount = hsActiveCount;
        _cpuLoad = cpuLoad;
        _interfaceStats = ifStats;
        _status = 'Active: $hsActiveCount users';

        if (_system != null) {
          _system!.cpuLoad = cpuLoad;
          _system!.freeRam = freeRAM;
        }
      });
    } catch (e) {
      _log.addLog(
        'Mikrotik($_host):_fetchUpdates: ${e.toString()}',
        level: 'ERROR',
      );
      setState(() {
        // _isConnected = false;
        _status = 'Disconnected';
      });
      _client = null;
    }
    _isFetching = false;
  }

  _MikrotikUser? _mapToUser(Map<String, String> item, String type) {
    final user = item['user'];
    if (user == null || user.isEmpty) return null;
    final addr = item['address'] ?? '-';
    final id = item['.id'] ?? user;
    final bIn = int.tryParse(item['bytes-in'] ?? '0') ?? 0;
    final bOut = int.tryParse(item['bytes-out'] ?? '0') ?? 0;

    String rx = '0 b', tx = '0 b';
    if (_prevBytesIn.containsKey(id)) {
      rx = _formatSpeed((bIn - _prevBytesIn[id]!) * 8 / _refreshInterval);
      tx = _formatSpeed((bOut - _prevBytesOut[id]!) * 8 / _refreshInterval);
    }
    _prevBytesIn[id] = bIn;
    _prevBytesOut[id] = bOut;

    return _MikrotikUser(
      id: id,
      name: item['user'] ?? 'Unknown',
      address: addr,
      uptime: item['uptime'] ?? '',
      bytesIn: _formatBytes(bIn.toString()),
      bytesOut: _formatBytes(bOut.toString()),
      rxRate: rx,
      txRate: tx,
    );
  }

  String _formatBytes(String s) {
    final b = double.tryParse(s) ?? 0;
    if (b < 1024) return '${b.toStringAsFixed(0)} B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} K';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} M';
    }
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(1)} G';
  }

  String _formatSpeed(dynamic val) {
    final bps = (val is double) ? val : double.tryParse(val.toString()) ?? 0;
    if (bps <= 0) return '0 b';
    if (bps < 1000) return '${bps.toStringAsFixed(0)} b';
    if (bps < 1000000) return '${(bps / 1000).toStringAsFixed(1)} k';
    return '${(bps / 1000000).toStringAsFixed(1)} M';
  }

  Widget _buildDetailGrid() {
    return Wrap(
      spacing: 20,
      runSpacing: 10,
      children: [
        _buildDetailItem('HOST', _host.isNotEmpty ? _host : '-', Icons.lan),
        _buildDetailItem('USER', _user.isNotEmpty ? _user : '-', Icons.person),
        _buildDetailItem('REFRESH', '${_refreshInterval}s', Icons.timer),
        _buildDetailItem('ACTIVE', '$_activeUsersCount', Icons.people),
      ],
    );
  }

  Widget _buildSystemGrid() {
    if (_system == null) return const SizedBox.shrink();
    final sys = _system!;
    return Wrap(
      spacing: 20,
      runSpacing: 10,
      children: [
        _buildDetailItem('NAME', sys.name, Icons.label),
        _buildDetailItem('UPTIME', sys.uptime, Icons.timelapse),
        _buildDetailItem('VERSION', sys.version, Icons.info),
        _buildDetailItem('BUILD', sys.buildTime, Icons.build),
        _buildDetailItem('FACTORY', sys.factorySoftware, Icons.factory),
        _buildDetailItem('BOARD', sys.boardName, Icons.memory),
        _buildDetailItem('ARCH', sys.architectureName, Icons.architecture),
        _buildDetailItem('CPU', sys.cpu, Icons.developer_board),
        _buildDetailItem('CPUs', '${sys.cpuCount}', Icons.numbers),
        _buildDetailItem('LOAD', '${sys.cpuLoad}%', Icons.speed),
        _buildDetailItem(
          'RAM',
          '${_formatBytes(sys.freeRam.toString())}/${_formatBytes(sys.totalRam.toString())}',
          Icons.memory,
        ),
        _buildDetailItem(
          'HDD',
          '${_formatBytes(sys.freeHdd.toString())}/${_formatBytes(sys.totalHdd.toString())}',
          Icons.storage,
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return SizedBox(
      width: 130,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.orangeAccent.withAlpha(150)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 8,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _client?.close();
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userStatusColor = switch (_activeUsersCount) {
      int i when i > 100 => Colors.greenAccent,
      int i when i > 70 => Colors.cyanAccent,
      int i when i > 50 => Colors.yellowAccent,
      int i when i > 20 => Colors.orangeAccent,
      _ => Colors.redAccent,
    };
    final cpuLoadColor = switch (_cpuLoad) {
      int i when i > 90 => Colors.redAccent,
      int i when i > 75 => Colors.orangeAccent,
      int i when i > 50 => Colors.yellowAccent,
      int i when i > 25 => Colors.cyanAccent,
      _ => Colors.greenAccent,
    };

    Widget card = BaseCard(
      title: _isConnected ? (_isDemoMode ? 'Demo Mode' : _host) : 'MikroTik',
      subtitle: _isConnected ? (_isDemoMode ? 'Demo' : 'Connected') : _status,
      subtitleColor: _isConnected ? Colors.greenAccent : Colors.grey,
      leading: Icon(
        Icons.router,
        color: _isConnected ? Colors.orangeAccent : Colors.grey,
        size: 24,
      ),
      trailing: _isConnected
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                /* User active count */
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: userStatusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: userStatusColor.withAlpha(40)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_activeUsersCount',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'users',
                        style: TextStyle(
                          fontSize: 9,
                          color: userStatusColor.withAlpha(150),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                /* CPU Load */
                SizedBox(width: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cpuLoadColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cpuLoadColor.withAlpha(40)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_cpuLoad',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            '%',
                            style: TextStyle(fontSize: 9, color: Colors.grey),
                          ),
                        ],
                      ),
                      Text(
                        'CPU',
                        style: TextStyle(
                          fontSize: 9,
                          color: cpuLoadColor.withAlpha(150),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : null,
      onDoubleTap: _showLoginDialog,
      onTap: () {
        if (!_isConnected && _host.isNotEmpty) connect();
      },
      children: _isConnected
          ? [
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailGrid(),
                    if (_system != null) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'SYSTEM',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildSystemGrid(),
                    ],
                    if (_interfaceStats.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'INTERFACES',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _interfaceStats
                            .map(
                              (s) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(10),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Wrap(
                                  spacing: 8,
                                  children: [
                                    Text(
                                      s.name.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      'R:${s.rxRate}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.greenAccent,
                                      ),
                                    ),
                                    Text(
                                      'T:${s.txRate}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (_activeUsers.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () =>
                            setState(() => _usersExpanded = !_usersExpanded),
                        child: Row(
                          children: [
                            Text(
                              'HOTSPOT USERS (${_activeUsers.length})',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _usersExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 14,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                      if (_usersExpanded) ...[
                        const SizedBox(height: 4),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 16,
                            headingRowHeight: 32,
                            dataRowMinHeight: 32,
                            dataRowMaxHeight: 36,
                            columns: const [
                              DataColumn(
                                label: Text(
                                  'Name',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'IP',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'RX',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'TX',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                            rows: _activeUsers
                                .take(20)
                                .map(
                                  (u) => DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          u.name,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          u.address,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          u.rxRate,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.greenAccent,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          u.txRate,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.blueAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ]
          : null,
    );

    return Dismissible(
      key: ValueKey('mikrotik_$_configKey'),
      direction: widget.onDelete != null
          ? DismissDirection.horizontal
          : (_isConnected
                ? DismissDirection.endToStart
                : DismissDirection.none),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          if (_isConnected) {
            setState(() {
              _isConnected = false;
              _isDemoMode = false;
              _activeUsers = [];
              _interfaceStats = [];
              _status = 'Disconnected';
            });
            _timer?.cancel();
            _client?.close();
            _client = null;
            await _saveConfig();
          } else if (_host.isNotEmpty) {
            connect();
          }
          return false;
        } else {
          widget.onDelete?.call();
          return true;
        }
      },
      background: Container(
        color: Colors.greenAccent.withAlpha(50),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.link_off, color: Colors.greenAccent),
      ),
      secondaryBackground: Container(
        color: Colors.redAccent.withAlpha(50),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.redAccent),
      ),
      child: card,
    );
  }
}

class _MikrotikUser {
  final String id, name, address, uptime, bytesIn, bytesOut, rxRate, txRate;
  _MikrotikUser({
    required this.id,
    required this.name,
    required this.address,
    required this.uptime,
    required this.bytesIn,
    required this.bytesOut,
    required this.rxRate,
    required this.txRate,
  });
}

class _InterfaceStat {
  final String name, rxRate, txRate;
  _InterfaceStat({
    required this.name,
    required this.rxRate,
    required this.txRate,
  });
}

class _MikrotikSystem {
  final String name,
      uptime,
      version,
      buildTime,
      factorySoftware,
      boardName,
      architectureName,
      cpu;
  int cpuLoad, freeRam;
  final int cpuCount, freeHdd, totalHdd, totalRam;
  _MikrotikSystem({
    required this.name,
    required this.uptime,
    required this.version,
    required this.buildTime,
    required this.factorySoftware,
    required this.boardName,
    required this.architectureName,
    required this.cpu,
    required this.cpuCount,
    required this.cpuLoad,
    required this.freeHdd,
    required this.totalHdd,
    required this.freeRam,
    required this.totalRam,
  });
}
