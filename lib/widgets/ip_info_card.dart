import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ip_info_service.dart';
import 'base_card.dart';

class IpInfoCard extends StatefulWidget {
  const IpInfoCard({super.key});

  @override
  State<IpInfoCard> createState() => _IpInfoCardState();
}

class _IpInfoCardState extends State<IpInfoCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IpInfoProvider>().fetchIpInfo();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<IpInfoProvider>(
      builder: (context, provider, child) {
        final data = provider.data;
        final isLoading = provider.isLoading;
        final error = provider.error;

        return BaseCard(
          leading: Icon(
            data?.ip != null ? Icons.public : Icons.public_off,
            color: Colors.tealAccent,
          ),
          title: 'Public IP & ISP',
          subtitle: data?.ip ?? 'Fetching IP...',
          trailing: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => provider.fetchIpInfo(),
                ),
          initiallyExpanded: data != null || error != null,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: error != null
                  ? Text(
                      error,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    )
                  : data == null
                      ? const Text('No data available', style: TextStyle(fontSize: 12))
                      : Column(
                          children: [
                            _buildDetailRow(Icons.business, 'ISP', data.isp),
                            _buildDetailRow(Icons.corporate_fare, 'Organization', data.org),
                            const Divider(height: 16),
                            _buildDetailRow(Icons.location_on, 'Location', '${data.city}, ${data.region}'),
                            _buildDetailRow(Icons.flag, 'Country', data.country),
                            _buildDetailRow(Icons.schedule, 'Timezone', data.timezone),
                          ],
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}