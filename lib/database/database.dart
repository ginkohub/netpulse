import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AppDatabase {
  static String? _dir;
  static final Map<String, Map<String, dynamic>> _cache = {};

  static Future<String> get dbDir async {
    _dir ??= (await getApplicationSupportDirectory()).path;
    return _dir!;
  }

  static Future<File> file(String name) async {
    final d = await dbDir;
    return File('$d/$name.json');
  }

  static Future<Map<String, dynamic>> loadJson(String name) async {
    if (_cache.containsKey(name)) return _cache[name]!;
    try {
      final f = await file(name);
      if (await f.exists()) {
        final content = await f.readAsString();
        if (content.isEmpty) {
          _cache[name] = {};
          return {};
        }
        final data = jsonDecode(content) as Map<String, dynamic>;
        _cache[name] = data;
        return data;
      }
    } catch (_) {}
    _cache[name] = {};
    return {};
  }

  static Future<void> saveJson(String name, Map<String, dynamic> data) async {
    _cache[name] = data;
    final f = await file(name);
    await f.writeAsString(jsonEncode(data));
  }

  static Future<Map<String, dynamic>> getSettings() => loadJson('settings');

  static Future<void> setSetting(String key, dynamic value) async {
    final data = await getSettings();
    data[key] = value;
    await saveJson('settings', data);
  }

  static Future<T?> getSetting<T>(String key) async {
    final data = await getSettings();
    return data[key] as T?;
  }

  static Future<Map<String, dynamic>> getSpeedtest() => loadJson('speedtest');

  static Future<void> setSpeedtestSetting(String key, dynamic value) async {
    final data = await getSpeedtest();
    data[key] = value;
    await saveJson('speedtest', data);
  }

  static Future<T?> getSpeedtestSetting<T>(String key) async {
    final data = await getSpeedtest();
    return data[key] as T?;
  }

  static Future<void> addSpeedtestHistory(Map<String, dynamic> entry) async {
    final data = await getSpeedtest();
    final list = data['history'] as List? ?? [];
    entry['id'] = 'history_${DateTime.now().millisecondsSinceEpoch}';
    list.insert(0, entry);
    if (list.length > 100) list.removeRange(100, list.length);
    data['history'] = list;
    await saveJson('speedtest', data);
  }

  static Future<Map<String, dynamic>> getMikrotik() => loadJson('mikrotik');

  static Future<void> setMikrotikCard(
    String id,
    Map<String, dynamic> config,
  ) async {
    final data = await getMikrotik();
    data[id] = config;
    await saveJson('mikrotik', data);
  }

  static Future<Map<String, dynamic>?> getMikrotikCard(String id) async {
    final data = await getMikrotik();
    final card = data[id];
    return card != null ? Map<String, dynamic>.from(card as Map) : null;
  }

  static Future<void> removeMikrotikCard(String id) async {
    final data = await getMikrotik();
    data.remove(id);
    await saveJson('mikrotik', data);
  }

  static Future<Map<String, dynamic>> getPing() => loadJson('ping');

  static Future<void> setPingCard(
    String id,
    Map<String, dynamic> config,
  ) async {
    final data = await getPing();
    data[id] = config;
    await saveJson('ping', data);
  }

  static Future<void> removePingCard(String id) async {
    final data = await getPing();
    data.remove(id);
    await saveJson('ping', data);
  }

  static Future<Map<String, dynamic>> getWifi() => loadJson('wifi');

  static Future<void> setWifiSetting(String key, dynamic value) async {
    final data = await getWifi();
    data[key] = value;
    await saveJson('wifi', data);
  }

  static Future<T?> getWifiSetting<T>(String key) async {
    final data = await getWifi();
    return data[key] as T?;
  }

  static Future<Map<String, dynamic>> getAppSettings() => getSettings();
  static Future<void> setAppSetting(String key, dynamic value) =>
      setSetting(key, value);
  static Future<T?> getAppSetting<T>(String key) => getSetting<T>(key);
  static Future<List<Map<String, dynamic>>> getHistory({
    int limit = 100,
  }) async {
    final data = await getSpeedtest();
    final list = data['history'] as List? ?? [];
    return list.take(limit).toList().cast<Map<String, dynamic>>();
  }

  static Future<void> clearHistory() async {
    final data = await getSpeedtest();
    data['history'] = [];
    await saveJson('speedtest', data);
  }

  static Future<String> addHistory(Map<String, dynamic> entry) async {
    final id = 'history_${DateTime.now().millisecondsSinceEpoch}';
    entry['id'] = id;
    await addSpeedtestHistory(entry);
    return id;
  }

  static const List<String> _allFiles = [
    'settings',
    'speedtest',
    'mikrotik',
    'ping',
    'wifi',
  ];

  static Future<Map<String, dynamic>> exportAllData() async {
    final Map<String, dynamic> allData = {};
    for (final name in _allFiles) {
      allData[name] = await loadJson(name);
    }
    return allData;
  }

  static Future<void> importAllData(Map<String, dynamic> data) async {
    for (final name in _allFiles) {
      if (data.containsKey(name)) {
        await saveJson(name, Map<String, dynamic>.from(data[name]));
      }
    }
  }
}
