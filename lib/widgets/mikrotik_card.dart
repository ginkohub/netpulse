import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../mikrotik_service.dart';

class MikrotikCard extends StatelessWidget {
  const MikrotikCard({super.key});

  void _showLoginDialog(BuildContext context, MikrotikProvider mk) {
    final hostCtrl = TextEditingController(text: mk.host);
    final userCtrl = TextEditingController(text: mk.user);
    final passCtrl = TextEditingController(text: mk.pass);
    final ifaceCtrl = TextEditingController(text: mk.monitoredInterfaces);
    int currentInterval = mk.refreshInterval;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('MikroTik Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: hostCtrl,
                  decoration: const InputDecoration(
                    labelText: 'IP Address',
                    hintText: '192.168.88.1',
                  ),
                ),
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                TextField(
                  controller: ifaceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ports (e.g. ether1,bridge)',
                    helperText: 'Comma separated list of interfaces',
                    helperStyle: TextStyle(fontSize: 10),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Refresh Rate:'),
                    DropdownButton<int>(
                      value: currentInterval,
                      items: [2, 5, 10, 30, 60].map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text('$value s'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => currentInterval = val);
                      },
                    ),
                  ],
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
              onPressed: () {
                mk.setInterfaces(ifaceCtrl.text.trim());
                mk.setConfig(hostCtrl.text, userCtrl.text, passCtrl.text);
                mk.setRefreshInterval(currentInterval);
                Navigator.pop(context);
              },
              child: const Text('SAVE & CONNECT'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MikrotikProvider>(
      builder: (context, mk, child) {
        return Card(
          margin: const EdgeInsets.fromLTRB(8, 2, 8, 2),
          elevation: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 6, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.router,
                              color: mk.isConnected
                                  ? Colors.orangeAccent
                                  : Colors.grey,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              mk.isConnected ? mk.host : 'MikroTik',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (mk.isConnected)
                              Transform.scale(
                                scale: 0.5,
                                child: Switch(
                                  value: mk.isMonitoring,
                                  onChanged: (_) => mk.toggleMonitoring(),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            IconButton(
                              icon: Icon(
                                mk.isConnected ? Icons.settings : Icons.login,
                                size: 14,
                              ),
                              onPressed: () => _showLoginDialog(context, mk),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (mk.isConnected && mk.interfaceStats.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0, bottom: 4.0),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: mk.interfaceStats
                              .map(
                                (stat) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(10),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Wrap(
                                    spacing: 4,
                                    runSpacing: 1,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        stat.name.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      _trafficStat(
                                        'R',
                                        stat.rxRate,
                                        Colors.greenAccent,
                                      ),
                                      _trafficStat(
                                        'T',
                                        stat.txRate,
                                        Colors.blueAccent,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      )
                    else if (!mk.isConnected)
                      Text(mk.status, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              if (mk.isConnected)
                ExpansionTile(
                  shape: const Border(),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  minTileHeight: 32,
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${mk.activeUsers.length}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Colors.orangeAccent,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'ACTIVE USERS',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  children: [
                    if (mk.activeUsers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No active users found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 400),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: DataTable(
                              columnSpacing: 20,
                              horizontalMargin: 12,
                              headingRowHeight: 32,
                              dataRowMinHeight: 32,
                              dataRowMaxHeight: 40,
                              sortColumnIndex: mk.sortColumnIndex,
                              sortAscending: mk.sortAscending,
                              columns: [
                                DataColumn(
                                  label: const Text(
                                    'Name',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onSort: (idx, asc) => mk.updateSort(idx, asc),
                                ),
                                DataColumn(
                                  label: const Text(
                                    'IP',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onSort: (idx, asc) => mk.updateSort(idx, asc),
                                ),
                                DataColumn(
                                  label: const Text(
                                    'RX',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onSort: (idx, asc) => mk.updateSort(idx, asc),
                                ),
                                DataColumn(
                                  label: const Text(
                                    'TX',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onSort: (idx, asc) => mk.updateSort(idx, asc),
                                ),
                                DataColumn(
                                  label: const Text(
                                    'Byte In',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onSort: (idx, asc) => mk.updateSort(idx, asc),
                                ),
                                DataColumn(
                                  label: const Text(
                                    'Byte Out',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onSort: (idx, asc) => mk.updateSort(idx, asc),
                                ),
                                DataColumn(
                                  label: const Text(
                                    'Time',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onSort: (idx, asc) => mk.updateSort(idx, asc),
                                ),
                              ],
                              rows: mk.activeUsers
                                  .map(
                                    (u) => DataRow(
                                      cells: [
                                        DataCell(
                                          Text(
                                            u.name,
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            u.address,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            u.rxRate,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.greenAccent,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            u.txRate,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.blueAccent,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            u.bytesIn,
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            u.bytesOut,
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            u.uptime,
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _trafficStat(String label, String val, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: const TextStyle(fontSize: 8, color: Colors.grey),
        ),
        const SizedBox(width: 2),
        Text(
          val,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
