import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../database/database.dart';

class TestHistoryItem {
  final String? id;
  final DateTime timestamp;
  final double download;
  final double upload;
  final int latency;
  final int jitter;
  final String server;
  final String sponsor;
  final String isp;
  final double? lat;
  final double? lon;

  TestHistoryItem({
    this.id,
    required this.timestamp,
    required this.download,
    required this.upload,
    required this.latency,
    required this.jitter,
    required this.server,
    required this.sponsor,
    required this.isp,
    this.lat,
    this.lon,
  });
}

class HistoryProvider extends ChangeNotifier {
  List<TestHistoryItem> _items = [];
  static const int _maxItems = 100;

  List<TestHistoryItem> get items => _items;

  HistoryProvider() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final rows = await AppDatabase.getHistory(limit: _maxItems);
    _items = rows
        .map(
          (row) => TestHistoryItem(
            id: row['id'] as String?,
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              row['timestamp'] as int,
            ),
            download: row['download'] as double,
            upload: row['upload'] as double,
            latency: row['latency'] as int,
            jitter: row['jitter'] as int,
            server: row['server'] as String,
            sponsor: row['sponsor'] as String,
            isp: row['isp'] as String,
            lat: row['lat'] as double?,
            lon: row['lon'] as double?,
          ),
        )
        .toList();
    notifyListeners();
  }

  Future<void> addResult({
    required double download,
    required double upload,
    required int latency,
    required int jitter,
    required String server,
    required String sponsor,
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

    final now = DateTime.now();
    final id = await AppDatabase.addHistory({
      'timestamp': now.millisecondsSinceEpoch,
      'download': download,
      'upload': upload,
      'latency': latency,
      'jitter': jitter,
      'server': server,
      'sponsor': sponsor,
      'isp': isp,
      'lat': lat,
      'lon': lon,
    });

    _items.insert(
      0,
      TestHistoryItem(
        id: id,
        timestamp: now,
        download: download,
        upload: upload,
        latency: latency,
        jitter: jitter,
        server: server,
        sponsor: sponsor,
        isp: isp,
        lat: lat,
        lon: lon,
      ),
    );

    if (_items.length > _maxItems) _items.removeLast();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await AppDatabase.clearHistory();
    _items = [];
    notifyListeners();
  }
}
