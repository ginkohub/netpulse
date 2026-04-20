import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:router_os_client/router_os_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'log_service.dart';

class MikrotikUser {
  final String id;
  final String name;
  final String address;
  final String uptime;
  final String bytesIn;
  final String bytesOut;
  String rxRate;
  String txRate;
  final int rawBytesIn;
  final int rawBytesOut;
  final int rawUptime;

  MikrotikUser({
    required this.id,
    required this.name,
    required this.address,
    required this.uptime,
    required this.bytesIn,
    required this.bytesOut,
    required this.rxRate,
    required this.txRate,
    required this.rawBytesIn,
    required this.rawBytesOut,
    required this.rawUptime,
  });
}

class InterfaceStat {
  final String name;
  final String rxRate;
  final String txRate;
  InterfaceStat({
    required this.name,
    required this.rxRate,
    required this.txRate,
  });
}

class MikrotikProvider extends ChangeNotifier {
  final LogProvider? logger;
  bool _isDisposed = false;

  String _host = '';
  String _user = '';
  String _pass = '';
  String _monitoredInterfaces = 'ether1';

  bool _isConnected = false;
  bool _isLoading = false;
  bool _isMonitoring = false;
  int _refreshInterval = 2;
  List<MikrotikUser> _activeUsers = [];
  List<InterfaceStat> _interfaceStats = [];
  String _status = 'Disconnected';
  Timer? _timer;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySub;
  bool _hasNetwork = true;
  
  RouterOSClient? _activeClient;

