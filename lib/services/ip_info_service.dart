import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'log_service.dart';

class IpInfoData {
  final String ip;
  final String isp;
  final String org;
  final String city;
  final String region;
  final String country;
  final String timezone;

  IpInfoData({
    required this.ip,
    required this.isp,
    required this.org,
    required this.city,
    required this.region,
    required this.country,
    required this.timezone,
  });

  factory IpInfoData.fromIpApi(Map<String, dynamic> json) {
    return IpInfoData(
      ip: json['query'] ?? '',
      isp: json['isp'] ?? '',
      org: json['org'] ?? '',
      city: json['city'] ?? '',
      region: json['regionName'] ?? '',
      country: json['country'] ?? '',
      timezone: json['timezone'] ?? '',
    );
  }
}

class IpInfoProvider extends ChangeNotifier {
  final LogProvider? logger;
  IpInfoData? _data;
  bool _isLoading = false;
  String? _error;

  IpInfoProvider({this.logger});

  IpInfoData? get data => _data;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchIpInfo() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('http://ip-api.com/json/?fields=status,message,country,countryCode,region,regionName,city,zip,lat,lon,timezone,isp,org,as,query'));
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 'fail') {
          throw json['message'] ?? 'Failed to fetch IP info';
        }
        _data = IpInfoData.fromIpApi(json);
        logger?.addLog('[IP Info] Fetched: ${_data!.ip} - ${_data!.isp}');
      } else {
        throw 'HTTP ${response.statusCode}';
      }
    } catch (e) {
      _error = e.toString();
      logger?.addLog('[IP Info] Error: $e', level: 'ERROR');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}