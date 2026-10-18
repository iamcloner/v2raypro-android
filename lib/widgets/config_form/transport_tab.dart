// File: lib/widgets/config_form/transport_tab.dart
// Description: Protocol and transport layer settings tab (TCP, WS, gRPC, HTTPUpgrade, XHTTP).
// Customizes path, host, gRPC service name, and XHTTP modes based on the selected protocol.
// Implements reactive updates corresponding to network transport selection changes.

import 'package:flutter/material.dart';
import '../../core/l10n/translations.dart';
import '../../models/proxy_node.dart';

/// Tab for configuring proxy node transport layer and network protocol.
///
/// Manages core protocol type (VLESS, VMess, Trojan, Shadowsocks),
/// network transport stream, and protocol-specific parameters such as path and host.
class TransportTab extends StatelessWidget {
  final ProtocolType selectedProtocol;
  final NetworkType selectedNetwork;
  final TextEditingController pathController;
  final TextEditingController hostController;
  final TextEditingController serviceNameController;
  final bool grpcMultiMode;
  final String? selectedHeaderType;
  final String? selectedXhttpMode;
  final TextEditingController xhttpExtraController;
  final List<String> availableHeaderTypes;
  final List<String> availableXhttpModes;
  final String locale;
  final ValueChanged<ProtocolType?> onProtocolChanged;
  final ValueChanged<NetworkType?> onNetworkChanged;
  final ValueChanged<bool> onGrpcMultiModeChanged;
  final ValueChanged<String?> onHeaderTypeChanged;
  final ValueChanged<String?> onXhttpModeChanged;

  const TransportTab({
    super.key,
    required this.selectedProtocol,
    required this.selectedNetwork,
    required this.pathController,
    required this.hostController,
    required this.serviceNameController,
    required this.grpcMultiMode,
    required this.selectedHeaderType,
    required this.selectedXhttpMode,
    required this.xhttpExtraController,
    required this.availableHeaderTypes,
    required this.availableXhttpModes,
    required this.locale,
    required this.onProtocolChanged,
    required this.onNetworkChanged,
    required this.onGrpcMultiModeChanged,
    required this.onHeaderTypeChanged,
    required this.onXhttpModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ProtocolType>(
                  value: selectedProtocol,
                  decoration: InputDecoration(
                    labelText: AppStrings.get('protocol', locale: locale),
                    prefixIcon: const Icon(Icons.layers_rounded, size: 20),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: ProtocolType.values
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p.name.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: onProtocolChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<NetworkType>(
                  value: selectedNetwork,
                  decoration: InputDecoration(
                    labelText: AppStrings.get('transport_network', locale: locale),
                    prefixIcon: const Icon(Icons.router_rounded, size: 20),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: NetworkType.values
                      .map((n) => DropdownMenuItem(
                            value: n,
                            child: Text(n.name.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: onNetworkChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (selectedNetwork == NetworkType.ws ||
              selectedNetwork == NetworkType.httpUpgrade ||
              selectedNetwork == NetworkType.h2) ...[
            TextField(
              controller: pathController,
              decoration: const InputDecoration(
                labelText: 'Path (e.g. / or /ws)',
                prefixIcon: Icon(Icons.alt_route_rounded, size: 20),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hostController,
              decoration: const InputDecoration(
                labelText: 'Host header (e.g. cdn.example.com)',
                prefixIcon: Icon(Icons.language_rounded, size: 20),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ] else if (selectedNetwork == NetworkType.grpc) ...[
            TextField(
              controller: serviceNameController,
              decoration: InputDecoration(
                labelText: AppStrings.get('service_name', locale: locale),
                hintText: 'e.g. v2ray-grpc',
                prefixIcon: const Icon(Icons.cloud_sync_rounded, size: 20),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(AppStrings.get('multi_mode', locale: locale)),
              value: grpcMultiMode,
              onChanged: (val) => onGrpcMultiModeChanged(val),
            ),
          ] else if (selectedNetwork == NetworkType.xhttp || selectedNetwork == NetworkType.splithttp) ...[
            TextField(
              controller: pathController,
              decoration: const InputDecoration(
                labelText: 'Path (e.g. /xhttp)',
                prefixIcon: Icon(Icons.alt_route_rounded, size: 20),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hostController,
              decoration: const InputDecoration(
                labelText: 'Host header',
                prefixIcon: Icon(Icons.language_rounded, size: 20),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedXhttpMode,
              decoration: InputDecoration(
                labelText: AppStrings.get('xhttp_mode', locale: locale),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: availableXhttpModes
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: onXhttpModeChanged,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: xhttpExtraController,
              decoration: InputDecoration(
                labelText: AppStrings.get('xhttp_extra', locale: locale),
                hintText: '{"noSSEHeader": false}',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ] else if (selectedNetwork == NetworkType.tcp) ...[
            DropdownButtonFormField<String>(
              value: selectedHeaderType,
              decoration: InputDecoration(
                labelText: AppStrings.get('header_type', locale: locale),
                prefixIcon: const Icon(Icons.code_rounded, size: 20),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: availableHeaderTypes
                  .map((h) => DropdownMenuItem(value: h, child: Text(h.toUpperCase())))
                  .toList(),
              onChanged: onHeaderTypeChanged,
            ),
            if (selectedHeaderType == 'http') ...[
              const SizedBox(height: 12),
              TextField(
                controller: pathController,
                decoration: const InputDecoration(
                  labelText: 'HTTP Request Path (e.g. /)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hostController,
                decoration: const InputDecoration(
                  labelText: 'HTTP Host Header',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