  final Map<String, int> _prevBytesIn = {};
  final Map<String, int> _prevBytesOut = {};

  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  MikrotikProvider({this.logger}) {
    _loadConfig();
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      _checkConnectivity(results);
    });
  }

  Future<void> _checkConnectivity(List<ConnectivityResult> results) async {
    _hasNetwork = results.isNotEmpty && !results.contains(ConnectivityResult.none);
    if (!_hasNetwork && _isConnected) {
      _isConnected = false;
      _status = 'No Network Connection';
      _activeUsers.clear();
      _interfaceStats.clear();
      await _closeCurrentClient();
      notifyListeners();
    } else if (_hasNetwork && _isMonitoring && !_isConnected) {
      connect();
    }
  }

  void _log(String msg, {String level = 'INFO'}) {
    if (_isDisposed) return;
    logger?.addLog('MikroTik: $msg', level: level);
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) super.notifyListeners();
  }

  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  bool get isMonitoring => _isMonitoring;
  int get refreshInterval => _refreshInterval;
  int get sortColumnIndex => _sortColumnIndex;
  bool get sortAscending => _sortAscending;
  String get status => _status;
  String get host => _host;
  String get user => _user;
  String get pass => _pass;
  String get monitoredInterfaces => _monitoredInterfaces;
  List<InterfaceStat> get interfaceStats => _interfaceStats;

  List<MikrotikUser> get activeUsers {
    List<MikrotikUser> sortedList = List.from(_activeUsers);
    sortedList.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0: cmp = a.name.compareTo(b.name); break;
        case 1: cmp = a.address.compareTo(b.address); break;
        case 2: cmp = a.rxRate.compareTo(b.rxRate); break;
        case 3: cmp = a.txRate.compareTo(b.txRate); break;
        case 4: cmp = a.rawBytesIn.compareTo(b.rawBytesIn); break;
        case 5: cmp = a.rawBytesOut.compareTo(b.rawBytesOut); break;
        case 6: cmp = a.rawUptime.compareTo(b.rawUptime); break;
        default: cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return sortedList;
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _host = prefs.getString('mk_host') ?? '';
    _user = prefs.getString('mk_user') ?? '';
    _pass = prefs.getString('mk_pass') ?? '';
    _monitoredInterfaces = prefs.getString('mk_ifaces') ?? 'ether1';
    _refreshInterval = prefs.getInt('mk_refresh') ?? 2;
    _isMonitoring = prefs.getBool('mk_monitor') ?? false;
    if (_host.isNotEmpty && _user.isNotEmpty && _isMonitoring) {
      connect();
    }
  }

  void updateSort(int index, bool ascending) {
    _sortColumnIndex = index;
    _sortAscending = ascending;
    notifyListeners();
  }

  Future<void> setRefreshInterval(int seconds) async {
    _refreshInterval = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('mk_refresh', seconds);
    _log('Refresh rate set to $seconds s');
    if (_isMonitoring) _startPolling();
    notifyListeners();
  }

  Future<void> setInterfaces(String ifaces) async {
    _monitoredInterfaces = ifaces;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mk_ifaces', ifaces);
    _log('Monitoring ports: $ifaces');
    notifyListeners();
  }

  Future<void> setConfig(String host, String user, String pass) async {
    _host = host;
    _user = user;
    _pass = pass;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mk_host', host);
    await prefs.setString('mk_user', user);
    await prefs.setString('mk_pass', pass);
    _log('New credentials saved for $host');
    connect();
  }

  Future<void> _closeCurrentClient() async {
    try {
      _activeClient?.close();
      _activeClient = null;
    } catch (_) {}
  }

  Future<void> connect() async {
    if (_host.isEmpty || !_hasNetwork) return;
    _isLoading = true;
    _status = 'Connecting...';
    notifyListeners();
    
    try {
      await _closeCurrentClient();
      
      final client = RouterOSClient(
        address: _host,
        user: _user,
        password: _pass,
      );
      
      if (await client.login().timeout(const Duration(seconds: 10))) {
        if (!_isConnected) _log('Connected to $_host');
        _isConnected = true;
        _status = 'Connected';
        _activeClient = client;
        _isMonitoring = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('mk_monitor', true);
        _startPolling();
      } else {
        _isConnected = false;
        _status = 'Login Failed';
        _log('Login failed: Invalid credentials', level: 'ERROR');
        client.close();
      }
    } catch (e) {
      _isConnected = false;
      _status = 'Error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleMonitoring() async {
    _isMonitoring = !_isMonitoring;
    _log('Monitoring turned ${_isMonitoring ? "ON" : "OFF"}');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mk_monitor', _isMonitoring);
    if (_isMonitoring) {
      if (!_isConnected || _activeClient == null) {
        connect();
      } else {
        _startPolling();
      }
    } else {
      _timer?.cancel();
    }
    notifyListeners();
  }

  void _startPolling() {
    _timer?.cancel();
    if (!_isMonitoring || !_isConnected) return;
    _timer = Timer.periodic(Duration(seconds: _refreshInterval), (timer) {
      if (_isMonitoring && _isConnected && _activeClient != null) {
        fetchUpdates();
      } else {
        timer.cancel();
      }
    });
    fetchUpdates();
  }

  Future<void> fetchUpdates() async {
    if (!_isConnected || _host.isEmpty || !_isMonitoring || !_hasNetwork) return;
    
    if (_activeClient == null) {
      await connect();
      return;
    }

    try {
      final List<Future<List<Map<String, String>>>> tasks = [
        _activeClient!.talk(['/ip/hotspot/active/print', '=detail=', '=without-paging=']),
        _activeClient!.talk(['/ip/hotspot/host/print', '?bypassed=yes', '=detail=', '=without-paging=']),
        _activeClient!.talk(['/ppp/active/print', '=detail=', '=without-paging=']),
      ];

      final results = await Future.wait(tasks);
      final hsActiveRaw = results[0];
      final hsHostRaw = results[1];
      final pppActiveRaw = results[2];

      final Map<String, MikrotikUser> nextMap = {};

      for (var item in hsActiveRaw) {
        final user = _mapToUser(item, 'Hotspot');
        nextMap[item['.id'] ?? user.id] = user;
      }

      for (var item in hsHostRaw) {
        String mac = item['mac-address'] ?? '';
        String id = item['.id'] ?? mac;
        if (id.isNotEmpty && !nextMap.containsKey(id)) {
          nextMap[id] = _mapToUser(item, 'Bypass');
        }
      }

      for (var item in pppActiveRaw) {
        final user = _mapToUser(item, 'PPP');
        nextMap[item['.id'] ?? user.address] = user;
      }

      List<InterfaceStat> nextIfStats = [];
      if (_monitoredInterfaces.isNotEmpty) {
        try {
          final tr = await _activeClient!.talk([
            '/interface/monitor-traffic',
            '=interface=$_monitoredInterfaces',
            '=once=',
          ]);
          for (var item in tr) {
            nextIfStats.add(InterfaceStat(
              name: item['name'] ?? '?',
              rxRate: _formatSpeed(item['rx-bits-per-second'] ?? '0'),
              txRate: _formatSpeed(item['tx-bits-per-second'] ?? '0'),
            ));
          }
        } catch (_) {}
      }

      _activeUsers = nextMap.values.toList();
      _interfaceStats = nextIfStats;
      _status = 'Active: H:${hsActiveRaw.length} P:${pppActiveRaw.length} B:${hsHostRaw.length} (Total: ${_activeUsers.length})';
    } catch (e) {
      _log('Session error, reconnecting...', level: 'WARN');
      _isConnected = false;
      _status = 'Reconnecting...';
      _activeUsers.clear();
      _interfaceStats.clear();
      notifyListeners();
      await connect();
    }
    notifyListeners();
  }

  MikrotikUser _mapToUser(Map<String, String> item, String type) {
    String address = item['address'] ?? item['active-address'] ?? '-';
    String id = item['.id'] ?? item['user'] ?? address;
    
    int bIn = int.tryParse(item['bytes-in'] ?? '0') ?? 0;
    int bOut = int.tryParse(item['bytes-out'] ?? '0') ?? 0;
    
    String calculatedRx = '0 b';
    String calculatedTx = '0 b';
    
    if (_prevBytesIn.containsKey(id)) {
      int deltaIn = bIn - _prevBytesIn[id]!;
      int deltaOut = bOut - _prevBytesOut[id]!;
      calculatedRx = _formatSpeed((deltaIn * 8) / _refreshInterval);
      calculatedTx = _formatSpeed((deltaOut * 8) / _refreshInterval);
    }
    
    _prevBytesIn[id] = bIn;
    _prevBytesOut[id] = bOut;

    String displayName = item['user'] ?? item['host-name'] ?? item['comment'] ?? item['mac-address'] ?? 'Unknown';

    return MikrotikUser(
      id: id,
      name: displayName,
      address: address,
      uptime: item['uptime'] ?? '',
      bytesIn: _formatBytes(item['bytes-in'] ?? '0'),
      bytesOut: _formatBytes(item['bytes-out'] ?? '0'),
      rxRate: calculatedRx,
      txRate: calculatedTx,
      rawBytesIn: bIn,
      rawBytesOut: bOut,
      rawUptime: _parseUptime(item['uptime'] ?? '0s'),
    );
  }

  int _parseUptime(String uptime) {
    try {
      int totalSeconds = 0;
      if (uptime.contains('d')) {
        var parts = uptime.split('d');
        totalSeconds += int.parse(parts[0]) * 86400;
        uptime = parts[1];
      }
      var hms = uptime.split(':');
      if (hms.length == 3) {
        totalSeconds += int.parse(hms[0]) * 3600;
        totalSeconds += int.parse(hms[1]) * 60;
        totalSeconds += int.parse(hms[2]);
      }
      return totalSeconds;
    } catch (_) { return 0; }
  }

  String _formatBytes(String bytesStr) {
    double b = double.tryParse(bytesStr) ?? 0;
    if (b < 1024) return '${b.toStringAsFixed(0)} B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} K';
    if (b < 1024 * 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} M';
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(1)} G';
  }

  String _formatSpeed(dynamic val) {
    double bps = 0;
    if (val is double) {
      bps = val;
    } else {
      String s = val.toString().toLowerCase();
      if (s.contains('k') || s.contains('m') || s.contains('g')) return s.replaceAll('bps', '').trim();
      bps = double.tryParse(s.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    }
    if (bps <= 0) return '0 b';
    if (bps < 1000) return '${bps.toStringAsFixed(0)} b';
    if (bps < 1000000) return '${(bps / 1000).toStringAsFixed(1)} k';
    return '${(bps / 1000000).toStringAsFixed(1)} M';
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _connectivitySub?.cancel();
    _closeCurrentClient();
    super.dispose();
  }
}
