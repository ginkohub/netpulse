import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wifi_service.dart';
import 'base_card.dart';

class WifiInfoCard extends StatelessWidget {
  const WifiInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WifiProvider>(
      builder: (context, wifi, child) {
        final isConnected = wifi.status == 'Connected';

        return BaseCard(
          title: wifi.isDemoMode ? 'Demo Network' : (wifi.ssid ?? 'No WiFi'),
          subtitle: wifi.isDemoMode ? 'Demo' : wifi.status,
          subtitleColor: isConnected ? Colors.greenAccent : Colors.orangeAccent,
          leading: Icon(
            isConnected ? Icons.wifi : Icons.wifi_off,
            color: isConnected ? Colors.blueAccent : Colors.grey,
            size: 24,
          ),
          trailing: isConnected && wifi.signalStrength != null
              ? _buildSignalIndicator(wifi.signalStrength!)
              : null,
          onDoubleTap: () => _showSettingsDialog(context, wifi),
          children: isConnected
              ? [
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: _buildGrid(wifi),
                  ),
                ]
              : null,
        );
      },
    );
  }

  void _showSettingsDialog(BuildContext context, WifiProvider wifi) {
    int currentInterval = wifi.refreshInterval;
    bool demoMode = wifi.isDemoMode;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          title: const Text(
            'WiFi Settings',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Refresh Rate:', style: TextStyle(fontSize: 14)),
                    DropdownButton<int>(
                      value: currentInterval,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                      items: [2, 5, 10, 30, 60]
                          .map(
                            (v) =>
                                DropdownMenuItem(value: v, child: Text('$v s')),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => currentInterval = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Demo Mode:', style: TextStyle(fontSize: 14)),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: demoMode,
                        onChanged: (v) => setState(() => demoMode = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(fontSize: 13)),
            ),
            TextButton(
              onPressed: () {
                if (demoMode != wifi.isDemoMode) {
                  wifi.setDemoMode(demoMode);
                }
                if (currentInterval != wifi.refreshInterval) {
                  wifi.setRefreshInterval(currentInterval);
                }
                Navigator.pop(context);
              },
              child: const Text(
                'SAVE',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(WifiProvider wifi) {
    return Wrap(
      spacing: 20,
      runSpacing: 10,
      children: [
        _buildDetailItem('IP ADDR', wifi.ip ?? '-', Icons.lan),
        _buildDetailItem(
          'GATEWAY',
          wifi.gateway ?? '-',
          Icons.settings_input_component,
        ),
        _buildDetailItem('DNS', wifi.dns ?? '-', Icons.dns),
        _buildDetailItem('BSSID', wifi.bssid ?? '-', Icons.router),
        _buildDetailItem('SPEED', '${wifi.speed}Mbps', Icons.speed),
        if (wifi.frequency != null)
          _buildDetailItem('FREQ', '${wifi.frequency}MHz', Icons.wifi_channel),
        if (wifi.channel != null)
          _buildDetailItem('CH', '${wifi.channel}', Icons.tag),
        if (wifi.band != null) _buildDetailItem('BAND', wifi.band!, Icons.wifi),
        if (wifi.security != null)
          _buildDetailItem('SECURITY', wifi.security!, Icons.lock),
        if (wifi.standard != null)
          _buildDetailItem('STD', wifi.standard!, Icons.hardware),
        if (wifi.txSpeed != null)
          _buildDetailItem('TX', '${wifi.txSpeed}Mbps', Icons.upload),
        if (wifi.rxSpeed != null)
          _buildDetailItem('RX', '${wifi.rxSpeed}Mbps', Icons.download),
        if (wifi.connectionType != null)
          _buildDetailItem('NET', wifi.connectionType!, Icons.cell_tower),
        if (wifi.isMetered != null)
          _buildDetailItem(
            'METERED',
            wifi.isMetered! ? 'Yes' : 'No',
            Icons.monetization_on,
          ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return SizedBox(
      width: 130,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blueAccent.withAlpha(150)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 8,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalIndicator(int rssi) {
    Color color = Colors.greenAccent;
    if (rssi < -80) {
      color = Colors.redAccent;
    } else if (rssi < -67) {
      color = Colors.orangeAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.signal_wifi_4_bar, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$rssi dBm',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
