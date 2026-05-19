import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'log_service.dart';

class HopResult {
  final int hop;
  final String host;
  final String ip;
  final double time;

  HopResult({
    required this.hop,
    required this.host,
    required this.ip,
    required this.time,
  });
}

class TracerouteProvider extends ChangeNotifier {
  final LogProvider? logger;
  final List<HopResult> _hops = [];
  bool _isTracing = false;
  String? _target;
  String? _lastInput;
  double _progress = 0;

  TracerouteProvider({this.logger});

  List<HopResult> get hops => _hops;
  bool get isTracing => _isTracing;
  String? get target => _target;
  String? get lastInput => _lastInput;
  double get progress => _progress;

  void clear() {
    _hops.clear();
    _target = null;
    _progress = 0;
    notifyListeners();
  }

  Future<void> startTrace(String host) async {
    if (_isTracing) return;
    
    _isTracing = true;
    _target = host;
    _hops.clear();
    _progress = 0.1;
    notifyListeners();
    
    logger?.addLog('[Traceroute] Starting trace to $host');

    try {
      if (Platform.isAndroid || Platform.isLinux) {
        // Simple implementation using ping -t (TTL) loop to be more compatible
        for (int ttl = 1; ttl <= 30; ttl++) {
          if (!_isTracing) break;
          
          _progress = ttl / 30;
          notifyListeners();

          final stopwatch = Stopwatch()..start();
          final result = await Process.run('ping', ['-c', '1', '-t', ttl.toString(), '-W', '2', host]);
          stopwatch.stop();
          
          final output = result.stdout.toString();
          final double elapsedMs = stopwatch.elapsedMicroseconds / 1000.0;
          
          // Look for "From <ip>" or "64 bytes from <ip>"
          String? foundIp;
          double time = elapsedMs; // Use measured time as default

          if (output.contains('From')) {
            // Exited due to TTL exceeded
            final match = RegExp(r'From ([\d\.]+|[\w\.-]+)').firstMatch(output);
            foundIp = match?.group(1);
          } else if (output.contains('bytes from')) {
            // Reached destination
            final match = RegExp(r'from ([\d\.]+|[\w\.-]+):.*time=([\d\.]+)').firstMatch(output);
            foundIp = match?.group(1);
            // If the command provides a more precise time, use it
            if (match?.group(2) != null) {
              time = double.tryParse(match!.group(2)!) ?? elapsedMs;
            }
          }

          if (foundIp != null) {
            final hop = HopResult(
              hop: ttl,
              host: foundIp,
              ip: foundIp,
              time: time,
            );
            _hops.add(hop);
            notifyListeners();
            
            if (output.contains('bytes from')) {
              logger?.addLog('[Traceroute] Reached destination: $foundIp');
              break; 
            }
          } else {
            _hops.add(HopResult(hop: ttl, host: '*', ip: '*', time: 0));
            notifyListeners();
          }
        }
      }
    } catch (e) {
      logger?.addLog('[Traceroute] Error: $e', level: 'ERROR');
    } finally {
      _isTracing = false;
      _progress = 1.0;
      notifyListeners();
      logger?.addLog('[Traceroute] Finished trace to $host');
    }
  }

  void stopTrace() {
    _isTracing = false;
    notifyListeners();
  }

  void setLastInput(String input) {
    _lastInput = input;
    notifyListeners();
  }
}
