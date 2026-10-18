// Settings Local Ports Configuration Card
// Provides input controls for local HTTP and SOCKS5 proxy inbound port bindings.
// Validates TCP port ranges (1-65535) and saves preferences with feedback.
// Formatted with compact mobile input fields for touch interfaces.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';

/// Card for configuring and modifying local HTTP and SOCKS5 inbound ports.
/// Validates numeric port ranges and saves values to state providers.
class SettingsPortsCard extends ConsumerStatefulWidget {
  final String locale;

  const SettingsPortsCard({
    super.key,
    required this.locale,
  });

  @override
  ConsumerState<SettingsPortsCard> createState() => _SettingsPortsCardState();
}

class _SettingsPortsCardState extends ConsumerState<SettingsPortsCard> {
  late TextEditingController _httpPortController;
  late TextEditingController _socksPortController;

  @override
  void initState() {
    super.initState();
    final httpPort = ref.read(httpPortProvider);
    final socksPort = ref.read(socksPortProvider);
    _httpPortController = TextEditingController(text: httpPort.toString());
    _socksPortController = TextEditingController(text: socksPort.toString());
  }

  @override
  void dispose() {
    _httpPortController.dispose();
    _socksPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    final httpPort = ref.watch(httpPortProvider);
    final socksPort = ref.watch(socksPortProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.25), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 16, color: AppTheme.primaryAccent),
              const SizedBox(width: 6),
              Text(
                locale == 'fa' ? 'تعیین پورت‌های ورودی محلی (Proxy)' : 'Local Inbound Ports (Proxy)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryAccent),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildPortRow(
            icon: Icons.settings_ethernet_rounded,
            iconColor: AppTheme.primaryAccent,
            title: AppStrings.get('http_port', locale: locale),
            currentPort: httpPort,
            defaultPort: 10888,
            controller: _httpPortController,
            onSave: (p) => ref.read(httpPortProvider.notifier).setPort(p),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _buildPortRow(
            icon: Icons.swap_calls_rounded,
            iconColor: AppTheme.secondaryAccent,
            title: AppStrings.get('socks_port', locale: locale),
            currentPort: socksPort,
            defaultPort: 10999,
            controller: _socksPortController,
            onSave: (p) => ref.read(socksPortProvider.notifier).setPort(p),
          ),
        ],
      ),
    );
  }

  Widget _buildPortRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required int currentPort,
    required int defaultPort,
    required TextEditingController controller,
    required void Function(int p) onSave,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text('127.0.0.1:$currentPort (Default: $defaultPort)', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
        SizedBox(
          width: 75,
          height: 32,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.check_circle_rounded, size: 20, color: AppTheme.successColor),
          onPressed: () {
            final p = int.tryParse(controller.text.trim());
            if (p != null && p > 0 && p < 65536) {
              onSave(p);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Port saved: $p')),
              );
            }
          },
        ),
      ],
    );
  }
}
