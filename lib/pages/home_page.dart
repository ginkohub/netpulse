import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ping_service.dart';
import '../services/wifi_service.dart';
import '../services/settings_service.dart';
import '../services/speedtest_service.dart';
import 'log_page.dart';
import 'about_page.dart';
import '../widgets/wifi_info_card.dart';
import '../widgets/mikrotik_card.dart';
import '../widgets/speed_test_card.dart';
import '../widgets/ping_card.dart';

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
      context.read<PingProvider>().addHost(host);
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
        content: TextField(
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
        content: Consumer3<PingProvider, WifiProvider, SpeedTestProvider>(
          builder: (context, ping, wifi, speed, child) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  dense: true,
                  title: const Text('Global Demo Mode',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.orangeAccent)),
                  value: ping.isDemoMode,
                  onChanged: (v) {
                    ping.setDemoMode(v);
                    wifi.setDemoMode(v);
                    speed.setDemoMode(v);
                  },
                ),
                const Divider(),
                const Text(
                  'WiFi Settings',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                ListTile(
                  dense: true,
                  title: const Text('Refresh Interval',
                      style: TextStyle(fontSize: 13)),
                  trailing: DropdownButton<int>(
                    value: wifi.refreshInterval,
                    items: [5, 10, 30, 60, 300]
                        .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text('${e}s',
                                style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) wifi.setRefreshInterval(v);
                    },
                  ),
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
    await wifi.updateWifiDetails();

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
          Consumer<PingProvider>(
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
          child: Consumer<PingProvider>(
            builder: (context, provider, child) {
              final items = provider.items;
              final isReorder = provider.isReorderEnabled;

              return ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 70),
                itemCount: items.length,
                buildDefaultDragHandles: false,
                onReorder: (oldIndex, newIndex) {
                  provider.reorderItems(oldIndex, newIndex);
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
                  String itemKey;

                  switch (item.type) {
                    case DashboardItemType.wifi:
                      itemKey = 'wifi_$index';
                      card = const WifiInfoCard();
                      break;
                    case DashboardItemType.mikrotik:
                      itemKey = 'mikrotik_${item.value ?? index}';
                      final cfgKey = item.value ?? '$index';
                      card = MikrotikCard(
                        uniqueKey: cfgKey,
                        configKey: cfgKey,
                        onDelete: () => provider.removeItem(
                          item.type,
                          value: item.value,
                          index: index,
                        ),
                      );
                      break;
                    case DashboardItemType.speedtest:
                      itemKey = 'speedtest_$index';
                      card = const SpeedTestCard();
                      break;
                    case DashboardItemType.ping:
                      final host = item.value;
                      if (host == null) {
                        return SizedBox(key: ValueKey('ping_error_$index'));
                      }
                      itemKey = 'ping_${host}_$index';
                      final result = provider.getResult(host);
                      if (result == null) {
                        return SizedBox(key: ValueKey(itemKey));
                      }
                      card = PingCard(item: result);
                      break;
                  }

                  // Root of the item MUST have the stable key
                  final bool isMikrotik =
                      item.type == DashboardItemType.mikrotik;
                  if (isMikrotik) {
                    return KeyedSubtree(
                      key: ValueKey('${item.type.name}_${item.value ?? index}'),
                      child: ReorderableDragStartListener(
                        index: index,
                        enabled: isReorder,
                        child: card,
                      ),
                    );
                  }
                  return Dismissible(
                    key: ValueKey(
                      'dismiss_${item.type.name}_${item.value ?? index}',
                    ),
                    direction: isReorder
                        ? DismissDirection.none
                        : (item.type == DashboardItemType.ping
                            ? DismissDirection.horizontal
                            : DismissDirection.endToStart),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        final val = item.value;
                        if (item.type == DashboardItemType.ping && val != null) {
                          provider.toggleHost(val);
                        }
                        return false;
                      }
                      return true;
                    },
                    onDismissed: (_) {
                      final val = item.value;
                      if (item.type == DashboardItemType.ping && val != null) {
                        provider.removeHost(val);
                      } else {
                        provider.removeItem(
                          item.type,
                          value: val,
                          index: index,
                        );
                      }
                    },
                    background: item.type == DashboardItemType.ping && item.value != null
                        ? Container(
                            color: Colors.blueAccent,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            child: Icon(
                              provider.getResult(item.value!)?.isPaused ?? false
                                  ? Icons.play_arrow
                                  : Icons.pause,
                              size: 24,
                            ),
                          )
                        : Container(
                            color: Colors.redAccent,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete, size: 24),
                          ),
                    secondaryBackground: item.type == DashboardItemType.ping &&
                            item.value != null
                        ? Container(
                            color: Colors.redAccent,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete, size: 24),
                          )
                        : null,
                    child: KeyedSubtree(
                      key: ValueKey('${item.type.name}_${item.value ?? index}'),
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
    final provider = context.read<PingProvider>();
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
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
            ListTile(
              leading: const Icon(Icons.wifi),
              title: const Text('WiFi Info'),
              enabled: !provider.items.any(
                (i) => i.type == DashboardItemType.wifi,
              ),
              onTap: () {
                provider.addItem(DashboardItemType.wifi);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.router),
              title: const Text('MikroTik'),
              onTap: () {
                final newKey =
                    'mikrotik_${DateTime.now().millisecondsSinceEpoch}';
                provider.addItem(DashboardItemType.mikrotik, value: newKey);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.speed),
              title: const Text('Speed Test'),
              enabled: !provider.items.any(
                (i) => i.type == DashboardItemType.speedtest,
              ),
              onTap: () {
                provider.addItem(DashboardItemType.speedtest);
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
