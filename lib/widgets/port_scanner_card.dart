import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/port_scanner_service.dart';
import 'base_card.dart';

class PortScannerCard extends StatefulWidget {
  const PortScannerCard({super.key});

  @override
  State<PortScannerCard> createState() => _PortScannerCardState();
}

class _PortScannerCardState extends State<PortScannerCard> {
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _startPortController = TextEditingController();
  final TextEditingController _endPortController = TextEditingController();

  @override
  void initState() {
    super.initState();

    final provider = context.read<PortScannerProvider>();

    _hostController.text = provider.lastHost.isNotEmpty
        ? provider.lastHost
        : '192.168.1.1';
    _startPortController.text = provider.lastStartPort.toString();
    _endPortController.text = provider.lastEndPort.toString();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.prefilledHost.isNotEmpty) {
        _hostController.text = provider.prefilledHost;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host = context.watch<PortScannerProvider>().prefilledHost;
    if (host.isNotEmpty && host != _hostController.text) {
      _hostController.text = host;
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _startPortController.dispose();
    _endPortController.dispose();
    super.dispose();
  }

  void _startScan(PortScannerProvider provider) {
    final host = _hostController.text.trim();
    final start = int.tryParse(_startPortController.text) ?? 1;
    final end = int.tryParse(_endPortController.text) ?? 1024;

    if (host.isEmpty) return;

    provider.scanRange(host, start, end);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PortScannerProvider>(
      builder: (context, provider, child) {
        final isScanning = provider.isScanning;

        return BaseCard(
          title: 'Port Scanner',
          subtitle: isScanning
              ? 'Scanning... (${(provider.progress * 100).toStringAsFixed(0)}%)'
              : 'Scan a range of ports',
          leading: Icon(
            Icons.search,
            color: isScanning ? Colors.blueAccent : Colors.grey,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _hostController,
                          enabled: !isScanning,
                          decoration: const InputDecoration(
                            labelText: 'Host',
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _startPortController,
                          enabled: !isScanning,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Start',
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _endPortController,
                          enabled: !isScanning,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'End',
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isScanning)
                    LinearProgressIndicator(
                      value: provider.progress,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.blueAccent,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isScanning
                            ? 'Port: ${provider.currentPort}'
                            : 'Found: ${provider.openPorts.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Row(
                        children: [
                          if (provider.openPorts.isNotEmpty && !isScanning)
                            TextButton(
                              onPressed: provider.clearResults,
                              child: const Text(
                                'CLEAR',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ElevatedButton(
                            onPressed: isScanning
                                ? provider.stopScan
                                : () => _startScan(provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isScanning
                                  ? Colors.redAccent.withAlpha(50)
                                  : null,
                            ),
                            child: Text(
                              isScanning ? 'STOP' : 'SCAN',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isScanning ? Colors.redAccent : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (provider.openPorts.isNotEmpty) ...[
                    const Divider(),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Open Ports:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.greenAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: provider.openPorts
                          .map(
                            (p) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withAlpha(20),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.greenAccent.withAlpha(50),
                                ),
                              ),
                              child: Text(
                                p.service != null
                                    ? '${p.port} (${p.service})'
                                    : '${p.port}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.greenAccent,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
