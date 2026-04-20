import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ping_service.dart';

class PingCard extends StatelessWidget {
  final PingResultModel item;
  const PingCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    Color statusColor = item.isPaused
        ? Colors.orange
        : (item.isOnline
            ? Colors.greenAccent
            : (item.error != null ? Colors.redAccent : Colors.grey));
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => context.read<PingProvider>().toggleHost(item.host),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.isPaused ? Icons.pause : Icons.sensors,
                  color: statusColor,
                  size: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.host,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    item.isPaused
                        ? 'Paused'
                        : (item.error ??
                            (item.isOnline ? 'Online' : 'Offline')),
                    style: TextStyle(
                      fontSize: 9,
                      color: item.isPaused
                          ? Colors.orange
                          : (item.isOnline
                              ? Colors.green.shade200
                              : Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => context.read<PingProvider>().toggleHost(item.host),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.latency != null ? '${item.latency}' : '--',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Text(
                      'ms',
                      style:
                          TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
