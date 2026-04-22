import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ping_service.dart';
import 'base_card.dart';

class PingCard extends StatelessWidget {
  final PingResultModel item;
  const PingCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PingProvider>();
    final isOnline = item.isOnline && !item.isPaused;
    final Color statusColor = item.isPaused
        ? Colors.grey
        : (isOnline
              ? switch (item.latency) {
                  int v when v > 25 => Colors.yellowAccent,
                  int v when v > 50 => Colors.amberAccent,
                  int v when v > 100 => Colors.orangeAccent,
                  int v when v > 1000 => Colors.red,
                  _ => Colors.greenAccent,
                }
              : Colors.redAccent);

    return BaseCard(
      title: item.host,
      subtitle: item.isPaused
          ? 'Paused'
          : (isOnline ? 'Online' : (item.error ?? 'Offline')),
      subtitleColor: statusColor.withAlpha(200),
      leading: Icon(Icons.radar, size: 24, color: statusColor),
      onTap: () => provider.toggleHost(item.host),
      onDoubleTap: () => _showEditDialog(context, provider),
      trailing: item.isPaused
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withAlpha(40)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.latency != null ? '${item.latency}' : '--',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'ms',
                    style: TextStyle(
                      fontSize: 9,
                      color: statusColor.withAlpha(150),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showEditDialog(BuildContext context, PingProvider provider) {
    final ctrl = TextEditingController(text: item.host);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Edit Host Target',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            isDense: true,
            labelText: 'IP / Domain',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.updateHost(item.host, ctrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }
}
