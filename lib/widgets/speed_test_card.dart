import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/speedtest_service.dart';
import '../services/history_service.dart';
import 'base_card.dart';

class SpeedTestCard extends StatelessWidget {
  const SpeedTestCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SpeedTestProvider, HistoryProvider>(
      builder: (context, st, history, child) {
        return BaseCard(
          leading: Icon(Icons.speed, size: 24, color: Colors.blueAccent),
          titleWidget: Row(
            children: [
              _buildMiniStat(
                'DOWN',
                st.downloadSpeed,
                Icons.arrow_downward,
                Colors.greenAccent,
                isBig: true,
              ),
              const SizedBox(width: 8),
              _buildMiniStat(
                'UP',
                st.uploadSpeed,
                Icons.arrow_upward,
                Colors.blueAccent,
                isBig: true,
              ),
              const SizedBox(width: 8),
              _buildMiniStat(
                'PING',
                st.latency.toDouble(),
                Icons.network_ping,
                Colors.orangeAccent,
              ),
              const SizedBox(width: 8),
              _buildMiniStat(
                'JIT',
                st.jitter.toDouble(),
                Icons.speed,
                Colors.purpleAccent,
              ),
            ],
          ),

          body: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showServerDialog(context, st),
              icon: const Icon(Icons.signal_cellular_alt, size: 18),
              label: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    st.serverSponsor,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      height: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    st.serverName,
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.grey,
                      height: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          trailing: IconButton.filledTonal(
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
                      sponsor: st.serverSponsor,
                      isp: st.clientIsp,
                    );
                  },
                );
              }
            },
            icon: Icon(st.isActive ? Icons.stop : Icons.play_arrow, size: 20),
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
          ),
          children: [
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _buildInfoItem(
                        'Location',
                        st.serverName,
                        Icons.location_on,
                        onTap: () => {_showServerDialog(context, st)},
                      ),
                      _buildInfoItem(
                        'Sponsor',
                        st.availableServers.isNotEmpty &&
                                st.selectedServer != null
                            ? st.selectedServer!.sponsor
                            : st.serverSponsor,
                        Icons.business,
                      ),
                      _buildInfoItem('ISP', st.clientIsp, Icons.wifi),
                      _buildInfoItem('IP', st.clientIp, Icons.language),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (history.items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No history found. Run a test first!',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    SizedBox(
                      height: 120,
                      child: LineChart(
                        LineChartData(
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (touchedSpot) =>
                                  Colors.blueGrey.withOpacity(0.8),
                              getTooltipItems:
                                  (List<LineBarSpot> touchedBarSpots) {
                                return touchedBarSpots.map((barSpot) {
                                  final flSpot = barSpot;
                                  return LineTooltipItem(
                                    '${flSpot.y.toStringAsFixed(1)} Mbps',
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
                                    (e) => FlSpot(
                                      e.key.toDouble(),
                                      e.value.download,
                                    ),
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
                                    (e) => FlSpot(
                                      e.key.toDouble(),
                                      e.value.upload,
                                    ),
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
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 16,
                        headingRowHeight: 36,
                        dataRowMinHeight: 32,
                        dataRowMaxHeight: 36,
                        columns: const [
                          DataColumn(
                            label: Text('Time', style: TextStyle(fontSize: 11)),
                          ),
                          DataColumn(
                            label: Text('DN', style: TextStyle(fontSize: 11)),
                          ),
                          DataColumn(
                            label: Text('UP', style: TextStyle(fontSize: 11)),
                          ),
                          DataColumn(
                            label: Text('LT', style: TextStyle(fontSize: 11)),
                          ),
                          DataColumn(
                            label: Text('JT', style: TextStyle(fontSize: 11)),
                          ),
                          DataColumn(
                            label: Text(
                              'Location',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Sponsor',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                        rows: history.items
                            .take(10)
                            .map(
                              (item) => DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      DateFormat(
                                        'dd/MM/yy HH:mm',
                                      ).format(item.timestamp),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.download.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.greenAccent,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.upload.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${item.latency}ms',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${item.jitter}ms',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.server,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.sponsor,
                                      style: const TextStyle(fontSize: 10),
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
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMiniStat(
    String label,
    double val,
    IconData icon,
    Color color, {
    bool isBig = false,
  }) {
    final isLoading = val == 0;
    final unit = switch (label) {
      'PING' => 'ms',
      'JIT' => 'ms',
      _ => 'Mbps',
    };

    return SizedBox(
      width: isBig ? 58 : 32,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: isBig ? 8 : 7, color: color),
              const SizedBox(width: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: isBig ? 8 : 7,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isLoading
                    ? '---'
                    : val == val.roundToDouble()
                    ? '${val.round()}'
                    : val.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: isBig ? 24 : 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                  fontSize: isBig ? 8 : 7,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    String label,
    String value,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 120,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blueAccent.withAlpha(180)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 8,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onTap != null)
                      IconButton(
                        iconSize: 10,
                        onPressed: onTap,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                          maxWidth: 20,
                          maxHeight: 20,
                        ),
                        icon: Icon(
                          Icons.arrow_forward_ios,
                          size: 10,
                          color: Colors.blueAccent.withAlpha(180),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showServerDialog(BuildContext context, SpeedTestProvider st) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        title: const Text(
          'Select Server',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 250,
          child: ListView.builder(
            itemCount: st.availableServers.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  leading: const Icon(Icons.auto_awesome, size: 16),
                  title: const Text(
                    'Auto Pick Best',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${st.availableServers.length} servers available',
                    style: const TextStyle(fontSize: 10),
                  ),
                  selected: st.selectedServer == null,
                  onTap: () {
                    st.selectServer(null);
                    st.findBestServer();
                    Navigator.pop(context);
                  },
                );
              }
              final server = st.availableServers[index - 1];
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                leading: Icon(
                  server.latency < 50
                      ? Icons.signal_cellular_4_bar
                      : (server.latency < 100
                            ? Icons.signal_cellular_alt
                            : Icons.signal_cellular_alt_1_bar),
                  size: 12,
                  color: server.latency < 50
                      ? Colors.greenAccent
                      : (server.latency < 100
                            ? Colors.orangeAccent
                            : Colors.redAccent),
                ),
                title: Text(
                  '${server.name} • ${server.latency < 9999 ? '${server.latency}ms' : '?'}',
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  server.sponsor,
                  style: const TextStyle(fontSize: 10),
                ),
                trailing: st.selectedServer == server
                    ? const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.greenAccent,
                      )
                    : null,
                onTap: () {
                  st.selectServer(server);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
