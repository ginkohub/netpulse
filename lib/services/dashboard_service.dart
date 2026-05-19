import 'package:flutter/material.dart';
import '../database/database.dart';
import 'log_service.dart';

enum DashboardItemType {
  wifi,
  mikrotik,
  speedtest,
  ping,
  portScanner,
  ipScanner,
  weather,
  traceroute,
  ipInfo,
  mdns,
  dns,
}

class DashboardItem {
  final DashboardItemType type;
  final String? value;

  DashboardItem({required this.type, this.value});

  Map<String, dynamic> toJson() => {'type': type.index, 'value': value};

  factory DashboardItem.fromJson(Map<String, dynamic> json) => DashboardItem(
    type: DashboardItemType.values[json['type']],
    value: json['value'],
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashboardItem &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          value == other.value;

  @override
  int get hashCode => type.hashCode ^ value.hashCode;
}

class DashboardProvider extends ChangeNotifier {
  final LogProvider? logger;
  List<DashboardItem> _items = [];
  bool _isReorderEnabled = false;

  static const String _storageKey = 'cards';
  static const String _reorderEnabledKey = 'reorder_enabled';

  DashboardProvider({this.logger}) {
    _loadDashboard();
  }

  List<DashboardItem> get items => _items;
  bool get isReorderEnabled => _isReorderEnabled;

  Future<void> _loadDashboard() async {
    _isReorderEnabled = await AppDatabase.getSetting<bool>(_reorderEnabledKey) ?? false;
    final saved = await AppDatabase.getSetting<List<dynamic>>(_storageKey);

    if (saved == null || saved.isEmpty) {
      _items = [];
    } else {
      _items = saved
          .map((s) => DashboardItem.fromJson(Map<String, dynamic>.from(s)))
          .toList();
    }
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final data = _items.map((i) => i.toJson()).toList();
    await AppDatabase.setSetting(_storageKey, data);
  }

  void toggleReorder() async {
    _isReorderEnabled = !_isReorderEnabled;
    notifyListeners();
    await AppDatabase.setSetting(_reorderEnabledKey, _isReorderEnabled);
  }

  void reorderItems(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
    _saveToPrefs();
    notifyListeners();
  }

  void addItem(DashboardItemType type, {String? value}) {
    if (type == DashboardItemType.wifi ||
        type == DashboardItemType.speedtest ||
        type == DashboardItemType.portScanner ||
        type == DashboardItemType.ipScanner ||
        type == DashboardItemType.weather) {
      if (!_items.any((i) => i.type == type)) {
        _items.add(DashboardItem(type: type, value: value));
        _saveToPrefs();
        notifyListeners();
      }
    } else {
      final newValue = value ?? '${type.name}_${DateTime.now().millisecondsSinceEpoch}';
      _items.add(DashboardItem(type: type, value: newValue));
      _saveToPrefs();
      notifyListeners();
    }
  }

  void removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      _saveToPrefs();
      notifyListeners();
    }
  }

  void removeItemByType(DashboardItemType type, String? value) {
    _items.removeWhere((i) => i.type == type && i.value == value);
    _saveToPrefs();
    notifyListeners();
  }
}
