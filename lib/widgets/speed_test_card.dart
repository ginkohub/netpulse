import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../speedtest_service.dart';
import '../history_service.dart';

class SpeedTestCard extends StatelessWidget {
  const SpeedTestCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SpeedTestProvider, HistoryProvider>(
      builder: (context, st, history, child) {
        return Card(
          margin: const EdgeInsets.fromLTRB(8, 2, 8, 2),
          elevation: 2,
          child: ExpansionTile(
            collapsedBackgroundColor: Colors.transparent,
            leading: const Icon(
              Icons.speed,
              color: Colors.blueAccent,
              size: 18,
            ),
            tilePadding: const EdgeInsets.fromLTRB(10, 0, 8, 0),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  st.serverName,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _stat('DN', st.downloadSpeed, Colors.greenAccent),
                    const SizedBox(width: 8),
                    _stat('UP', st.uploadSpeed, Colors.blueAccent),
                  ],
                ),
                Row(
                  children: [
                    _smallStat(
                      'LT',
                      st.latency.toDouble(),
                      Colors.orangeAccent,
                    ),
                    const SizedBox(width: 8),
                    _smallStat('JT', st.jitter.toDouble(), Colors.purpleAccent),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<int>(
                  icon: st.isRefreshing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.dns, size: 14),
                  tooltip: 'Select Server',
                  itemBuilder: (context) {
                    final servers = [...st.availableServers]
                      ..sort((a, b) => a.latency.compareTo(b.latency));
                    return [
                      const PopupMenuItem(
                        value: -1,
                        child: Text(
                          'Auto',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const PopupMenuDivider(),
                      ...servers
                          .take(20)
                          .toList()
                          .asMap()
                          .entries
                          .map(
                            (e) => PopupMenuItem(
                              value: e.key,
                              child: Text(
                                '${e.value.name} (${e.value.latency < 9999 ? '${e.value.latency}ms' : '?'})',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                    ];
                  },
                  onSelected: (value) {
                    if (value == -1) {
                      st.selectServer(null);
                      st.findBestServer();
                    } else {
                      final servers = [...st.availableServers]
                        ..sort((a, b) => a.latency.compareTo(b.latency));
                      st.selectServer(servers[value]);
                    }
                  },
                ),
                IconButton.filledTonal(
                  onPressed: () {
                    if (st.isActive) {
                      st.stopTest();
                    } else {
                      st.startTest(
                        onFinish: () {
                          context.read<HistoryProvider>().addResult(
                            download: st.downloadSpeed,
                            upload: st.uploadSpeed,
                            latency: st.latency,
                            jitter: st.jitter,
                            server: st.serverName,
                            isp: st.clientIsp,
                          );
                        },
                      );
                    }
                  },
                  icon: Icon(
                    st.isActive ? Icons.stop : Icons.play_arrow,
                    size: 20,
                  ),
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            children: [
              if (history.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No history found. Run a test first!',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                )
              else ...[
                SizedBox(
                  height: 120,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(
                        show: true,
                        drawVerticalLine: false,
                      ),
                      titlesData: const FlTitlesData(
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.white10),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: history.items.reversed
                              .toList()
                              .asMap()
                              .entries
                              .map(
                                (e) =>
                                    FlSpot(e.key.toDouble(), e.value.download),
                              )
                              .toList(),
                          isCurved: true,
                          color: Colors.greenAccent,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                        ),
                        LineChartBarData(
                          spots: history.items.reversed
                              .toList()
                              .asMap()
                              .entries
                              .map(
                                (e) => FlSpot(e.key.toDouble(), e.value.upload),
                              )
                              .toList(),
                          isCurved: true,
                          color: Colors.blueAccent,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 16,
                    headingRowHeight: 32,
                    dataRowMinHeight: 24,
                    dataRowMaxHeight: 32,
                    columns: const [
                      DataColumn(
                        label: Text('Time', style: TextStyle(fontSize: 10)),
                      ),
                      DataColumn(
                        label: Text('DN', style: TextStyle(fontSize: 10)),
                      ),
                      DataColumn(
                        label: Text('UP', style: TextStyle(fontSize: 10)),
                      ),
                      DataColumn(
                        label: Text('LT', style: TextStyle(fontSize: 10)),
                      ),
                      DataColumn(
                        label: Text('JT', style: TextStyle(fontSize: 10)),
                      ),
                      DataColumn(
                        label: Text('Location', style: TextStyle(fontSize: 10)),
                      ),
                    ],
                    rows: history.items
                        .take(10)
                        .map(
                          (item) => DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  DateFormat('HH:mm').format(item.timestamp),
                                  style: const TextStyle(fontSize: 9),
                                ),
                              ),
                              DataCell(
                                Text(
                                  item.download.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.greenAccent,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  item.upload.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${item.latency}ms',
                                  style: const TextStyle(fontSize: 9),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${item.jitter}ms',
                                  style: const TextStyle(fontSize: 9),
                                ),
                              ),
                              DataCell(
                                Text(
                                  item.server,
                                  style: const TextStyle(fontSize: 9),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => history.clearHistory(),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 14,
                    color: Colors.redAccent,
                  ),
                  label: const Text(
                    'CLEAR HISTORY',
                    style: TextStyle(fontSize: 10, color: Colors.redAccent),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String label, double val, Color color) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(width: 4),
      Text(
        val.toStringAsFixed(1),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
      const Text(' Mbps', style: TextStyle(fontSize: 8, color: Colors.grey)),
    ],
  );
  Widget _smallStat(String label, double val, Color color) => Row(
    children: [
      Text(
        '$label: ',
        style: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
      Text(
        '${val.round()}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      const Text(' ms', style: TextStyle(fontSize: 8, color: Colors.grey)),
    ],
  );
}
