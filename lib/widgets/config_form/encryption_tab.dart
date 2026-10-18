// File: lib/widgets/config_form/encryption_tab.dart
// Description: Encryption and authentication settings tab (UUID, Flow, Cipher, and Mux).
// Configures user ID, encryption algorithms, and multiplexing capabilities.
// Includes random UUID generator and standard selectors for modern protocols.

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';

/// Tab for proxy encryption settings, flow control, and server authentication.
///
/// Manages UUID/password, Vision flows, cipher algorithm type,
/// and multiplexing (Mux) configuration.
class EncryptionTab extends StatelessWidget {
  final TextEditingController uuidController;
  final String? selectedFlow;
  final TextEditingController cipherController;
  final bool enableMux;
  final List<String> availableFlows;
  final List<String> availableCiphers;
  final String locale;
  final ValueChanged<String?> onFlowChanged;
  final ValueChanged<bool> onMuxChanged;

  const EncryptionTab({
    super.key,
    required this.uuidController,
    required this.selectedFlow,
    required this.cipherController,
    required this.enableMux,
    required this.availableFlows,
    required this.availableCiphers,
    required this.locale,
    required this.onFlowChanged,
    required this.onMuxChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: uuidController,
            decoration: InputDecoration(
              labelText: AppStrings.get('uuid_password', locale: locale),
              prefixIcon: const Icon(Icons.key_rounded, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                tooltip: 'Generate Random UUID',
                onPressed: () {
                  uuidController.text = const Uuid().v4();
                },
              ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: (selectedFlow != null && availableFlows.contains(selectedFlow)) ? selectedFlow : '',
            decoration: InputDecoration(
              labelText: AppStrings.get('flow', locale: locale),
              prefixIcon: const Icon(Icons.waves_rounded, size: 20),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: '', child: Text('None / Empty')),
              DropdownMenuItem(value: 'xtls-rprx-vision', child: Text('xtls-rprx-vision (Vision)')),
              DropdownMenuItem(value: 'xtls-rprx-vision-udp443', child: Text('xtls-rprx-vision-udp443')),
            ],
            onChanged: onFlowChanged,
          ),
          const SizedBox(height: 16),
          Autocomplete<String>(
            initialValue: TextEditingValue(text: cipherController.text),
            optionsBuilder: (textVal) {
              if (textVal.text.isEmpty) return availableCiphers;
              return availableCiphers.where((c) => c.toLowerCase().contains(textVal.text.toLowerCase()));
            },
            onSelected: (val) {
              cipherController.text = val;
            },
            fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
              controller.addListener(() {
                cipherController.text = controller.text;
              });
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: AppStrings.get('cipher_encryption', locale: locale),
                  prefixIcon: const Icon(Icons.lock_clock_rounded, size: 20),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            secondary: const Icon(Icons.merge_type_rounded, color: AppTheme.primaryAccent),
            title: Text(
              AppStrings.get('enable_mux', locale: locale),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              AppStrings.get('enable_mux_desc', locale: locale),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
            value: enableMux,
            onChanged: onMuxChanged,
          ),
        ],
      ),
    );
  }
}
