import 'dart:async';
import 'package:flutter/material.dart';
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

class MikrotikProvider extends ChangeNotifier with WidgetsBindingObserver {
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
  bool _isFetching = false;
  
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
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _log('App resumed, waking up connection...');
      _isFetching = false;
      if (_isMonitoring) connect();
    }
  }

  Future<void> _checkConnectivity(List<ConnectivityResult> results) async {
    _hasNetwork = results.isNotEmpty && !results.contains(ConnectivityResult.none);
    if (!_hasNetwork) {
      if (_isConnected) {
        _isConnected = false;
        _status = 'No Network';
        _activeUsers.clear();
        _interfaceStats.clear();
        await _closeCurrentClient();
        notifyListeners();
      }
    } else if (_isMonitoring && !_isConnected && !_isLoading) {
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

  Future<void> reloadConfig() async {
    _log('Reloading configuration...');
    await _closeCurrentClient();
    _isConnected = false;
    await _loadConfig();
    notifyListeners();
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
      if (_activeClient != null) {
        _activeClient!.close();
      }
    } catch (_) {}
    _activeClient = null;
  }

  Future<void> connect() async {
    if (_host.isEmpty || !_hasNetwork || _isLoading) return;
    _isLoading = true;
    _status = 'Connecting...';
    notifyListeners();
    
    try {
      await _closeCurrentClient();
      await Future.delayed(const Duration(milliseconds: 200)); 

      final client = RouterOSClient(address: _host, user: _user, password: _pass);
      if (await client.login().timeout(const Duration(seconds: 7))) {
        _log('Connected successfully');
        _isConnected = true;
        _status = 'Connected';
        _activeClient = client;
        _isMonitoring = true;
        _startPolling();
      } else {
        _isConnected = false;
        _status = 'Auth Failed';
        client.close();
      }
    } catch (e) {
      _isConnected = false;
      _status = 'Offline';
      _log('Connection failed: $e', level: 'WARN');
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
      _startPolling();
    } else {
      _timer?.cancel();
    }
    notifyListeners();
  }

  void _startPolling() {
    _timer?.cancel();
    if (!_isMonitoring) return;
    
    _timer = Timer.periodic(Duration(seconds: _refreshInterval), (timer) {
      if (!_isMonitoring) {
        timer.cancel();
        return;
      }
      if (_isConnected && _activeClient != null) {
        fetchUpdates();
      } else if (_hasNetwork && !_isLoading) {
        connect();
      }
    });
    
    if (_isConnected) {
      fetchUpdates();
    } else if (_hasNetwork) {
      connect();
    }
  }

  Future<void> fetchUpdates() async {
    if (!_isConnected || _host.isEmpty || !_isMonitoring || !_hasNetwork || _isFetching || _activeClient == null) return;
    
    _isFetching = true;
    try {
      // Fetch data one by one to avoid collision in simple persistent session
      List<Map<String, String>> hsActiveRaw = [];
      try {
        hsActiveRaw = await _activeClient!.talk(['/ip/hotspot/active/print', '=detail=']);
      } catch (e) { throw Exception('HS Fetch: $e'); }

      List<Map<String, String>> hsHostRaw = [];
      try {
        hsHostRaw = await _activeClient!.talk(['/ip/hotspot/host/print', '?bypassed=yes', '=detail=']);
      } catch (_) {}

      List<Map<String, String>> pppActiveRaw = [];
      try {
        pppActiveRaw = await _activeClient!.talk(['/ppp/active/print', '=detail=']);
      } catch (_) {}

      final Map<String, MikrotikUser> nextMap = {};

      for (var item in hsActiveRaw) {
        final user = _mapToUser(item, 'Hotspot');
        nextMap[item['.id'] ?? user.id] = user;
      }
      for (var item in hsHostRaw) {
        final user = _mapToUser(item, 'Bypass');
        String key = item['.id'] ?? item['mac-address'] ?? '';
        if (key.isNotEmpty && !nextMap.containsKey(key)) nextMap[key] = user;
      }
      for (var item in pppActiveRaw) {
        final user = _mapToUser(item, 'PPP');
        nextMap[item['.id'] ?? user.address] = user;
      }

      List<InterfaceStat> nextIfStats = [];
      if (_monitoredInterfaces.isNotEmpty) {
        try {
          final tr = await _activeClient!.talk(['/interface/monitor-traffic', '=interface=$_monitoredInterfaces', '=once=']);
          for (var item in tr) {
            nextIfStats.add(InterfaceStat(
              name: item['name'] ?? '?',
              rxRate: _formatSpeed(item['rx-bits-per-second'] ?? '0'),
              txRate: _formatSpeed(item['tx-bits-per-second'] ?? '0'),
            ));
          }
        } catch (_) {}
      }

      if (nextMap.isEmpty && (hsActiveRaw.isNotEmpty || pppActiveRaw.isNotEmpty)) {
        _log('Warning: Possible partial read, skipping update', level: 'WARN');
      } else {
        _activeUsers = nextMap.values.toList();
        _interfaceStats = nextIfStats;
        _status = 'Active: H:${hsActiveRaw.length} P:${pppActiveRaw.length} B:${hsHostRaw.length}';
        _log('Counts - HS:${hsActiveRaw.length} B:${hsHostRaw.length} P:${pppActiveRaw.length} | Merged:${_activeUsers.length}');
      }
    } catch (e) {
      _log('Session Lost: $e', level: 'WARN');
      _isConnected = false;
      _status = 'Disconnected';
      await _closeCurrentClient();
    } finally {
      _isFetching = false;
      notifyListeners();
    }
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
      bytesIn: _formatBytes(bIn.toString()),
      bytesOut: _formatBytes(bOut.toString()),
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
        uptime = parts[parts.length-1];
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
