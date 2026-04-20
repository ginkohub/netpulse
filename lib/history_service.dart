import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

class TestHistoryItem {
  final DateTime timestamp;
  final double download;
  final double upload;
  final int latency;
  final int jitter;
  final String server;
  final String isp;
  final double? lat;
  final double? lon;

  TestHistoryItem({
    required this.timestamp,
    required this.download,
    required this.upload,
    required this.latency,
    required this.jitter,
    required this.server,
    required this.isp,
    this.lat,
    this.lon,
  });

  Map<String, dynamic> toJson() => {
    't': timestamp.millisecondsSinceEpoch,
    'dl': download,
    'ul': upload,
    'lt': latency,
    'jt': jitter,
    'srv': server,
    'isp': isp,
    'lat': lat,
    'lon': lon,
  };

  factory TestHistoryItem.fromJson(Map<String, dynamic> json) => TestHistoryItem(
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['t']),
    download: json['dl'],
    upload: json['ul'],
    latency: json['lt'],
    jitter: json['jt'],
    server: json['srv'],
    isp: json['isp'],
    lat: json['lat'],
    lon: json['lon'],
  );
}

class HistoryProvider extends ChangeNotifier {
  List<TestHistoryItem> _items = [];
  static const String _storageKey = 'test_history';

  List<TestHistoryItem> get items => _items;

  HistoryProvider() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? data = prefs.getStringList(_storageKey);
    if (data != null) {
      _items = data.map((e) => TestHistoryItem.fromJson(jsonDecode(e))).toList();
      _items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifyListeners();
    }
  }

  Future<void> addResult({
    required double download,
    required double upload,
    required int latency,
    required int jitter,
    required String server,
    required String isp,
  }) async {
    double? lat, lon;

    try {
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 3),
        ),
      );
      lat = pos.latitude;
      lon = pos.longitude;
    } catch (_) {
      debugPrint('Location fetching failed for history geotag');
    }

    final newItem = TestHistoryItem(
      timestamp: DateTime.now(),
      download: download,
      upload: upload,
      latency: latency,
      jitter: jitter,
      server: server,
      isp: isp,
      lat: lat,
      lon: lon,
    );

    _items.insert(0, newItem);
    if (_items.length > 100) _items.removeLast();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, _items.map((e) => jsonEncode(e.toJson())).toList());
    notifyListeners();
  }

  void clearHistory() async {
    _items = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    notifyListeners();
  }
}
