// File: lib/widgets/config_form/tls_tab.dart
// Description: Security settings tab for TLS, Reality, and certificate pinning in config editor.
// Manages SNI, uTLS fingerprint, public key, ShortId, and ECH settings.
// Designed according to modern security standards and optimized for Android.

import 'package:flutter/material.dart';
import '../../core/l10n/translations.dart';
import '../../models/proxy_node.dart';

/// Tab for configuring TLS and Reality security settings for anti-censorship.
///
/// Manages security mode (None, TLS, Reality), SNI domain name,
/// browser fingerprint, Reality public key, and certificate pinning.
class TlsTab extends StatelessWidget {
  final SecurityType selectedSecurity;
  final TextEditingController sniController;
  final String? selectedFingerprint;
  final TextEditingController alpnController;
  final bool allowInsecure;
  final TextEditingController echConfigListController;
  final TextEditingController verifyPeerCertByNameController;
  final TextEditingController certificatePinningController;
  final TextEditingController publicKeyController;
  final TextEditingController shortIdController;
  final TextEditingController spiderXController;
  final List<String> availableFingerprints;
  final String locale;
  final ValueChanged<SecurityType?> onSecurityChanged;
  final ValueChanged<String?> onFingerprintChanged;
  final ValueChanged<bool> onAllowInsecureChanged;

  const TlsTab({
    super.key,
    required this.selectedSecurity,
    required this.sniController,
    required this.selectedFingerprint,
    required this.alpnController,
    required this.allowInsecure,
    required this.echConfigListController,
    required this.verifyPeerCertByNameController,
    required this.certificatePinningController,
    required this.publicKeyController,
    required this.shortIdController,
    required this.spiderXController,
    required this.availableFingerprints,
    required this.locale,
    required this.onSecurityChanged,
    required this.onFingerprintChanged,
    required this.onAllowInsecureChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<SecurityType>(
            value: selectedSecurity,
            decoration: InputDecoration(
              labelText: AppStrings.get('tls_mode', locale: locale),
              prefixIcon: const Icon(Icons.shield_outlined, size: 20),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: SecurityType.values
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.name.toUpperCase()),
                    ))
                .toList(),
            onChanged: onSecurityChanged,
          ),
          const SizedBox(height: 16),
          if (selectedSecurity == SecurityType.none)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppStrings.get('tls_none_hint', locale: locale),
                      style: const TextStyle(fontSize: 12, color: Colors.amber),
                    ),
                  ),
                ],
              ),
            ),
          if (selectedSecurity == SecurityType.tls) ...[
            TextField(
              controller: sniController,
              decoration: InputDecoration(
                labelText: AppStrings.get('sni_servername', locale: locale),
                hintText: 'e.g. example.com',
                prefixIcon: const Icon(Icons.link_rounded, size: 20),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: availableFingerprints.contains(selectedFingerprint) ? selectedFingerprint : 'chrome',
                    decoration: InputDecoration(
                      labelText: AppStrings.get('fingerprint', locale: locale),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: availableFingerprints
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: onFingerprintChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: alpnController,
                    decoration: InputDecoration(
                      labelText: AppStrings.get('alpn', locale: locale),
                      hintText: 'h2,http/1.1',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                AppStrings.get('allow_insecure', locale: locale),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                AppStrings.get('allow_insecure_desc', locale: locale),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
              value: allowInsecure,
              onChanged: onAllowInsecureChanged,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: echConfigListController,
              decoration: InputDecoration(
                labelText: AppStrings.get('ech_config_list', locale: locale),
                hintText: 'Base64 encoded ECH configs',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: verifyPeerCertByNameController,
              decoration: InputDecoration(
                labelText: AppStrings.get('verify_peer_cert', locale: locale),
                hintText: 'Expected certificate subject name',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: certificatePinningController,
              decoration: InputDecoration(
                labelText: AppStrings.get('cert_pinning', locale: locale),
                hintText: 'SHA-256 public key hash',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
          if (selectedSecurity == SecurityType.reality) ...[
            TextField(
              controller: sniController,
              decoration: InputDecoration(
                labelText: AppStrings.get('sni_servername', locale: locale),
                hintText: 'e.g. play.google.com, yahoo.com',
                prefixIcon: const Icon(Icons.link_rounded, size: 20),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: availableFingerprints.contains(selectedFingerprint) ? selectedFingerprint : 'chrome',
                    decoration: InputDecoration(
                      labelText: AppStrings.get('fingerprint', locale: locale),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: availableFingerprints
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: onFingerprintChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: spiderXController,
                    decoration: InputDecoration(
                      labelText: AppStrings.get('spider_x', locale: locale),
                      hintText: '/',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: publicKeyController,
              decoration: InputDecoration(
                labelText: AppStrings.get('public_key', locale: locale),
                hintText: 'Reality Public Key (pbk)',
                prefixIcon: const Icon(Icons.vpn_key_rounded, size: 20),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: shortIdController,
              decoration: InputDecoration(
                labelText: AppStrings.get('short_id', locale: locale),
                hintText: 'Reality Short ID (sid)',
                prefixIcon: const Icon(Icons.fingerprint_rounded, size: 20),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
