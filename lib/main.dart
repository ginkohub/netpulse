import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/ping_service.dart';
import 'services/wifi_service.dart';
import 'services/speedtest_service.dart';
import 'services/settings_service.dart';
import 'services/history_service.dart';
import 'services/log_service.dart';
import 'services/update_service.dart';
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
        ChangeNotifierProvider(create: (context) => PingProvider()),
        ChangeNotifierProvider(create: (context) => WifiProvider()),
        ChangeNotifierProvider(
          create: (context) => SpeedTestProvider(logger: logProvider),
        ),
        ChangeNotifierProvider(create: (context) => SettingsProvider()),
        ChangeNotifierProvider(create: (context) => HistoryProvider()),
        ChangeNotifierProvider(create: (context) => UpdateProvider()),
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
