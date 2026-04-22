import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../database/database.dart' show AppDatabase;
import 'package:xml/xml.dart' as xml;
import 'log_service.dart';

class SpeedTestServer {
  final String url;
  final String name;
  final String sponsor;
  int latency;

  SpeedTestServer({
    required this.url,
    required this.name,
    required this.sponsor,
    this.latency = 9999,
  });

  SpeedTestServer copyWith({int? latency}) => SpeedTestServer(
    url: url,
    name: name,
    sponsor: sponsor,
    latency: latency ?? this.latency,
  );

  Map<String, dynamic> toMap() => {
    'url': url,
    'name': name,
    'sponsor': sponsor,
    'latency': latency,
  };
}

class SpeedTestProvider extends ChangeNotifier {
  final LogProvider? logger;
  bool _isDisposed = false;

  bool _isTesting = false;
  bool _isRefreshing = false;
  double _downloadSpeed = 0;
  double _uploadSpeed = 0;
  int _latency = 0;
  int _jitter = 0;
  String _status = 'Ready';

  String _serverName = 'Select Server';
  String _serverSponsor = '-';
  String _baseUrl = '';

  List<SpeedTestServer> _availableServers = [];
  SpeedTestServer? _selectedServer;

  String _clientIsp = '-';
  String _clientIp = '-';

  final List<String> _discoveryUrls = [
    'https://www.speedtest.net/api/js/servers?limit=25',
    'https://www.speedtest.net/speedtest-servers-static.php',
  ];

  bool get isTesting => _isTesting;
  bool get isRefreshing => _isRefreshing;
  double get downloadSpeed => _downloadSpeed;
  double get uploadSpeed => _uploadSpeed;
  int get latency => _latency;
  int get jitter => _jitter;
  String get status => _status;
  String get serverName => _serverName;
  String get serverSponsor => _serverSponsor;
  String get clientIsp => _clientIsp;
  String get clientIp => _clientIp;
  String get baseUrl => _baseUrl;
  List<SpeedTestServer> get availableServers => _availableServers;
  SpeedTestServer? get selectedServer => _selectedServer;

  SpeedTestProvider({this.logger}) {
    _init();
  }

