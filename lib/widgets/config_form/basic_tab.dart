// File: lib/widgets/config_form/basic_tab.dart
// Description: Basic settings tab for proxy configurations (alias remark, server address, and port).
// Manages and validates initial mandatory inputs for proxy servers.
// Designed for Android UI with clean, modern text fields.

import 'package:flutter/material.dart';
import '../../core/l10n/translations.dart';

/// Basic info tab for configuring proxy node remark alias, server host/IP, and port.
///
/// Users specify their desired node name, host address or IP, and destination port
/// for connecting to the VPN/proxy server.
class BasicTab extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController addressController;
  final TextEditingController portController;
  final String locale;

  const BasicTab({
    super.key,
    required this.nameController,
    required this.addressController,
    required this.portController,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: AppStrings.get('alias_remark', locale: locale),
              hintText: 'e.g. My Fast VPS',
              prefixIcon: const Icon(Icons.label_rounded, size: 20),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: addressController,
            decoration: InputDecoration(
              labelText: AppStrings.get('server_address', locale: locale),
              hintText: '198.51.100.1 or mydomain.com',
              prefixIcon: const Icon(Icons.dns_rounded, size: 20),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: portController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: AppStrings.get('server_port', locale: locale),
              hintText: '443',
              prefixIcon: const Icon(Icons.tag_rounded, size: 20),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}
