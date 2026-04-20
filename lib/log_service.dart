import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class LogEntry {
  final DateTime timestamp;
  final String message;
  final String level;

  LogEntry({required this.timestamp, required this.message, this.level = 'INFO'});
}

class LogProvider extends ChangeNotifier {
  final List<LogEntry> _logs = [];
  final int _maxLogs = 200;

  List<LogEntry> get logs => _logs.reversed.toList();

  void addLog(String message, {String level = 'INFO'}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      message: message,
      level: level,
    );

    _logs.add(entry);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }

    debugPrint('[$level] ${DateFormat('HH:mm:ss').format(entry.timestamp)}: $message');
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    addLog('Logs cleared');
    notifyListeners();
  }
}
