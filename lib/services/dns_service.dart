import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'log_service.dart';

class DnsRecord {
  final String type;
  final String value;
  final int? ttl;

  DnsRecord({required this.type, required this.value, this.ttl});
}

class WhoisInfo {
  final String? registrar;
  final String? creationDate;
  final String? expirationDate;
  final String? nameServers;
  final String? status;
  final String? raw;

  WhoisInfo({
    this.registrar,
    this.creationDate,
    this.expirationDate,
    this.nameServers,
    this.status,
    this.raw,
  });
}

class DnsProvider extends ChangeNotifier {
  final LogProvider? logger;
  final List<DnsRecord> _records = [];
  WhoisInfo? _whois;
  bool _isLoading = false;
  String? _error;
  String? _lastQuery;
  String? _lastInput;

  DnsProvider({this.logger});

  List<DnsRecord> get records => _records;
  WhoisInfo? get whois => _whois;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get lastQuery => _lastQuery;
  String? get lastInput => _lastInput;

  Future<void> lookup(String domain) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _records.clear();
    _whois = null;
    _lastQuery = domain;
    notifyListeners();

    logger?.addLog('[DNS] Looking up: $domain');

    try {
      final types = ['A', 'AAAA', 'MX', 'CNAME', 'TXT', 'NS'];
      for (final type in types) {
        await _lookupRecordType(domain, type);
      }
      logger?.addLog('[DNS] Found ${_records.length} records for $domain');
    } catch (e) {
      _error = e.toString();
      logger?.addLog('[DNS] Error: $e', level: 'ERROR');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _lookupRecordType(String domain, String type) async {
    try {
      List<String> args;
      if (Platform.isAndroid || Platform.isLinux) {
        args = [domain, '-t', type];
      } else {
        args = [type, domain];
      }
      final result = await Process.run('nslookup', args);
      final output = result.stdout.toString();

      if (output.contains('can\'t find') || output.contains('NXDOMAIN')) {
        return;
      }

      final lines = output.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('Server:') || trimmed.startsWith('Address:')) {
          continue;
        }

        String? value;
        if (trimmed.startsWith(type)) {
          final parts = trimmed.split('=');
          if (parts.length > 1) {
            value = parts.sublist(1).join('=').trim();
          }
        } else if (trimmed.contains('=')) {
          final parts = trimmed.split('=');
          if (parts.length > 1 && parts[0].trim() == type.toLowerCase()) {
            value = parts.sublist(1).join('=').trim();
          }
        }

        if (value != null && value.isNotEmpty && !value.startsWith('#')) {
          value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (type == 'MX' && value.contains('.')) {
            final mxParts = value.split(' ');
            if (mxParts.length > 1) {
              value = 'Priority ${mxParts[0]}, ${mxParts.sublist(1).join(' ')}';
            }
          }
          _records.add(DnsRecord(type: type, value: value));
        }
      }
    } catch (e) {
      logger?.addLog('[DNS] Failed to lookup $type: $e');
    }
  }

  Future<void> whoisLookup(String domain) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _lastQuery = domain;
    notifyListeners();

    logger?.addLog('[WHOIS] Looking up: $domain');

    try {
      String output = '';
      if (Platform.isAndroid || Platform.isLinux) {
        try {
          final result = await Process.run('whois', [domain]);
          output = result.stdout.toString();
        } catch (e) {
          if (e.toString().contains('No such file')) {
            _error = 'WHOIS command not installed.\nInstall with: sudo apt install whois';
            _isLoading = false;
            notifyListeners();
            return;
          }
          rethrow;
        }
      }

      if (output.isEmpty) {
        throw 'WHOIS not available on this platform';
      }

      String? registrar;
      String? creationDate;
      String? expirationDate;
      String? nameServers;
      String? status;

      final lines = output.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.contains(':')) {
          final parts = trimmed.split(':');
          final key = parts[0].trim().toLowerCase();
          final value = parts.sublist(1).join(':').trim();

          if (key.contains('registrar') && registrar == null) {
            registrar = value;
          } else if ((key.contains('creation') || key.contains('created')) && creationDate == null) {
            creationDate = value;
          } else if ((key.contains('expir') || key.contains('registry') || key.contains('updated')) && expirationDate == null) {
            expirationDate = value;
          } else if ((key.contains('name server') || key.contains('nserver')) && nameServers == null) {
            nameServers = value;
          } else if (key.contains('status') && status == null) {
            status = value;
          }
        }
      }

      _whois = WhoisInfo(
        registrar: registrar,
        creationDate: creationDate,
        expirationDate: expirationDate,
        nameServers: nameServers,
        status: status,
        raw: output,
      );

      logger?.addLog('[WHOIS] Retrieved info for $domain');
    } catch (e) {
      _error = e.toString();
      logger?.addLog('[WHOIS] Error: $e', level: 'ERROR');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setLastInput(String input) {
    _lastInput = input;
    notifyListeners();
  }

  void clear() {
    _records.clear();
    _whois = null;
    _error = null;
    _lastQuery = null;
    notifyListeners();
  }
}