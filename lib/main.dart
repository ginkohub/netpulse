import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/ping_service.dart';
import 'services/wifi_service.dart';
import 'services/speedtest_service.dart';
import 'services/settings_service.dart';
import 'services/speedtest_history.dart';
import 'services/log_service.dart';
import 'services/update_service.dart';
import 'services/mikrotik_service.dart';
import 'services/port_scanner_service.dart';
import 'services/ip_scanner_service.dart';
import 'pages/home_page.dart';
import 'database/database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.getAppSettings();

  runApp(const NetPulseApp());
}

class NetPulseApp extends StatelessWidget {
  const NetPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final logProvider = LogProvider();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LogProvider>.value(value: logProvider),
        ChangeNotifierProvider(
          create: (context) => PingProvider(logger: logProvider),
        ),
        ChangeNotifierProvider(
          create: (context) => WifiProvider(logger: logProvider),
        ),
        ChangeNotifierProvider(
          create: (context) => SpeedTestProvider(logger: logProvider),
        ),
        ChangeNotifierProvider(
          create: (context) => SettingsProvider(logger: logProvider),
        ),
        ChangeNotifierProvider(
          create: (context) => HistoryProvider(logger: logProvider),
        ),
        ChangeNotifierProvider(
          create: (context) => UpdateProvider(logger: logProvider),
        ),
        ChangeNotifierProvider(
          create: (context) => MikrotikProvider(logger: logProvider),
        ),
        ChangeNotifierProvider(
          create: (context) => PortScannerProvider(logger: logProvider),
        ),
        ChangeNotifierProvider(
          create: (context) => IPScannerProvider(logger: logProvider),
        ),
      ],
      child: MaterialApp(
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
      ),
    );
  }
}
