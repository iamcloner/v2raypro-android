// Settings Core & Network Section
// Configures proxy connection mode (TUN Whole-Device VPN vs Local Proxy Ports),
// UDP forwarding, insecure TLS verification bypass, multiplexing (Mux), and local LAN sharing.
// Built specifically for Android network interfaces.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import 'settings_ports_card.dart';

/// Core network and proxy settings section widget.
/// Configures connection mode (TUN or local proxy), port forwarding, UDP, Mux, and LAN sharing.
class SettingsNetworkSection extends ConsumerWidget {
  final String locale;

  /// Creates the core and network settings section.
  const SettingsNetworkSection({
    super.key,
    required this.locale,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTun = ref.watch(isTunEnabledProvider);
    final enableUdp = ref.watch(enableUdpProvider);
    final globalAllowInsecure = ref.watch(globalAllowInsecureProvider);
    final globalEnableMux = ref.watch(globalEnableMuxProvider);
    final allowLan = ref.watch(allowLanProvider);

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.hub_rounded, color: AppTheme.primaryAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      locale == 'fa' ? 'حالت اتصال' : 'Connection Mode',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildModeChip(
                        context: context,
                        label: locale == 'fa' ? 'وی‌پی‌ان (TUN)' : 'TUN (VPN)',
                        desc: locale == 'fa' ? 'کل دستگاه' : 'Whole Device',
                        icon: Icons.vpn_lock_rounded,
                        isSelected: isTun,
                        onTap: () {
                          ref.read(isTunEnabledProvider.notifier).toggle(true);
                          ref.read(autoEnableTunOnConnectProvider.notifier).toggle(true);
                          _reconnectIfActive(ref);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildModeChip(
                        context: context,
                        label: locale == 'fa' ? 'پروکسی (Proxy)' : 'Proxy Mode',
                        desc: locale == 'fa' ? 'پورت محلی' : 'Local Inbound',
                        icon: Icons.settings_ethernet_rounded,
                        isSelected: !isTun,
                        onTap: () {
                          ref.read(isTunEnabledProvider.notifier).toggle(false);
                          ref.read(autoEnableTunOnConnectProvider.notifier).toggle(false);
                          _reconnectIfActive(ref);
                        },
                      ),
                    ),
                  ],
                ),
                if (!isTun) ...[
                  const SizedBox(height: 10),
                  SettingsPortsCard(locale: locale),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.compare_arrows_rounded, color: Colors.tealAccent),
            title: Text(
              AppStrings.get('enable_udp', locale: locale),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              AppStrings.get('enable_udp_desc', locale: locale),
              style: const TextStyle(fontSize: 10.5, color: Colors.grey),
            ),
            value: enableUdp,
            onChanged: (val) => ref.read(enableUdpProvider.notifier).toggle(val),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.security_update_warning_rounded, color: Colors.orangeAccent),
            title: Text(
              AppStrings.get('global_allow_insecure', locale: locale),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              AppStrings.get('global_allow_insecure_desc', locale: locale),
              style: const TextStyle(fontSize: 10.5, color: Colors.grey),
            ),
            value: globalAllowInsecure,
            onChanged: (val) => ref.read(globalAllowInsecureProvider.notifier).toggle(val),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.alt_route_rounded, color: Colors.indigoAccent),
            title: Text(
              AppStrings.get('global_enable_mux', locale: locale),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              AppStrings.get('global_enable_mux_desc', locale: locale),
              style: const TextStyle(fontSize: 10.5, color: Colors.grey),
            ),
            value: globalEnableMux,
            onChanged: (val) => ref.read(globalEnableMuxProvider.notifier).toggle(val),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.wifi_tethering_rounded, color: Colors.purpleAccent),
            title: Text(
              AppStrings.get('allow_lan', locale: locale),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              AppStrings.get('allow_lan_desc', locale: locale),
              style: const TextStyle(fontSize: 10.5, color: Colors.grey),
            ),
            value: allowLan,
            onChanged: (val) => ref.read(allowLanProvider.notifier).toggle(val),
          ),
        ],
      ),
    );
  }

  /// Builds selectable mode chips for VPN (TUN) or Proxy modes.
  Widget _buildModeChip({
    required BuildContext context,
    required String label,
    required String desc,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryAccent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryAccent : Colors.grey.withValues(alpha: 0.25),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppTheme.primaryAccent : Colors.grey,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppTheme.primaryAccent : Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? AppTheme.primaryAccent.withValues(alpha: 0.8) : Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Reconnects the core process if active when settings are updated.
  void _reconnectIfActive(WidgetRef ref) {
    if (ref.read(connectionStatusProvider) == ConnectionStateEnum.connected) {
      ref.read(connectionStatusProvider.notifier).reconnectWithUpdatedSettings();
    }
  }
}
