import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:netpulse/services/mikrotik_service.dart';
import 'package:netpulse/models/mikrotik.dart';
import 'package:netpulse/utils/formater.dart';
import 'package:netpulse/utils/parser.dart';
import 'base_card.dart';

class MikrotikCard extends StatelessWidget {
  final String? uniqueKey;
  final String? configKey;
  final VoidCallback? onDelete;

  const MikrotikCard({
    super.key,
    this.uniqueKey,
    this.configKey,
    this.onDelete,
  });

  String get _configKey => configKey ?? uniqueKey ?? 'default';

  @override
  Widget build(BuildContext context) {
    final provider = context.read<MikrotikProvider>();
    final instance = provider.getInstance(_configKey);

    return ListenableBuilder(
      listenable: instance,
      builder: (context, _) {
        final isConnected = instance.isConnected;
        final config = instance.config;

        final userStatusColor = switch (instance.activeUsersCount) {
          int i when i > 100 => Colors.greenAccent,
          int i when i > 70 => Colors.cyanAccent,
          int i when i > 50 => Colors.yellowAccent,
          int i when i > 20 => Colors.orangeAccent,
          _ => Colors.redAccent,
        };
        final cpuLoadColor = switch (instance.cpuLoad) {
          int i when i > 90 => Colors.redAccent,
          int i when i > 75 => Colors.orangeAccent,
          int i when i > 50 => Colors.yellowAccent,
          int i when i > 25 => Colors.cyanAccent,
          _ => Colors.greenAccent,
        };

        Widget card = BaseCard(
          title: isConnected
              ? (config.isDemoMode ? 'Demo Mode' : config.host)
              : 'MikroTik',
          subtitle: isConnected
              ? (config.isDemoMode ? 'Demo' : 'Connected')
              : instance.status,
          subtitleColor: isConnected ? Colors.greenAccent : Colors.grey,
          leading: Icon(
            Icons.router,
            color: isConnected ? Colors.orangeAccent : Colors.grey,
            size: 24,
          ),
          trailing: isConnected
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatusChip(
                      '${instance.activeUsersCount}',
                      'users',
                      userStatusColor,
                    ),
                    const SizedBox(width: 2),
                    _buildStatusChip(
                      '${instance.cpuLoad}',
                      'CPU %',
                      cpuLoadColor,
                    ),
                  ],
                )
              : null,
          onDoubleTap: () => _showLoginDialog(context, instance),
          onTap: () {
            if (!isConnected && config.host.isNotEmpty) instance.connect();
          },
          onExpansionChanged: (expanded) {
            if (expanded) {
              final detailsState = context
                  .findAncestorStateOfType<_MikrotikDetailsState>();
              if (detailsState != null && detailsState._usersExpanded) {
                instance.toggleUserDetail(true);
              }
            } else {
              instance.toggleUserDetail(false);
            }
          },
          children: isConnected
              ? [
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: _MikrotikDetails(instance: instance),
                  ),
                ]
              : null,
        );

