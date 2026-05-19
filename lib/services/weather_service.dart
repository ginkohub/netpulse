import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'log_service.dart';

class WeatherData {
  final double temperature;
  final int humidity;
  final int weatherCode;
  final double windSpeed;
  final String locationName;
  final List<DailyForecast> daily;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.weatherCode,
    required this.windSpeed,
    required this.locationName,
    this.daily = const [],
  });

  factory WeatherData.fromJson(Map<String, dynamic> json, String location) {
    final current = json['current'];
    final dailyData = json['daily'];
    List<DailyForecast> dailyList = [];
    
    if (dailyData != null) {
      final times = dailyData['time'] as List? ?? [];
      final maxTemps = dailyData['temperature_2m_max'] as List? ?? [];
      final minTemps = dailyData['temperature_2m_min'] as List? ?? [];
      final codes = dailyData['weather_code'] as List? ?? [];
      
      for (int i = 0; i < times.length && i < 7; i++) {
        dailyList.add(DailyForecast(
          date: DateTime.parse(times[i]),
          maxTemp: (maxTemps[i] as num?)?.toDouble() ?? 0,
          minTemp: (minTemps[i] as num?)?.toDouble() ?? 0,
          weatherCode: (codes[i] as num?)?.toInt() ?? 0,
        ));
      }
    }
    
    return WeatherData(
      temperature: current['temperature_2m']?.toDouble() ?? 0.0,
      humidity: current['relative_humidity_2m']?.toInt() ?? 0,
      weatherCode: current['weather_code']?.toInt() ?? 0,
      windSpeed: current['wind_speed_10m']?.toDouble() ?? 0.0,
      locationName: location,
      daily: dailyList,
    );
  }

  String get weatherDescription {
    switch (weatherCode) {
      case 0: return 'Clear sky';
      case 1: case 2: case 3: return 'Partly cloudy';
      case 45: case 48: return 'Fog';
      case 51: case 53: case 55: return 'Drizzle';
      case 61: case 63: case 65: return 'Rain';
      case 71: case 73: case 75: return 'Snow';
      case 77: return 'Snow grains';
      case 80: case 81: case 82: return 'Rain showers';
      case 85: case 86: return 'Snow showers';
      case 95: return 'Thunderstorm';
      case 96: case 99: return 'Thunderstorm with hail';
      default: return 'Unknown';
    }
  }

  IconData get weatherIcon {
    switch (weatherCode) {
      case 0: return Icons.wb_sunny;
      case 1: case 2: case 3: return Icons.wb_cloudy;
      case 45: case 48: return Icons.cloud_queue;
      case 51: case 53: case 55: return Icons.grain;
      case 61: case 63: case 65: return Icons.umbrella;
      case 71: case 73: case 75: return Icons.ac_unit;
      case 80: case 81: case 82: return Icons.beach_access;
      case 95: case 96: case 99: return Icons.thunderstorm;
      default: return Icons.help_outline;
    }
  }
}

class DailyForecast {
  final DateTime date;
  final double maxTemp;
  final double minTemp;
  final int weatherCode;

  DailyForecast({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.weatherCode,
  });

  String get dayName {
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month) return 'Today';
    if (date.day == now.day + 1 && date.month == now.month) return 'Tomorrow';
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return days[date.weekday % 7];
  }

  String get weatherDescription {
    switch (weatherCode) {
      case 0: return 'Clear';
      case 1: case 2: case 3: return 'Cloudy';
      case 45: case 48: return 'Fog';
      case 51: case 53: case 55: return 'Drizzle';
      case 61: case 63: case 65: return 'Rain';
      case 71: case 73: case 75: return 'Snow';
      case 95: case 96: case 99: return 'Storm';
      default: return 'Unknown';
    }
  }

  IconData get weatherIcon {
    switch (weatherCode) {
      case 0: return Icons.wb_sunny;
      case 1: case 2: case 3: return Icons.wb_cloudy;
      case 45: case 48: return Icons.cloud_queue;
      case 51: case 53: case 55: return Icons.grain;
      case 61: case 63: case 65: return Icons.umbrella;
      case 71: case 73: case 75: return Icons.ac_unit;
      case 95: case 96: case 99: return Icons.thunderstorm;
      default: return Icons.help_outline;
    }
  }
}

class WeatherProvider extends ChangeNotifier {
  final LogProvider? logger;
  WeatherData? _data;
  bool _isLoading = false;
  String? _error;
  bool _isDemoMode = false;

  WeatherProvider({this.logger});

  WeatherData? get data => _data;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isDemoMode => _isDemoMode;

  void setDemoMode(bool value) {
    _isDemoMode = value;
    if (value) {
      final now = DateTime.now();
      _data = WeatherData(
        temperature: 28.5,
        humidity: 75,
        weatherCode: 1,
        windSpeed: 12.0,
        locationName: 'Jakarta (Demo)',
        daily: List.generate(7, (i) => DailyForecast(
          date: now.add(Duration(days: i)),
          maxTemp: 28.0 + (i * 0.5).roundToDouble(),
          minTemp: 22.0 + (i * 0.3).roundToDouble(),
          weatherCode: [0, 1, 2, 61, 1, 0, 3][i],
        )),
      );
    } else {
      fetchWeather();
    }
    notifyListeners();
  }

  Future<void> fetchWeather() async {
    if (_isDemoMode) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied.';
      }

      Position position = await Geolocator.getCurrentPosition();
      
      // Fetch weather data
      final weatherUrl = 'https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min,weather_code&timezone=auto';
      final weatherResponse = await http.get(Uri.parse(weatherUrl));

      // Fetch location name (Reverse Geocoding)
      String locationName = 'Unknown Location';
      try {
        final geoUrl = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=10';
        final geoResponse = await http.get(
          Uri.parse(geoUrl),
          headers: {'User-Agent': 'NetPulse/1.0'},
        );
        if (geoResponse.statusCode == 200) {
          final geoJson = jsonDecode(geoResponse.body);
          final address = geoJson['address'];
          locationName = address['city'] ?? address['town'] ?? address['village'] ?? address['county'] ?? 'Current Location';
        }
      } catch (_) {
        // Fallback to coordinates if geocoding fails
      }

      if (weatherResponse.statusCode == 200) {
        final json = jsonDecode(weatherResponse.body);
        _data = WeatherData.fromJson(json, locationName);
        logger?.addLog('[Weather] Fetched weather for $locationName (${position.latitude}, ${position.longitude})');
      } else {
        throw 'Failed to load weather data';
      }
    } catch (e) {
      _error = e.toString();
      logger?.addLog('[Weather] Error: $e', level: 'ERROR');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
