import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../database/database.dart';
import 'log_service.dart';

class SettingsProvider extends ChangeNotifier {
  final LogProvider? logger;

  SettingsProvider({this.logger});

  Future<String> exportToClipboard() async {
    final data = await AppDatabase.exportAllData();
    final jsonStr = jsonEncode(data);
    await Clipboard.setData(ClipboardData(text: jsonStr));
    return jsonStr;
  }

  Future<String?> exportToFile() async {
    try {
      final data = await AppDatabase.exportAllData();
      final jsonStr = jsonEncode(data);

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
      logger?.addLog('Export File Error: $e', level: 'ERROR');
      return null;
    }
  }

  Future<bool> importFromString(String jsonStr) async {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      await AppDatabase.importAllData(data);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
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
          final data = jsonDecode(content) as Map<String, dynamic>;
          await AppDatabase.importAllData(data);
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      logger?.addLog('Import File Error: $e', level: 'ERROR');
    }
    return false;
  }
}