  void _log(String msg, {String level = 'INFO'}) {
    if (_isDisposed) return;
    logger?.addLog('SpeedTest: $msg', level: level);
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) super.notifyListeners();
  }

  Future<void> _init() async {
    await _loadConfig();
    fetchClientInfo();
    if (_availableServers.isEmpty) {
      findBestServer();
    }
  }

  Future<void> _loadConfig() async {
    final server = await AppDatabase.getSpeedtestSetting<Map<String, dynamic>>(
      'server',
    );
    if (server != null) {
      _baseUrl = server['url'] ?? 'http://sgp.speedtest.clouvider.net';
      _serverName = server['name'] ?? 'Select Server';
      _serverSponsor = server['sponsor'] ?? '-';
    } else {
      _baseUrl = 'http://sgp.speedtest.clouvider.net';
      _serverName = 'Select Server';
      _serverSponsor = '-';
    }

    final cachedServers = await AppDatabase.getSpeedtestSetting<List<dynamic>>(
      'server_caches',
    );
    if (cachedServers != null) {
      try {
        _availableServers = cachedServers
            .map(
              (s) => SpeedTestServer(
                url: s['url'] ?? '',
                name: s['name'] ?? '',
                sponsor: s['sponsor'] ?? '',
                latency: s['latency'] ?? 9999,
              ),
            )
            .toList();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _saveServers() async {
    final list = _availableServers.map((s) => s.toMap()).toList();
    await AppDatabase.setSpeedtestSetting('server_caches', list);
  }

  Future<void> fetchClientInfo() async {
    try {
      final res = await http
          .get(Uri.parse('http://ip-api.com/json'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _clientIp = data['query'] ?? '';
        _clientIsp = data['isp'] ?? 'Unknown ISP';
        _log('Client detected: $_clientIsp ($_clientIp)');
        notifyListeners();
        return;
      }
    } catch (e) {
      _log('Client fetch error: $e', level: 'ERROR');
    }
    _clientIsp = 'Not Detected';
    notifyListeners();
  }

  void selectServer(SpeedTestServer? server) async {
    _selectedServer = server;
    if (server != null) {
      _baseUrl = server.url;
      _serverName = server.name;
      _serverSponsor = server.sponsor;
      _log('Manual server selection: $_serverName');
    } else {
      _log('Server selection set to Auto');
    }
    await AppDatabase.setSpeedtestSetting('server', {
      'url': _baseUrl,
      'name': _serverName,
      'sponsor': _serverSponsor,
    });
    notifyListeners();
  }

  Future<void> findBestServer() async {
    _isRefreshing = true;
    notifyListeners();

    List<SpeedTestServer> discovered = [];
    for (var discoveryUrl in _discoveryUrls) {
      try {
        final res = await http
            .get(
              Uri.parse(discoveryUrl),
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (X11; Linux x86_64; rv:149.0) Gecko/20100101 Firefox/149.0',
              },
            )
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          if (discoveryUrl.contains('js/servers')) {
            final List<dynamic> data = jsonDecode(res.body);
            for (var s in data) {
              discovered.add(
                SpeedTestServer(
                  url: s['url'] ?? '',
                  name: s['name'] ?? '',
                  sponsor: s['sponsor'] ?? '',
                ),
              );
            }
          } else {
            final document = xml.XmlDocument.parse(res.body);
            for (var node in document.findAllElements('server')) {
              discovered.add(
                SpeedTestServer(
                  url: node.getAttribute('url') ?? '',
                  name: node.getAttribute('name') ?? '',
                  sponsor: node.getAttribute('sponsor') ?? '',
                ),
              );
            }
          }
          if (discovered.isNotEmpty) break;
        } else {
          _log(
            'Server fetch failed: HTTP ${res.statusCode} from $discoveryUrl',
            level: 'WARN',
          );
        }
      } catch (e) {
        _log('Server fetch error: $e', level: 'ERROR');
      }
    }

    _isRefreshing = false;
    if (discovered.isNotEmpty) {
      final existingUrls = _availableServers.map((s) => s.url).toSet();
      for (var s in discovered) {
        if (!existingUrls.contains(s.url)) {
          _availableServers.add(s);
        }
      }
      await _saveServers();
      if (_selectedServer == null) {
        await _autoPickBest(discovered);
      }
    } else {
      _log('No servers discovered (using cache only)', level: 'WARN');
    }
    _isRefreshing = false;
    notifyListeners();
  }

  Future<void> _autoPickBest(List<SpeedTestServer> servers) async {
    String? bestUrl;
    String? bestName;
    String? bestSponsor;
    int lowestPing = 9999;

    final serversWithCache = servers.where((s) => s.latency < 9999).toList();
    if (serversWithCache.isNotEmpty) {
      serversWithCache.sort((a, b) => a.latency.compareTo(b.latency));
      final best = serversWithCache.first;
      bestUrl = best.url.split('/speedtest/')[0];
      if (bestUrl.startsWith('https')) {
        bestUrl = bestUrl.replaceFirst('https', 'http');
      }
      bestName = best.name;
      bestSponsor = best.sponsor;
      lowestPing = best.latency;
      _log('Using cached server: $_serverName (${lowestPing}ms)');
    }

    final serversToPing = servers
        .where((s) => s.latency >= 9999)
        .take(12 - serversWithCache.length)
        .toList();
    if (serversToPing.isNotEmpty) {
      final List<Future> tasks = [];
      for (var s in serversToPing) {
        tasks.add(() async {
          String url = s.url.split('/speedtest/')[0];
          if (url.startsWith('https')) url = url.replaceFirst('https', 'http');
          int p = await _quickPing(url);
          s.latency = p;
          if (p < lowestPing) {
            lowestPing = p;
            bestUrl = url;
            bestName = s.name;
            bestSponsor = s.sponsor;
          }
        }());
      }
      await Future.wait(
        tasks,
      ).timeout(const Duration(seconds: 4), onTimeout: () => []);
      await _saveServers();
    }

    if (bestUrl != null) {
      _baseUrl = bestUrl!;
      _serverName = bestName!;
      _serverSponsor = bestSponsor!;
      _log('Auto-selected optimal server: $_serverName');
      await AppDatabase.setSpeedtestSetting('server', {
        'url': _baseUrl,
        'name': _serverName,
        'sponsor': _serverSponsor,
      });
    }
  }

  Future<int> _quickPing(String baseUrl) async {
    try {
      final sw = Stopwatch()..start();
      final res = await http
          .get(Uri.parse('$baseUrl/speedtest/latency.txt'))
          .timeout(const Duration(milliseconds: 1200));
      return res.statusCode == 200 ? sw.elapsedMilliseconds : 9999;
    } catch (_) {
      return 9999;
    }
  }

  Future<void> startTest({Function()? onFinish}) async {
    if (_isTesting) return;
    _isTesting = true;
    _downloadSpeed = 0;
    _uploadSpeed = 0;
    _latency = 0;
    _jitter = 0;
    notifyListeners();

    try {
      _status = 'Latency...';
      notifyListeners();
      await _runLatencyTest();
      await _runParallelDownload();
      await _runParallelUpload();
      _status = 'Complete';
      if (onFinish != null) onFinish();
    } catch (e) {
      _status = 'Error: $e';
    } finally {
      _isTesting = false;
      notifyListeners();
    }
  }

  void stopTest() {
    _isTesting = false;
    _status = 'Stopped';
    notifyListeners();
  }

  bool get isActive => _isTesting;

  Future<void> _runLatencyTest() async {
    if (!_isTesting) return;
    final pings = <int>[];
    String base = _baseUrl.split('/speedtest/')[0];
    for (var i = 0; i < 5; i++) {
      if (!_isTesting) return;
      int p = await _quickPing(base);
      if (p < 9999) pings.add(p);
    }
    if (pings.isNotEmpty) {
      _latency = (pings.reduce((a, b) => a + b) / pings.length).round();
      if (pings.length > 1) {
        int variation = 0;
        for (var i = 0; i < pings.length - 1; i++) {
          variation += (pings[i] - pings[i + 1]).abs();
        }
        _jitter = (variation / (pings.length - 1)).round();
      }
    }
  }

  Future<void> _runParallelDownload() async {
    if (!_isTesting) return;
    _status = 'Download...';
    notifyListeners();
    String base = _baseUrl.split('/speedtest/')[0];
    String dlPath = '$base/speedtest/random4000x4000.jpg';
    const numThreads = 4;
    int totalBytes = 0;
    double smoothedSpeed = 0;
    final sw = Stopwatch()..start();
    bool keepRunning = true;
    final List<Future> workers = [];
    for (int i = 0; i < numThreads; i++) {
      workers.add(() async {
        final client = http.Client();
        try {
          if (!_isTesting) return;
          final res = await client
              .send(http.Request('GET', Uri.parse(dlPath)))
              .timeout(const Duration(seconds: 15));
          if (res.statusCode != 200) return;
          await for (var chunk in res.stream) {
            if (!keepRunning || _isDisposed || !_isTesting) break;
            totalBytes += chunk.length;
            final elapsed = sw.elapsedMilliseconds / 1000.0;
            if (elapsed > 0.4) {
              double currentInstant =
                  (totalBytes * 8) / (1024 * 1024) / elapsed;
              smoothedSpeed = (0.25 * currentInstant) + (0.75 * smoothedSpeed);
              _downloadSpeed = smoothedSpeed;
              notifyListeners();
            }
          }
        } catch (_) {
        } finally {
          client.close();
        }
      }());
    }
    await Future.wait(workers).timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        keepRunning = false;
        return [];
      },
    );
  }

  Future<void> _runParallelUpload() async {
    if (!_isTesting) return;
    _status = 'Upload...';
    notifyListeners();
    String base = _baseUrl.split('/speedtest/')[0];
    String ulPath = '$base/speedtest/upload.php';
    int totalUploaded = 0;
    double smoothedSpeed = 0;
    final sw = Stopwatch()..start();
    bool keepRunning = true;
    final random = math.Random();
    final data = Uint8List.fromList(
      List.generate(512 * 1024, (i) => random.nextInt(256)),
    );
    final List<Future> workers = [];
    for (int i = 0; i < 2; i++) {
      workers.add(() async {
        while (keepRunning && !_isDisposed && _isTesting) {
          try {
            final res = await http
                .post(Uri.parse(ulPath), body: data)
                .timeout(const Duration(seconds: 5));
            if (res.statusCode == 200) {
              totalUploaded += data.length;
              final elapsed = sw.elapsedMilliseconds / 1000.0;
              if (elapsed > 0.4) {
                double currentInstant =
                    (totalUploaded * 8) / (1024 * 1024) / elapsed;
                smoothedSpeed =
                    (0.25 * currentInstant) + (0.75 * smoothedSpeed);
                _uploadSpeed = smoothedSpeed;
                notifyListeners();
              }
            }
          } catch (_) {}
        }
      }());
    }
    await Future.delayed(const Duration(seconds: 8));
    keepRunning = false;
    await Future.wait(workers);
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
