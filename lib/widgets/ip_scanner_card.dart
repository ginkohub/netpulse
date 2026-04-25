import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/ip_scanner_service.dart';
import '../services/port_scanner_service.dart';
import 'base_card.dart';

class IPScannerCard extends StatefulWidget {
  const IPScannerCard({super.key});

  @override
  State<IPScannerCard> createState() => _IPScannerCardState();
}

class _IPScannerCardState extends State<IPScannerCard> {
  final TextEditingController _startIpController = TextEditingController();
  final TextEditingController _endIpController = TextEditingController();
  bool _isStartValid = true;
  bool _isEndValid = true;
  bool _isRangeValid = true;

  @override
  void initState() {
    super.initState();
    _initSubnet();
  }

  Future<void> _initSubnet() async {
    final provider = context.read<IPScannerProvider>();

    if (provider.lastStartIp.isNotEmpty) {
      _startIpController.text = provider.lastStartIp;
    } else {
      _startIpController.text = '192.168.1.1';
    }

    if (provider.lastEndIp.isNotEmpty) {
      _endIpController.text = provider.lastEndIp;
    } else {
      _endIpController.text = '192.168.1.254';
    }

    _validateIPs();
  }

  bool _isValidIPv4(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    final parts = trimmed.split('.');
    if (parts.length != 4) return false;
    for (var part in parts) {
      final val = int.tryParse(part);
      if (val == null || val < 0 || val > 255) return false;
    }
    return true;
  }

  void _validateIPs() {
    setState(() {
      final startText = _startIpController.text.trim();
      final endText = _endIpController.text.trim();

      _isStartValid = _isValidIPv4(startText);
      _isEndValid = _isValidIPv4(endText);

      if (_isStartValid && _isEndValid) {
        final start = IPScannerProvider.ipToInt(startText);
        final end = IPScannerProvider.ipToInt(endText);
        _isRangeValid = start <= end;
      } else {
        _isRangeValid = true;
      }
    });
  }

  @override
  void dispose() {
    _startIpController.dispose();
    _endIpController.dispose();
    super.dispose();
  }

  void _startScan(IPScannerProvider provider) {
    if (!_isStartValid || !_isEndValid || !_isRangeValid) return;

    final start = IPScannerProvider.ipToInt(_startIpController.text.trim());
    final end = IPScannerProvider.ipToInt(_endIpController.text.trim());

    if (start == 0 || end == 0) return;
    provider.scanFullRange(start, end);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<IPScannerProvider>(
      builder: (context, provider, child) {
        final isScanning = provider.isScanning;
        final bool canScan = _isStartValid && _isEndValid && _isRangeValid;

        String subtitle = 'Scan a range of IP addresses';
        int totalIps = 0;
        if (_isStartValid && _isEndValid && _isRangeValid) {
          totalIps =
              IPScannerProvider.ipToInt(_endIpController.text.trim()) -
              IPScannerProvider.ipToInt(_startIpController.text.trim()) +
              1;
        }

        if (isScanning) {
          subtitle =
              'Scanning ${provider.currentIp} (${(provider.progress * 100).toStringAsFixed(0)}%)';
        } else if (!_isRangeValid) {
          subtitle = 'Error: Start IP must be less than End IP';
        } else if (provider.discoveredHosts.isNotEmpty) {
          subtitle =
              'Found ${provider.discoveredHosts.length} devices in $totalIps IPs';
        } else if (totalIps > 0) {
          subtitle = 'Range: $totalIps IPs available to scan';
        }

        return BaseCard(
          title: 'IP Scanner',
          subtitle: subtitle,
          subtitleColor: !_isRangeValid ? Colors.redAccent : null,
          leading: Icon(
            Icons.settings_remote,
            color: isScanning ? Colors.blueAccent : Colors.grey,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _startIpController,
                          enabled: !isScanning,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Start IP',
                            hintText: '192.168.1.1',
                            isDense: true,
                            errorText: _isStartValid ? null : 'Invalid',
                            errorStyle: const TextStyle(fontSize: 10),
                          ),
                          style: const TextStyle(fontSize: 13),
                          onChanged: (_) => _validateIPs(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _endIpController,
                          enabled: !isScanning,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: 'End IP',
                            hintText: '192.168.1.254',
                            isDense: true,
                            errorText: _isEndValid ? null : 'Invalid',
                            errorStyle: const TextStyle(fontSize: 10),
                          ),
                          style: const TextStyle(fontSize: 13),
                          onChanged: (_) => _validateIPs(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (totalIps > 0 && !isScanning)
                        Text(
                          '$totalIps IPs in range',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else if (isScanning)
                        Text(
                          '${provider.scannedCount} / ${provider.totalCount} scanned',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else
                        const SizedBox(),
                      Row(
                        children: [
                          if (provider.discoveredHosts.isNotEmpty &&
                              !isScanning)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: TextButton(
                                onPressed: provider.clearResults,
                                child: const Text(
                                  'CLEAR',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ElevatedButton(
                            onPressed: isScanning
                                ? provider.stopScan
                                : (canScan ? () => _startScan(provider) : null),
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
                  const SizedBox(height: 8),
                  if (isScanning)
                    LinearProgressIndicator(
                      value: provider.progress,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.blueAccent,
                      ),
                    ),
                  if (provider.discoveredHosts.isNotEmpty) ...[
                    const Divider(),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Active Devices:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: SingleChildScrollView(
                        child: Column(
                          children: provider.discoveredHosts.map((host) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                top: 2,
                                bottom: 2,
                                right: 18,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.devices,
                                    size: 14,
                                    color: Colors.greenAccent,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    host.ip,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  if (host.hostname != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${host.hostname})',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.copy,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Copy IP',
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: host.ip),
                                      ).then((_) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'IP ${host.ip} copied',
                                              ),
                                              duration: const Duration(
                                                seconds: 1,
                                              ),
                                            ),
                                          );
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.search,
                                      size: 14,
                                      color: Colors.blueAccent,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Scan Ports',
                                    onPressed: () {
                                      context
                                          .read<PortScannerProvider>()
                                          .prefillHost(host.ip);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'IP ${host.ip} set in Port Scanner',
                                          ),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
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