        return Dismissible(
          key: ValueKey('mikrotik_$_configKey'),
          direction: onDelete != null
              ? DismissDirection.horizontal
              : (isConnected
                    ? DismissDirection.endToStart
                    : DismissDirection.none),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              if (isConnected) {
                instance.disconnect();
              } else if (config.host.isNotEmpty) {
                instance.connect();
              }
              return false;
            } else {
              onDelete?.call();
              provider.removeInstance(_configKey);
              return true;
            }
          },
          background: Container(
            color: Colors.greenAccent.withAlpha(50),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            child: const Icon(Icons.link_off, color: Colors.greenAccent),
          ),
          secondaryBackground: Container(
            color: Colors.redAccent.withAlpha(50),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.redAccent),
          ),
          child: card,
        );
      },
    );
  }

  Widget _buildStatusChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color.withAlpha(150),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showLoginDialog(BuildContext context, MikrotikInstance instance) {
    final config = instance.config;
    final hostCtrl = TextEditingController(text: config.host);
    final portCtrl = TextEditingController(text: config.port.toString());
    final userCtrl = TextEditingController(text: config.user);
    final passCtrl = TextEditingController(text: config.pass);
    final ifaceCtrl = TextEditingController(text: config.monitoredInterfaces);
    int currentInterval = config.refreshInterval;
    bool demoMode = config.isDemoMode;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          title: const Text(
            'MikroTik Settings',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: hostCtrl,
                  enabled: !demoMode,
                  decoration: const InputDecoration(
                    labelText: 'Host Address',
                    hintText: '192.168.0.1',
                  ),
                ),
                TextField(
                  controller: portCtrl,
                  enabled: !demoMode,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    hintText: '8728',
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                TextField(
                  controller: userCtrl,
                  enabled: !demoMode,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                TextField(
                  controller: passCtrl,
                  enabled: !demoMode,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                TextField(
                  controller: ifaceCtrl,
                  enabled: !demoMode,
                  decoration: const InputDecoration(
                    labelText: 'Ports',
                    helperText: 'e.g. ether1,bridge',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Refresh Rate:'),
                    DropdownButton<int>(
                      value: currentInterval,
                      items: [2, 5, 10, 30, 60]
                          .map(
                            (v) =>
                                DropdownMenuItem(value: v, child: Text('$v s')),
                          )
                          .toList(),
                      onChanged: demoMode
                          ? null
                          : (v) {
                              if (v != null) {
                                setState(() => currentInterval = v);
                              }
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Demo Mode:'),
                    Switch(
                      value: demoMode,
                      onChanged: (v) => setState(() => demoMode = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(fontSize: 13)),
            ),
            TextButton(
              onPressed: () {
                final newConfig = MikrotikConfig(
                  host: hostCtrl.text.trim(),
                  port: parseIntSafe(portCtrl.text.trim(), defaultValue: 8728),
                  user: userCtrl.text.trim(),
                  pass: passCtrl.text.trim(),
                  monitoredInterfaces: ifaceCtrl.text.trim(),
                  refreshInterval: currentInterval,
                  isMonitoring: true,
                  isDemoMode: demoMode,
                );
                instance.saveConfig(newConfig);
                Navigator.pop(context);
                if (demoMode) {
                  instance.startDemoMode();
                } else {
                  instance.connect();
                }
              },
              child: Text(
                demoMode ? 'START DEMO' : 'SAVE & CONNECT',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MikrotikDetails extends StatefulWidget {
  final MikrotikInstance instance;
  const _MikrotikDetails({required this.instance});

  @override
  State<_MikrotikDetails> createState() => _MikrotikDetailsState();
}

class _MikrotikDetailsState extends State<_MikrotikDetails> {
  bool _usersExpanded = false;

  @override
  Widget build(BuildContext context) {
    final instance = widget.instance;
    final config = instance.config;
    final system = instance.system;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGrid([
          _buildDetailItem(
            'HOST',
            config.host.isNotEmpty ? config.host : '-',
            Icons.lan,
          ),
          _buildDetailItem(
            'PORT',
            config.port.toString(),
            Icons.settings_input_antenna,
          ),
          _buildDetailItem(
            'USER',
            config.user.isNotEmpty ? config.user : '-',
            Icons.person,
          ),
          _buildDetailItem(
            'REFRESH',
            '${config.refreshInterval}s',
            Icons.timer,
          ),
        ]),
        if (system != null) ...[
          const SizedBox(height: 12),
          const _SectionHeader(title: 'SYSTEM'),
          const SizedBox(height: 4),
          _buildGrid([
            _buildDetailItem('NAME', system.name, Icons.label),
            _buildDetailItem('UPTIME', system.uptime, Icons.timelapse),
            _buildDetailItem('VERSION', system.version, Icons.info),
            _buildDetailItem('BUILD', system.buildTime, Icons.build),
            _buildDetailItem('FACTORY', system.factorySoftware, Icons.factory),
            _buildDetailItem('BOARD', system.boardName, Icons.memory),
            _buildDetailItem(
              'ARCH',
              system.architectureName,
              Icons.architecture,
            ),
            _buildDetailItem('CPU', system.cpu, Icons.developer_board),
            _buildDetailItem('CPUs', '${system.cpuCount}', Icons.numbers),
            _buildDetailItem('LOAD', '${system.cpuLoad}%', Icons.speed),
            _buildDetailItem(
              'RAM',
              '${formatBytes(system.freeRam)}/${formatBytes(system.totalRam)}',
              Icons.memory,
            ),
            _buildDetailItem(
              'HDD',
              '${formatBytes(system.freeHdd)}/${formatBytes(system.totalHdd)}',
              Icons.storage,
            ),
          ]),
        ],
        if (instance.interfaceStats.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _SectionHeader(title: 'INTERFACES'),
          const SizedBox(height: 4),
          _buildInterfacesGrid(instance.interfaceStats),
        ],
        if (instance.activeUsersCount > 0) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              setState(() => _usersExpanded = !_usersExpanded);
              instance.toggleUserDetail(_usersExpanded);
            },
            child: Row(
              children: [
                _SectionHeader(
                  title: 'HOTSPOT USERS (${instance.activeUsersCount})',
                ),
                const SizedBox(width: 4),
                Icon(
                  _usersExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 14,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
          if (_usersExpanded) ...[
            const SizedBox(height: 4),
            _buildUsersTable(instance.activeUsers),
          ],
        ],
      ],
    );
  }

  Widget _buildGrid(List<Widget> children) {
    return Wrap(spacing: 20, runSpacing: 10, children: children);
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return SizedBox(
      width: 130,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.orangeAccent.withAlpha(150)),
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
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterfacesGrid(List<InterfaceStat> stats) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: stats
          .map(
            (s) => SizedBox(
              width: 130,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lan,
                    size: 14,
                    color: Colors.orangeAccent.withAlpha(150),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.enabled
                              ? s.name.toUpperCase()
                              : '${s.name.toUpperCase()} (inactive)',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.arrow_downward_rounded,
                              size: 10,
                              color: Colors.greenAccent,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              s.rxRate,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_upward_rounded,
                              size: 10,
                              color: Colors.blueAccent,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              s.txRate,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildUsersTable(List<MikrotikUser> users) {
    final instance = widget.instance;
    const double colName = 110;
    const double colIP = 100;
    const double colRate = 75;
    const double colByte = 75;

    final columnWidths = {
      0: const FixedColumnWidth(colName),
      1: const FixedColumnWidth(colIP),
      2: const FixedColumnWidth(colRate),
      3: const FixedColumnWidth(colRate),
      4: const FixedColumnWidth(colByte),
      5: const FixedColumnWidth(colByte),
    };

    Widget headerCell(String text, UserSort field) {
      final isSorted = instance.sortField == field;
      return InkWell(
        onTap: () => instance.setSort(field),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              if (isSorted) ...[
                const SizedBox(width: 2),
                Icon(
                  instance.sortAscending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 10,
                  color: Colors.orangeAccent,
                ),
              ],
            ],
          ),
        ),
      );
    }

    Widget dataCell(String text, {Color? color, bool mono = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontFamily: mono ? 'monospace' : null,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: columnWidths,
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(5),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.withAlpha(50)),
                  ),
                ),
                children: [
                  headerCell('Name', UserSort.name),
                  headerCell('IP', UserSort.address),
                  headerCell('RX', UserSort.rxRate),
                  headerCell('TX', UserSort.txRate),
                  headerCell('IN', UserSort.bytesIn),
                  headerCell('OUT', UserSort.bytesOut),
                ],
              ),
            ],
          ),
          Container(
            constraints: const BoxConstraints(maxHeight: 250),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: columnWidths,
                children: users
                    .map(
                      (u) => TableRow(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.withAlpha(20),
                            ),
                          ),
                        ),
                        children: [
                          dataCell(u.name),
                          dataCell(u.address, mono: true),
                          dataCell(
                            formatSpeed(u.rxRate),
                            color: Colors.greenAccent,
                          ),
                          dataCell(
                            formatSpeed(u.txRate),
                            color: Colors.blueAccent,
                          ),
                          dataCell(
                            formatBytes(u.bytesIn),
                            color: Colors.greenAccent,
                          ),
                          dataCell(
                            formatBytes(u.bytesOut),
                            color: Colors.blueAccent,
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
      ),
    );
  }
}
