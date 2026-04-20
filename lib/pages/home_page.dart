import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ping_service.dart';
import '../wifi_service.dart';
import '../mikrotik_service.dart';
import '../settings_service.dart';
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
        title: const Text('Add Host to Monitor'),
        content: TextField(
          controller: _hostController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. 192.168.1.1 or google.com',
            labelText: 'IP Address / Domain',
          ),
          onSubmitted: (_) {
            _addHost();
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              _addHost();
              Navigator.pop(context);
            },
            child: const Text('ADD'),
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
        title: const Text('Backup & Restore'),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Settings restored! Please restart.'),
                        ),
                      );
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings restored! Please restart.'),
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

  Future<void> _refreshAll() async {
    final wifi = context.read<WifiProvider>();
    final mk = context.read<MikrotikProvider>();
    
    await Future.wait([
      wifi.updateWifiDetails(),
      if (mk.isConnected) mk.fetchUpdates(),
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
        title: const Text(
          'NetPulse',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.backup_outlined),
          onPressed: () => _showBackupRestoreDialog(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.list_alt_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LogPage()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: Consumer2<PingProvider, WifiProvider>(
            builder: (context, provider, wifi, child) {
              final results = provider.results;
              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 70),
                itemCount: results.length + 3,
                itemBuilder: (context, index) {
                  if (index == 0) return const WifiInfoCard();
                  if (index == 1) return const MikrotikCard();
                  if (index == 2) return const SpeedTestCard();

                  final item = results[index - 3];
                  return Dismissible(
                    key: ValueKey(item.host),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.redAccent,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, size: 24),
                    ),
                    onDismissed: (_) => provider.removeHost(item.host),
                    child: PingCard(item: item),
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => _showAddHostDialog(context),
        child: const Icon(Icons.add, size: 24),
      ),
    );
  }
}
