class MikrotikUser {
  final String id;
  final String name;
  final String address;
  final String uptime;
  final String bytesIn;
  final String bytesOut;
  final String rxRate;
  final String txRate;

  const MikrotikUser({
    required this.id,
    required this.name,
    required this.address,
    required this.uptime,
    required this.bytesIn,
    required this.bytesOut,
    required this.rxRate,
    required this.txRate,
  });
}

class InterfaceStat {
  final String name;
  final String rxRate;
  final String txRate;

  const InterfaceStat({
    required this.name,
    required this.rxRate,
    required this.txRate,
  });
}

class MikrotikSystem {
  final String name;
  final String uptime;
  final String version;
  final String buildTime;
  final String factorySoftware;
  final String boardName;
  final String architectureName;
  final String cpu;
  final int cpuCount;
  int cpuLoad;
  int freeRam;
  final int freeHdd;
  final int totalHdd;
  final int totalRam;

  MikrotikSystem({
    required this.name,
    required this.uptime,
    required this.version,
    required this.buildTime,
    required this.factorySoftware,
    required this.boardName,
    required this.architectureName,
    required this.cpu,
    required this.cpuCount,
    required this.cpuLoad,
    required this.freeHdd,
    required this.totalHdd,
    required this.freeRam,
    required this.totalRam,
  });
}

class MikrotikConfig {
  final String host;
  final String user;
  final String pass;
  final String monitoredInterfaces;
  final int refreshInterval;
  final bool isMonitoring;
  final bool isDemoMode;

  const MikrotikConfig({
    this.host = '',
    this.user = '',
    this.pass = '',
    this.monitoredInterfaces = 'ether1',
    this.refreshInterval = 2,
    this.isMonitoring = false,
    this.isDemoMode = false,
  });

  MikrotikConfig copyWith({
    String? host,
    String? user,
    String? pass,
    String? monitoredInterfaces,
    int? refreshInterval,
    bool? isMonitoring,
    bool? isDemoMode,
  }) {
    return MikrotikConfig(
      host: host ?? this.host,
      user: user ?? this.user,
      pass: pass ?? this.pass,
      monitoredInterfaces: monitoredInterfaces ?? this.monitoredInterfaces,
      refreshInterval: refreshInterval ?? this.refreshInterval,
      isMonitoring: isMonitoring ?? this.isMonitoring,
      isDemoMode: isDemoMode ?? this.isDemoMode,
    );
  }
}
