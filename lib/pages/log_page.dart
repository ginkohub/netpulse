import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/log_service.dart';

class LogPage extends StatelessWidget {
  const LogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        title: const Text(
          'Application Logs',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => context.read<LogProvider>().clearLogs(),
          ),
        ],
      ),
      body: Consumer<LogProvider>(
        builder: (context, logger, child) {
          if (logger.logs.isEmpty) {
            return const Center(child: Text('No logs yet.'));
          }
          return ListView.builder(
            itemCount: logger.logs.length,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            itemBuilder: (context, index) {
              final log = logger.logs[index];
              Color color = Colors.white70;
              if (log.level == 'ERROR') color = Colors.redAccent;
              if (log.level == 'WARN') color = Colors.orangeAccent;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 1.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('HH:mm:ss').format(log.timestamp),
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.grey,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '[${log.level}] ${log.message}',
                        style: TextStyle(
                          fontSize: 9,
                          color: color,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
