import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ping_service.dart';
import 'wifi_service.dart';
import 'speedtest_service.dart';
import 'mikrotik_service.dart';
import 'settings_service.dart';
import 'history_service.dart';
import 'log_service.dart';
import 'update_service.dart';
import 'pages/home_page.dart';

void main() {
  final logProvider = LogProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LogProvider>.value(value: logProvider),

        ChangeNotifierProvider(create: (context) => PingProvider()),
        ChangeNotifierProvider(create: (context) => WifiProvider()),

        ChangeNotifierProvider(create: (context) => SpeedTestProvider(logger: logProvider)),
        ChangeNotifierProvider(create: (context) => MikrotikProvider(logger: logProvider)),

        ChangeNotifierProvider(create: (context) => SettingsProvider()),
        ChangeNotifierProvider(create: (context) => HistoryProvider()),
        ChangeNotifierProvider(create: (context) => UpdateProvider()),
      ],
      child: const NetPulseApp(),
    ),
  );
}

class NetPulseApp extends StatelessWidget {
  const NetPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NetPulse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
