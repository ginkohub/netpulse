import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
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
      title: item.name != null && item.name!.isNotEmpty ? item.name : item.host,
      subtitle: item.isPaused
          ? 'Paused'
          : (isOnline ? 'Online' : (item.error ?? 'Offline')),
      subtitleColor: statusColor.withAlpha(200),
      leading: Icon(Icons.radar, size: 24, color: statusColor),
      onTap: () => provider.toggleHost(item.id),
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
                    style: const TextStyle(
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
      children: [
        if (item.history.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStats(item),
                const SizedBox(height: 12),
                const Text(
                  'Latency Trend (ms)',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 100,
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (touchedSpot) =>
                              Colors.blueGrey.withAlpha(200),
                          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                            return touchedBarSpots.map((barSpot) {
                              if (barSpot.y == 0) {
                                return const LineTooltipItem(
                                  'TIMEOUT',
                                  TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                );
                              }
                              return LineTooltipItem(
                                '${barSpot.y.toInt()} ms',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      gridData: const FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 50,
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 100,
                            getTitlesWidget: _leftTitleWidgets,
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          bottom: BorderSide(color: Colors.white10),
                          left: BorderSide(color: Colors.white10),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: item.history
                              .asMap()
                              .entries
                              .map(
                                (e) => FlSpot(
                                  e.key.toDouble(),
                                  e.value.toDouble(),
                                ),
                              )
                              .toList(),
                          isCurved: true,
                          gradient: const LinearGradient(
                            colors: [
                              Colors.greenAccent,
                              Colors.yellowAccent,
                              Colors.orangeAccent,
                              Colors.redAccent,
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
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
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta) {
    return SideTitleWidget(
      meta: meta,
      space: 4,
      child: Text(
        value.toInt().toString(),
        style: const TextStyle(fontSize: 8, color: Colors.grey),
      ),
    );
  }

  Widget _buildStats(PingResultModel item) {
    final validPings = item.history.where((l) => l > 0).toList();
    final lossCount = item.history.where((l) => l == 0).length;
    final lossPercent = (lossCount / item.history.length * 100).toStringAsFixed(
      0,
    );
    final avg = validPings.isEmpty
        ? 0
        : (validPings.reduce((a, b) => a + b) / validPings.length).round();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _statItem(
          'Packet Loss',
          '$lossPercent%',
          lossCount > 0 ? Colors.redAccent : Colors.grey,
        ),
        _statItem('Average', '${avg}ms', Colors.grey),
        _statItem('Samples', '${item.history.length}', Colors.grey),
      ],
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, PingProvider provider) {
    final ctrlHost = TextEditingController(text: item.host);
    final ctrlName = TextEditingController(text: item.name);
    int selectedInterval = item.interval;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          void onSave() {
            final newName = ctrlName.text.trim();
            final newHost = ctrlHost.text.trim().toLowerCase();

            if (newHost.isEmpty) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                  const SnackBar(content: Text('Host cannot be empty')));
              return;
            }

            if (newName != item.name ||
                newHost != item.host ||
                selectedInterval != item.interval) {
              provider.updatePing(item.id,
                  host: newHost, name: newName, interval: selectedInterval);
            }
            Navigator.pop(context);
          }

          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            title: const Text(
              'Edit Ping',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: ctrlName,
                  autofocus: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Optional',
                    labelText: 'Name',
                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                    border: UnderlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: ctrlHost,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Host',
                    hintText: 'google.com',
                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                    border: UnderlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Ping Interval:',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                    DropdownButton<int>(
                      value: selectedInterval,
                      isDense: true,
                      underline: const SizedBox(),
                      items: [1, 2, 5, 10, 30, 60]
                          .map((v) => DropdownMenuItem(
                                value: v,
                                child: Text('${v}s',
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => selectedInterval = v);
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL', style: TextStyle(fontSize: 13)),
              ),
              TextButton(
                onPressed: onSave,
                child: const Text(
                  'SAVE',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
