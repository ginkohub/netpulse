import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mdns_service.dart';
import 'base_card.dart';

class MdnsCard extends StatefulWidget {
  const MdnsCard({super.key});

  @override
  State<MdnsCard> createState() => _MdnsCardState();
}

class _MdnsCardState extends State<MdnsCard> {
  @override
  Widget build(BuildContext context) {
    return Consumer<MdnsProvider>(
      builder: (context, provider, child) {
        final services = provider.services;
        final isScanning = provider.isScanning;
        final error = provider.error;

        return BaseCard(
          leading: Icon(
            Icons.radar,
            color: isScanning ? Colors.orangeAccent : Colors.cyanAccent,
          ),
          title: 'mDNS / Bonjour',
          subtitle: isScanning ? 'Scanning...' : '${services.length} services found',
          initiallyExpanded: isScanning || services.isNotEmpty || error != null,
          trailing: IconButton(
            icon: Icon(
              isScanning ? Icons.stop : Icons.play_arrow,
              color: isScanning ? Colors.redAccent : Colors.greenAccent,
            ),
            onPressed: () {
              if (isScanning) {
                provider.stopScan();
              } else {
                provider.startScan();
              }
            },
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTypeSelector(provider),
                  const SizedBox(height: 8),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        error,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  if (services.isEmpty && !isScanning)
                    const Text(
                      'No services found. Tap play to scan.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    )
                  else if (services.isNotEmpty)
                    ...services.map((s) => _buildServiceItem(s)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypeSelector(MdnsProvider provider) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: provider.presetTypes.map((type) {
        final label = type.replaceAll('._tcp', '').replaceAll('_', ' ');
        final isSelected = provider.serviceType == type;
        return GestureDetector(
          onTap: () => provider.setServiceType(type),
          child: Chip(
            label: Text(label, style: const TextStyle(fontSize: 10)),
            backgroundColor: isSelected ? Colors.cyanAccent.withValues(alpha: 0.2) : null,
            side: BorderSide(
              color: isSelected ? Colors.cyanAccent : Colors.grey.withValues(alpha: 0.3),
              width: isSelected ? 1.5 : 0.5,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            visualDensity: VisualDensity.compact,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildServiceItem(ServiceInfo service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _getIconForType(service.displayType),
            size: 20,
            color: Colors.cyanAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${service.displayType}${service.host != null ? ' • ${service.host}' : ''}${service.port != null ? ':${service.port}' : ''}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Web': return Icons.language;
      case 'SSH': return Icons.terminal;
      case 'Printer': return Icons.print;
      case 'AirPlay': return Icons.tv;
      case 'Chromecast': return Icons.cast;
      case 'Audio': return Icons.speaker;
      case 'HomeKit': return Icons.home;
      case 'Spotify': return Icons.music_note;
      default: return Icons.devices;
    }
  }
}