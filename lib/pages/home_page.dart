import 'package:flutter/material.dart';
import 'package:netpulse/services/mikrotik_service.dart';
import 'package:provider/provider.dart';
import '../services/ping_service.dart';
import '../services/wifi_service.dart';
import '../services/settings_service.dart';
import '../services/speedtest_service.dart';
import '../services/port_scanner_service.dart';
import '../services/ip_scanner_service.dart';
import '../services/weather_service.dart';
import '../services/dashboard_service.dart';
import 'log_page.dart';
import 'about_page.dart';
import '../widgets/wifi_info_card.dart';
import '../widgets/mikrotik_card.dart';
import '../widgets/speed_test_card.dart';
import '../widgets/ping_card.dart';
import '../widgets/port_scanner_card.dart';
import '../widgets/ip_scanner_card.dart';
import '../widgets/weather_card.dart';
import '../widgets/traceroute_card.dart';
import '../widgets/ip_info_card.dart';
import '../widgets/mdns_card.dart';
import '../widgets/dns_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _hostController = TextEditingController();

  void _addHost() {
    final host = _hostController.text.trim();
    if (host.isNotEmpty) {
      final id = 'ping_${DateTime.now().millisecondsSinceEpoch}';
      context.read<PingProvider>().addHost(id, host);
      context.read<DashboardProvider>().addItem(DashboardItemType.ping, value: id);
      _hostController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  void _showAddHostDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        title: const Text(
          'Add Host to Monitor',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _hostController,
                autofocus: true,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'e.g. 192.168.1.1 or google.com',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  _addHost();
                  Navigator.pop(context);
                },
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
              _addHost();
              Navigator.pop(context);
            },
            child: const Text(
              'ADD',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showBackupRestoreDialog(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final importCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        title: const Text(
          'Backup & Restore',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Export your settings:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await settings.exportToClipboard();
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard!')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text(
                        'CLIPBOARD',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await settings.exportToFile();
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.file_upload, size: 16),
                      label: const Text('FILE', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              const Text(
                'Import from file:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    bool ok = await settings.importFromFile();
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    if (ok) {
                      if (context.mounted) {
                        context.read<PingProvider>().reloadHosts();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Backup restored successfully!'),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.file_download),
                  label: const Text('CHOOSE BACKUP FILE'),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Or paste JSON string:',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: importCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '{...}',
                ),
                style: const TextStyle(fontSize: 9, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (importCtrl.text.isEmpty) return;
              bool ok = await settings.importFromString(importCtrl.text);
              if (!context.mounted) return;
              Navigator.pop(context);
              if (ok) {
                context.read<PingProvider>().reloadHosts();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Backup restored successfully!'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid data!'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('IMPORT TEXT'),
          ),
        ],
      ),
    );
  }

  void _showAppSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        title: const Text(
          'App Settings',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content:
            Consumer6<
              PingProvider,
              WifiProvider,
              SpeedTestProvider,
              PortScannerProvider,
              IPScannerProvider,
              WeatherProvider
            >(
              builder: (context, ping, wifi, speed, port, ip, weather, child) =>
                  SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SwitchListTile(
                          dense: true,
                          title: const Text(
                            'Global Demo Mode',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.orangeAccent,
                            ),
                          ),
                          value: ping.isDemoMode,
                          onChanged: (v) {
                            ping.setDemoMode(v);
                            wifi.setDemoMode(v);
                            speed.setDemoMode(v);
                            port.setDemoMode(v);
                            ip.setDemoMode(v);
                            weather.setDemoMode(v);
                          },
                        ),
                      ],
                    ),
                  ),
            ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshAll() async {
    final wifi = context.read<WifiProvider>();
    final weather = context.read<WeatherProvider>();
    await Future.wait([
      wifi.updateWifiDetails(),
      weather.fetchWeather(),
    ]);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data refreshed'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        toolbarHeight: 48,
        title: const Text(
          'NetPulse',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          Consumer<DashboardProvider>(
            builder: (context, provider, _) => IconButton(
              icon: Icon(
                provider.isReorderEnabled ? Icons.check : Icons.reorder,
                color: provider.isReorderEnabled ? Colors.greenAccent : null,
              ),
              onPressed: () => provider.toggleReorder(),
              tooltip: provider.isReorderEnabled
                  ? 'Save Order'
                  : 'Enable Reordering',
            ),
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.settings_outlined),
            onSelected: (value) {
              if (value == 0) {
                _showBackupRestoreDialog(context);
              } else if (value == 1) {
                _showAppSettingsDialog(context);
              } else if (value == 2) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LogPage()),
                );
              } else if (value == 3) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutPage()),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 0,
                child: Row(
                  children: [
                    Icon(Icons.backup_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Backup & Restore'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 1,
                child: Row(
                  children: [
                    Icon(Icons.tune, size: 20),
                    SizedBox(width: 12),
                    Text('App Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 2,
                child: Row(
                  children: [
                    Icon(Icons.list_alt_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Internal Logs'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 3,
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20),
                    SizedBox(width: 12),
                    Text('About'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: Consumer2<DashboardProvider, PingProvider>(
            builder: (context, dashboard, pingProvider, child) {
              final items = dashboard.items;
              final isReorder = dashboard.isReorderEnabled;

              return ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 70),
                itemCount: items.length,
                buildDefaultDragHandles: false,
                onReorder: (oldIndex, newIndex) {
                  dashboard.reorderItems(oldIndex, newIndex);
                },
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      return Material(
                        elevation: 8,
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: child,
                      );
                    },
                    child: child,
                  );
                },
                itemBuilder: (context, index) {
                  final item = items[index];

                  Widget card;
                  final String stableId = item.value ?? item.type.name;

                  switch (item.type) {
                    case DashboardItemType.wifi:
                      card = const WifiInfoCard();
                      break;
                    case DashboardItemType.mikrotik:
                      final cfgKey = item.value ?? 'default';
                      card = MikrotikCard(
                        uniqueKey: cfgKey,
                        configKey: cfgKey,
                        onDelete: () => dashboard.removeItem(index),
                      );
                      break;
                    case DashboardItemType.speedtest:
                      card = const SpeedTestCard();
                      break;
                    case DashboardItemType.ping:
                      final hostId = item.value;
                      if (hostId == null) {
                        return SizedBox(key: ValueKey('ping_error_$index'));
                      }
                      final result = pingProvider.getResult(hostId);
                      if (result == null) {
                        return SizedBox(key: ValueKey('ping_missing_$hostId'));
                      }
                      card = PingCard(item: result);
                      break;
                    case DashboardItemType.portScanner:
                      card = const PortScannerCard();
                      break;
                    case DashboardItemType.ipScanner:
                      card = const IPScannerCard();
                      break;
                    case DashboardItemType.weather:
                      card = const WeatherCard();
                      break;
                    case DashboardItemType.traceroute:
                      card = const TracerouteCard();
                      break;
                    case DashboardItemType.ipInfo:
                      card = const IpInfoCard();
                      break;
                    case DashboardItemType.mdns:
                      card = const MdnsCard();
                      break;
                    case DashboardItemType.dns:
                      card = const DnsCard();
                      break;
                  }

                  // Root of the item MUST have the stable key
                  final bool isMikrotik =
                      item.type == DashboardItemType.mikrotik;

                  return Dismissible(
                    key: ValueKey('dismiss_$stableId'),
                    direction: isReorder
                        ? DismissDirection.none
                        : (item.type == DashboardItemType.ping ||
                                item.type == DashboardItemType.weather || isMikrotik
                              ? DismissDirection.horizontal
                              : DismissDirection.endToStart),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        final val = item.value;
                        if (item.type == DashboardItemType.ping &&
                            val != null) {
                          pingProvider.toggleHost(val);
                        } else if (item.type == DashboardItemType.weather) {
                          context.read<WeatherProvider>().fetchWeather();
                          return false;
                        } else if (isMikrotik) {
                          final instance = context
                              .read<MikrotikProvider>()
                              .getInstance(val ?? 'default');
                          if (instance.isConnected) {
                            instance.disconnect();
                          } else {
                            if (instance.config.isDemoMode) {
                              instance.startDemoMode();
                            } else {
                              instance.connect();
                            }
                          }
                        }
                        return false;
                      }
                      return true;
                    },
                    onDismissed: (_) {
                      final val = item.value;
                      if (item.type == DashboardItemType.ping && val != null) {
                        pingProvider.removeHost(val);
                        dashboard.removeItem(index);
                      } else {
                        dashboard.removeItem(index);
                      }
                    },
                    background: (item.type == DashboardItemType.ping && item.value != null) ||
                        (item.type == DashboardItemType.weather) ||
                        (isMikrotik && item.value != null)
                        ? Builder(builder: (context) {
                            bool isActive = false;
                            IconData icon = Icons.play_arrow;
                            Color color = Colors.blueAccent;

                            if (item.type == DashboardItemType.ping) {
                              isActive = !(pingProvider.getResult(item.value!)?.isPaused ?? false);
                              icon = isActive ? Icons.pause : Icons.play_arrow;
                            } else if (item.type == DashboardItemType.weather) {
                              icon = Icons.refresh;
                              color = Colors.blueAccent;
                            } else if (isMikrotik) {
                              final instance = context
                                  .read<MikrotikProvider>()
                                  .getInstance(item.value ?? 'default');
                              isActive = instance.isConnected;
                              icon = isActive ? Icons.link_off : Icons.link;
                              color = Colors.orangeAccent;
                            }

                            return Container(
                              color: color,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 20),
                              child: Icon(icon, size: 24, color: Colors.white),
                            );
                          })
                        : Container(
                            color: Colors.redAccent,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete_outline, size: 24, color: Colors.white),
                          ),
                    secondaryBackground: Container(
                      color: Colors.redAccent,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete_outline, size: 24, color: Colors.white),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey('subtree_$stableId'),
                      child: ReorderableDragStartListener(
                        index: index,
                        enabled: isReorder,
                        child: card,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => _showAddCardMenu(context),
        child: const Icon(Icons.add, size: 24),
      ),
    );
  }

  void _showAddCardMenu(BuildContext context) {
    final dashboard = context.read<DashboardProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Add Card',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.wifi),
                        title: const Text('WiFi Info'),
                        enabled: !dashboard.items.any(
                          (i) => i.type == DashboardItemType.wifi,
                        ),
                        onTap: () {
                          dashboard.addItem(DashboardItemType.wifi);
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.router),
                        title: const Text('MikroTik'),
                        onTap: () {
                          dashboard.addItem(DashboardItemType.mikrotik);
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.speed),
                        title: const Text('Speed Test'),
                        enabled: !dashboard.items.any(
                          (i) => i.type == DashboardItemType.speedtest,
                        ),
                        onTap: () {
                          dashboard.addItem(DashboardItemType.speedtest);
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.network_ping),
                        title: const Text('Ping Host'),
                        onTap: () {
                          Navigator.pop(context);
                          _showAddHostDialog(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.search),
                        title: const Text('Port Scanner'),
                        enabled: !dashboard.items.any(
                          (i) => i.type == DashboardItemType.portScanner,
                        ),
                        onTap: () {
                          dashboard.addItem(DashboardItemType.portScanner);
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.settings_remote),
                        title: const Text('IP Scanner'),
                        enabled: !dashboard.items.any(
                          (i) => i.type == DashboardItemType.ipScanner,
                        ),
                        onTap: () {
                          dashboard.addItem(DashboardItemType.ipScanner);
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.wb_sunny_outlined),
                        title: const Text('Weather Info'),
                        enabled: !dashboard.items.any(
                          (i) => i.type == DashboardItemType.weather,
                        ),
                        onTap: () {
                          dashboard.addItem(DashboardItemType.weather);
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.alt_route),
                        title: const Text('Traceroute'),
                        enabled: !dashboard.items.any(
                          (i) => i.type == DashboardItemType.traceroute,
                        ),
                        onTap: () {
                          dashboard.addItem(DashboardItemType.traceroute);
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('Public IP & ISP'),
                        enabled: !dashboard.items.any(
                          (i) => i.type == DashboardItemType.ipInfo,
                        ),
                        onTap: () {
                          dashboard.addItem(DashboardItemType.ipInfo);
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.radar),
                        title: const Text('mDNS / Bonjour'),
                        enabled: !dashboard.items.any(
                          (i) => i.type == DashboardItemType.mdns,
                        ),
                        onTap: () {
                          dashboard.addItem(DashboardItemType.mdns);
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.dns),
                        title: const Text('DNS Lookup / WHOIS'),
                        enabled: !dashboard.items.any(
                          (i) => i.type == DashboardItemType.dns,
                        ),
                        onTap: () {
                          dashboard.addItem(DashboardItemType.dns);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
