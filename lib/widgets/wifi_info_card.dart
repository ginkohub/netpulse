import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../wifi_service.dart';
import '../speedtest_service.dart';
import 'info_text_widget.dart';

class WifiInfoCard extends StatelessWidget {
  const WifiInfoCard({super.key});

  void _showWifiSettings(BuildContext context, WifiProvider wifi) {
    int currentInterval = wifi.refreshInterval;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('WiFi Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Refresh Rate:'),
                  DropdownButton<int>(
                    value: currentInterval,
                    items: [2, 5, 10, 30].map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value s'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => currentInterval = val);
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                wifi.setRefreshInterval(currentInterval);
                Navigator.pop(context);
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WifiProvider>(
      builder: (context, wifi, child) {
        if (wifi.status != 'Connected') return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.fromLTRB(8, 1, 8, 1),
          elevation: 1,
          color: Colors.blueAccent.withAlpha(13),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 4, 4),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'WIFI',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: Colors.blueAccent,
                      ),
                    ),
                    Row(
                      children: [
                        Transform.scale(
                          scale: 0.45,
                          child: Switch(
                            value: wifi.isMonitoring,
                            onChanged: (_) => wifi.toggleMonitoring(),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.settings,
                            size: 12,
                            color: Colors.blueAccent,
                          ),
                          onPressed: () => _showWifiSettings(context, wifi),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
                Wrap(
                  spacing: 2,
                  runSpacing: 2,
                  children: [
                    StatChip(icon: Icons.wifi, value: wifi.ssid ?? 'WiFi'),
                    StatChip(
                      icon: Icons.signal_cellular_alt,
                      value: '${wifi.signalStrength ?? "--"} dBm',
                    ),
                    StatChip(icon: Icons.router, value: wifi.bssid ?? 'AP'),
                    StatChip(icon: Icons.public, value: wifi.ip ?? 'IP'),
                    StatChip(
                      icon: Icons.fingerprint,
                      value: wifi.clientMac ?? 'MAC',
                    ),
                    Consumer<SpeedTestProvider>(
                      builder: (context, st, child) {
                        return StatChip(
                          icon: Icons.cloud_queue,
                          value: '${st.clientIsp} (${st.clientIp})',
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
