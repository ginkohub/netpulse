import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateProvider extends ChangeNotifier {
  String _currentVersion = '';
  String _latestVersion = '';
  String _downloadUrl = '';
  bool _isChecking = false;
  bool _hasUpdate = false;
  String? _error;

  String get currentVersion => _currentVersion;
  String get latestVersion => _latestVersion;
  bool get isChecking => _isChecking;
  bool get hasUpdate => _hasUpdate;
  String? get error => _error;

  UpdateProvider() {
    _init();
  }

  Future<void> _init() async {
    final info = await PackageInfo.fromPlatform();
    _currentVersion = info.version;
    notifyListeners();
  }

  Future<void> checkForUpdates({bool silent = false}) async {
    if (_isChecking) return;
    _isChecking = true;
    _error = null;
    if (!silent) notifyListeners();

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/ginkohub/netpulse/releases/latest',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _latestVersion = (data['tag_name'] as String).replaceAll('v', '');
        _downloadUrl =
            data['html_url'] ?? 'https://github.com/ginkohub/netpulse/releases';

        _hasUpdate = _isNewerVersion(_currentVersion, _latestVersion);
      } else {
        _error = 'Failed to fetch version (HTTP ${response.statusCode})';
        debugPrint('Update Check Failed: ${response.body}');
      }
    } catch (e) {
      _error = 'Connection error: $e';
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  bool _isNewerVersion(String current, String latest) {
    List<int> currentParts = current
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    List<int> latestParts = latest
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();

    for (int i = 0; i < latestParts.length; i++) {
      int curr = i < currentParts.length ? currentParts[i] : 0;
      if (latestParts[i] > curr) return true;
      if (latestParts[i] < curr) return false;
    }
    return false;
  }

  Future<void> launchDownloadUrl() async {
    if (_downloadUrl.isNotEmpty) {
      final uri = Uri.parse(_downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}
