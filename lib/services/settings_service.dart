import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../database/database.dart';

class SettingsProvider extends ChangeNotifier {
  static const List<String> _keys = [
    'saved_hosts',
    'mk_host',
    'mk_user',
    'mk_pass',
    'mk_ifaces',
    'mk_refresh',
    'mk_monitor',
    'st_url',
    'st_name',
    'wifi_refresh',
    'wifi_monitor',
  ];

  Future<String> exportToClipboard() async {
    final jsonStr = await _getBackupJson();
    await Clipboard.setData(ClipboardData(text: jsonStr));
    return jsonStr;
  }

  Future<String?> exportToFile() async {
    try {
      final jsonStr = await _getBackupJson();

      if (!kIsWeb && Platform.isLinux) {
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save NetPulse Backup',
          fileName: 'netpulse_backup.json',
          allowedExtensions: ['json'],
          type: FileType.custom,
          bytes: utf8.encode(jsonStr),
        );
        return outputFile;
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/netpulse_backup.json');
        await file.writeAsString(jsonStr);
        await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], text: 'NetPulse Backup'),
        );
        return "Shared";
      }
    } catch (e) {
      debugPrint('Export File Error: $e');
      return null;
    }
  }

  Future<bool> importFromString(String jsonStr) async {
    return await _applyBackup(jsonStr);
  }

  Future<bool> importFromFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: kIsWeb || Platform.isLinux ? FileType.custom : FileType.any,
        allowedExtensions: kIsWeb || Platform.isLinux ? ['json'] : null,
        withData: true,
      );

      if (result != null) {
        String? content;
        if (result.files.single.path != null) {
          final file = File(result.files.single.path!);
          content = await file.readAsString();
        } else if (result.files.single.bytes != null) {
          content = utf8.decode(result.files.single.bytes!);
        }

        if (content != null) {
          return await _applyBackup(content);
        }
      }
    } catch (e) {
      debugPrint('Import File Error: $e');
    }
    return false;
  }

  Future<String> _getBackupJson() async {
    final settings = await AppDatabase.getAppSettings();
    final Map<String, dynamic> backup = {};
    for (var key in _keys) {
      if (settings.containsKey(key)) {
        backup[key] = settings[key];
      }
    }
    return jsonEncode(backup);
  }

  Future<bool> _applyBackup(String jsonStr) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      for (var entry in data.entries) {
        if (_keys.contains(entry.key)) {
          await AppDatabase.setSetting(entry.key, entry.value);
        }
      }
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }
}
