import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/traceroute_service.dart';
import 'base_card.dart';

class TracerouteCard extends StatefulWidget {
  const TracerouteCard({super.key});

  @override
  State<TracerouteCard> createState() => _TracerouteCardState();
}

class _TracerouteCardState extends State<TracerouteCard> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TracerouteProvider>(
      builder: (context, provider, child) {
        final isTracing = provider.isTracing;
        final hops = provider.hops;

        return BaseCard(
          key: ValueKey('traceroute_card_${isTracing || hops.isNotEmpty}'),
          leading: const Icon(Icons.alt_route, color: Colors.purpleAccent),
          title: 'Traceroute',
          subtitle: provider.target ?? 'Analyze network path',
          initiallyExpanded: isTracing || hops.isNotEmpty,
          trailing: isTracing
              ? IconButton(
                  icon: const Icon(Icons.stop, color: Colors.redAccent),
                  onPressed: () => provider.stopTrace(),
                )
              : IconButton(
                  icon: const Icon(Icons.play_arrow, color: Colors.greenAccent),
                  onPressed: () => _showStartDialog(context, provider),
                ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  if (isTracing)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: LinearProgressIndicator(
                        value: provider.progress,
                        backgroundColor: Colors.purpleAccent.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.purpleAccent,
                        ),
                      ),
                    ),
                  if (hops.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Text(
                        'No hops to display. Start a trace.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    )
                  else
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        child: Table(
                          columnWidths: const {
                            0: FixedColumnWidth(30),
                            1: FlexColumnWidth(),
                            2: FixedColumnWidth(70),
                          },
                          children: [
                            TableRow(
                              children: [
                                _buildHeader('Hop'),
                                _buildHeader('Host / IP'),
                                _buildHeader('Time'),
                              ],
                            ),
                            ...hops.map(
                              (hop) => TableRow(
                                children: [
                                  _buildCell(hop.hop.toString(), isBold: true),
                                  _buildCell(hop.host, isMonospace: true),
                                  _buildCell(
                                    hop.time > 0
                                        ? '${hop.time.toStringAsFixed(1)}ms'
                                        : '*',
                                    color: hop.time > 0
                                        ? Colors.blueAccent
                                        : Colors.redAccent,
                                    align: TextAlign.right,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildCell(
    String value, {
    bool isBold = false,
    bool isMonospace = false,
    Color? color,
    TextAlign align = TextAlign.left,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Text(
        value,
        textAlign: align,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontFamily: isMonospace ? 'monospace' : null,
          color: color,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _showStartDialog(BuildContext context, TracerouteProvider provider) {
    _controller.text = provider.lastInput ?? '';
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Traceroute', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: _controller,
          decoration: const InputDecoration(
            hintText: 'e.g. google.com or 8.8.8.8',
            isDense: true,
          ),
          autofocus: true,
          onSubmitted: (_) => _startTrace(provider),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => _startTrace(provider),
            child: const Text('START'),
          ),
        ],
      ),
    );
  }

  void _startTrace(TracerouteProvider provider) {
    final host = _controller.text.trim();
    if (host.isNotEmpty) {
      provider.setLastInput(host);
      provider.startTrace(host);
    }
    Navigator.pop(context);
  }
}
