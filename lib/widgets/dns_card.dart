import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dns_service.dart';
import 'base_card.dart';

class DnsCard extends StatefulWidget {
  const DnsCard({super.key});

  @override
  State<DnsCard> createState() => _DnsCardState();
}

class _DnsCardState extends State<DnsCard> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DnsProvider>(
      builder: (context, provider, child) {
        final records = provider.records;
        final whois = provider.whois;
        final isLoading = provider.isLoading;
        final error = provider.error;

        return BaseCard(
          leading: Icon(Icons.dns, color: Colors.amberAccent),
          title: 'DNS Lookup / WHOIS',
          subtitle: provider.lastQuery ?? 'Enter domain to lookup',
          initiallyExpanded: records.isNotEmpty || whois != null || error != null,
          trailing: IconButton(
            icon: const Icon(Icons.search, color: Colors.amberAccent),
            onPressed: () => _showLookupDialog(context, provider),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(error, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    )
                  else if (records.isEmpty && whois == null)
                    const Text(
                      'Enter a domain to lookup DNS records or WHOIS info.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    )
                  else ...[
                    if (records.isNotEmpty) ...[
                      const Text('DNS Records', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      ...records.map((r) => _buildRecordRow(r)),
                      const SizedBox(height: 16),
                    ],
                    if (whois != null) ...[
                      const Text('WHOIS Info', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      if (whois.registrar != null) _buildWhoisRow('Registrar', whois.registrar!),
                      if (whois.creationDate != null) _buildWhoisRow('Created', whois.creationDate!),
                      if (whois.expirationDate != null) _buildWhoisRow('Expires', whois.expirationDate!),
                      if (whois.nameServers != null) _buildWhoisRow('Name Servers', whois.nameServers!),
                      if (whois.status != null) _buildWhoisRow('Status', whois.status!),
                    ],
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecordRow(DnsRecord record) {
    Color typeColor;
    switch (record.type) {
      case 'A': case 'AAAA': typeColor = Colors.blueAccent; break;
      case 'MX': typeColor = Colors.orangeAccent; break;
      case 'CNAME': typeColor = Colors.greenAccent; break;
      case 'TXT': typeColor = Colors.purpleAccent; break;
      case 'NS': typeColor = Colors.cyanAccent; break;
      default: typeColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              record.type,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              record.value,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhoisRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  void _showLookupDialog(BuildContext context, DnsProvider provider) {
    _controller.text = provider.lastInput ?? '';
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DNS Lookup', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'e.g. google.com',
                isDense: true,
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    final domain = _controller.text.trim();
                    if (domain.isNotEmpty) {
                      provider.setLastInput(domain);
                      provider.lookup(domain);
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('DNS Lookup'),
                ),
                TextButton(
                  onPressed: () {
                    final domain = _controller.text.trim();
                    if (domain.isNotEmpty) {
                      provider.setLastInput(domain);
                      provider.whoisLookup(domain);
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('WHOIS'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }
}