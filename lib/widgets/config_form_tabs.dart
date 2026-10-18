// File: lib/widgets/config_form_tabs.dart
// Description: Main tabbed form for creating and manually editing proxy configurations on Android.
// Manages input fields and connects the controllers of each individual tab.
// Includes Basic Info, Credentials & Encryption, Transport Layer, and TLS/Reality Security tabs.

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/l10n/translations.dart';
import '../core/theme/app_theme.dart';
import '../models/proxy_node.dart';
import 'config_form/basic_tab.dart';
import 'config_form/config_form_constants.dart';
import 'config_form/encryption_tab.dart';
import 'config_form/tls_tab.dart';
import 'config_form/transport_tab.dart';

/// Tabbed form widget for manually creating or editing a proxy node configuration.
///
/// Collects basic info, credentials, transport layer, and security settings across dedicated tabs
/// to construct a complete [ProxyNode] object.
class ConfigFormTabs extends StatefulWidget {
  final ProxyNode? initialNode;
  final String locale;

  const ConfigFormTabs({
    super.key,
    this.initialNode,
    required this.locale,
  });

  @override
  ConfigFormTabsState createState() => ConfigFormTabsState();
}

class ConfigFormTabsState extends State<ConfigFormTabs> with SingleTickerProviderStateMixin {
  late TabController tabController;

  // Tab 1 controllers: Basic info
  late TextEditingController nameController;
  late TextEditingController addressController;
  late TextEditingController portController;

  // Tab 2 controllers: Credentials & Encryption
  late TextEditingController uuidController;
  String? selectedFlow;
  late TextEditingController cipherController;
  late bool enableMux;

  // Tab 3 controllers: Transport layer
  late ProtocolType selectedProtocol;
  late NetworkType selectedNetwork;
  late TextEditingController pathController;
  late TextEditingController hostController;
  late TextEditingController serviceNameController;
  late bool grpcMultiMode;
  String? selectedHeaderType;
  String? selectedXhttpMode;
  late TextEditingController xhttpExtraController;

  // Tab 4 controllers: TLS & Reality security
  late SecurityType selectedSecurity;
  late TextEditingController sniController;
  String? selectedFingerprint;
  late TextEditingController alpnController;
  late bool allowInsecure;
  late TextEditingController echConfigListController;
  late TextEditingController verifyPeerCertByNameController;
  late TextEditingController certificatePinningController;
  late TextEditingController publicKeyController;
  late TextEditingController shortIdController;
  late TextEditingController spiderXController;

  static List<String> get availableFlows => ConfigFormConstants.availableFlows;
  static List<String> get availableCiphers => ConfigFormConstants.availableCiphers;
  static List<String> get availableFingerprints => ConfigFormConstants.availableFingerprints;
  static List<String> get availableXhttpModes => ConfigFormConstants.availableXhttpModes;
  static List<String> get availableHeaderTypes => ConfigFormConstants.availableHeaderTypes;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 4, vsync: this);
    final n = widget.initialNode;

    // Tab 1: Basic info
    nameController = TextEditingController(text: n?.name ?? 'Custom Node');
    addressController = TextEditingController(text: n?.address ?? '');
    portController = TextEditingController(text: (n?.port ?? 443).toString());

    // Tab 2: Encryption
    uuidController = TextEditingController(text: n?.uuidOrPassword ?? const Uuid().v4());
    selectedFlow = n?.flow ?? '';
    cipherController = TextEditingController(text: n?.cipher ?? 'auto');
    enableMux = n?.enableMux ?? false;

    // Tab 3: Transport
    selectedProtocol = n?.protocol ?? ProtocolType.vless;
    selectedNetwork = n?.network ?? NetworkType.tcp;
    pathController = TextEditingController(text: n?.path ?? '');
    hostController = TextEditingController(text: n?.host ?? '');
    serviceNameController = TextEditingController(text: n?.serviceName ?? '');
    grpcMultiMode = true;
    selectedHeaderType = (n?.headerType != null && n!.headerType!.isNotEmpty) ? n.headerType! : 'none';
    selectedXhttpMode = (n?.mode != null && n!.mode!.isNotEmpty) ? n.mode! : 'auto';
    xhttpExtraController = TextEditingController(text: n?.extra ?? '');

    // Tab 4: Security
    selectedSecurity = n?.security ?? SecurityType.tls;
    sniController = TextEditingController(text: n?.sni ?? '');
    selectedFingerprint = (n?.fingerprint != null && n!.fingerprint!.isNotEmpty) ? n.fingerprint! : 'chrome';
    alpnController = TextEditingController(text: (n?.alpn != null) ? n!.alpn!.join(',') : 'h2,http/1.1');
    allowInsecure = n?.allowInsecure ?? false;
    echConfigListController = TextEditingController(text: n?.echConfigList ?? '');
    verifyPeerCertByNameController = TextEditingController(text: n?.verifyPeerCertByName ?? '');
    certificatePinningController = TextEditingController(text: n?.certificatePinning ?? '');
    publicKeyController = TextEditingController(text: n?.publicKey ?? '');
    shortIdController = TextEditingController(text: n?.shortId ?? '');
    spiderXController = TextEditingController(text: n?.spiderX ?? '/');
  }

  @override
  void dispose() {
    tabController.dispose();
    nameController.dispose();
    addressController.dispose();
    portController.dispose();
    uuidController.dispose();
    cipherController.dispose();
    pathController.dispose();
    hostController.dispose();
    serviceNameController.dispose();
    xhttpExtraController.dispose();
    sniController.dispose();
    alpnController.dispose();
    echConfigListController.dispose();
    verifyPeerCertByNameController.dispose();
    certificatePinningController.dispose();
    publicKeyController.dispose();
    shortIdController.dispose();
    spiderXController.dispose();
    super.dispose();
  }

  /// Validates user input across required fields.
  String? validate() {
    if (addressController.text.trim().isEmpty) {
      return '${AppStrings.get('server_address', locale: widget.locale)} is required';
    }
    final p = int.tryParse(portController.text.trim());
    if (p == null || p <= 0 || p > 65535) {
      return 'Port must be a valid number between 1 and 65535';
    }
    if (uuidController.text.trim().isEmpty) {
      return '${AppStrings.get('uuid_password', locale: widget.locale)} is required';
    }
    if (selectedSecurity == SecurityType.reality && publicKeyController.text.trim().isEmpty) {
      return 'Reality Public Key (pbk) is required for Reality mode';
    }
    return null;
  }

  /// Constructs the final [ProxyNode] object from the populated form fields.
  ProxyNode buildNode({String? id, bool isActive = false}) {
    final original = widget.initialNode;
    final port = int.tryParse(portController.text.trim()) ?? 443;
    final addr = addressController.text.trim();
    final name = nameController.text.trim().isEmpty ? 'Node-$addr' : nameController.text.trim();

    final alpnRaw = alpnController.text.trim();
    final alpnList = alpnRaw.isNotEmpty
        ? alpnRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
        : null;

    final flowVal = (selectedFlow != null && selectedFlow!.trim().isNotEmpty) ? selectedFlow!.trim() : null;
    final headerTypeVal = (selectedHeaderType != null && selectedHeaderType != 'none') ? selectedHeaderType : null;
    final xhttpModeVal = (selectedXhttpMode != null && selectedXhttpMode != 'auto') ? selectedXhttpMode : null;

    return ProxyNode(
      id: id ?? original?.id ?? const Uuid().v4(),
      name: name,
      protocol: selectedProtocol,
      address: addr,
      port: port,
      uuidOrPassword: uuidController.text.trim(),
      alterId: original?.alterId ?? 0,
      cipher: cipherController.text.trim().isEmpty ? null : cipherController.text.trim(),
      network: selectedNetwork,
      path: pathController.text.trim().isEmpty ? null : pathController.text.trim(),
      host: hostController.text.trim().isEmpty ? null : hostController.text.trim(),
      serviceName: serviceNameController.text.trim().isEmpty ? null : serviceNameController.text.trim(),
      security: selectedSecurity,
      sni: sniController.text.trim().isEmpty ? null : sniController.text.trim(),
      alpn: alpnList,
      allowInsecure: allowInsecure,
      fingerprint: (selectedFingerprint != null && selectedFingerprint!.isNotEmpty) ? selectedFingerprint : null,
      publicKey: publicKeyController.text.trim().isEmpty ? null : publicKeyController.text.trim(),
      shortId: shortIdController.text.trim().isEmpty ? null : shortIdController.text.trim(),
      spiderX: spiderXController.text.trim().isEmpty ? null : spiderXController.text.trim(),
      mode: xhttpModeVal,
      extra: xhttpExtraController.text.trim().isEmpty ? null : xhttpExtraController.text.trim(),
      flow: flowVal,
      headerType: headerTypeVal,
      enableMux: enableMux,
      echConfigList: echConfigListController.text.trim().isEmpty ? null : echConfigListController.text.trim(),
      verifyPeerCertByName: verifyPeerCertByNameController.text.trim().isEmpty ? null : verifyPeerCertByNameController.text.trim(),
      certificatePinning: certificatePinningController.text.trim().isEmpty ? null : certificatePinningController.text.trim(),
      subscriptionId: original?.subscriptionId,
      latencyMs: original?.latencyMs,
      lastTestedAt: original?.lastTestedAt,
      isActive: isActive || (original?.isActive ?? false),
      originalAddress: original?.originalAddress,
      countryCode: original?.countryCode,
      country: original?.country,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.locale;

    return SizedBox(
      width: double.infinity,
      height: 490,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppTheme.primaryAccent,
              unselectedLabelColor: Colors.grey.shade400,
              indicatorColor: AppTheme.primaryAccent,
              indicatorSize: TabBarIndicatorSize.tab,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
              tabs: [
                Tab(
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  text: AppStrings.get('tab_basic_info', locale: loc),
                ),
                Tab(
                  icon: const Icon(Icons.lock_outline_rounded, size: 18),
                  text: AppStrings.get('tab_encryption', locale: loc),
                ),
                Tab(
                  icon: const Icon(Icons.swap_calls_rounded, size: 18),
                  text: AppStrings.get('tab_transport', locale: loc),
                ),
                Tab(
                  icon: const Icon(Icons.security_rounded, size: 18),
                  text: AppStrings.get('tab_tls', locale: loc),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                BasicTab(
                  nameController: nameController,
                  addressController: addressController,
                  portController: portController,
                  locale: loc,
                ),
                EncryptionTab(
                  uuidController: uuidController,
                  selectedFlow: selectedFlow,
                  cipherController: cipherController,
                  enableMux: enableMux,
                  availableFlows: availableFlows,
                  availableCiphers: availableCiphers,
                  locale: loc,
                  onFlowChanged: (val) => setState(() => selectedFlow = val),
                  onMuxChanged: (val) => setState(() => enableMux = val),
                ),
                TransportTab(
                  selectedProtocol: selectedProtocol,
                  selectedNetwork: selectedNetwork,
                  pathController: pathController,
                  hostController: hostController,
                  serviceNameController: serviceNameController,
                  grpcMultiMode: grpcMultiMode,
                  selectedHeaderType: selectedHeaderType,
                  selectedXhttpMode: selectedXhttpMode,
                  xhttpExtraController: xhttpExtraController,
                  availableHeaderTypes: availableHeaderTypes,
                  availableXhttpModes: availableXhttpModes,
                  locale: loc,
                  onProtocolChanged: (val) {
                    if (val != null) setState(() => selectedProtocol = val);
                  },
                  onNetworkChanged: (val) {
                    if (val != null) setState(() => selectedNetwork = val);
                  },
                  onGrpcMultiModeChanged: (val) => setState(() => grpcMultiMode = val),
                  onHeaderTypeChanged: (val) => setState(() => selectedHeaderType = val),
                  onXhttpModeChanged: (val) => setState(() => selectedXhttpMode = val),
                ),
                TlsTab(
                  selectedSecurity: selectedSecurity,
                  sniController: sniController,
                  selectedFingerprint: selectedFingerprint,
                  alpnController: alpnController,
                  allowInsecure: allowInsecure,
                  echConfigListController: echConfigListController,
                  verifyPeerCertByNameController: verifyPeerCertByNameController,
                  certificatePinningController: certificatePinningController,
                  publicKeyController: publicKeyController,
                  shortIdController: shortIdController,
                  spiderXController: spiderXController,
                  availableFingerprints: availableFingerprints,
                  locale: loc,
                  onSecurityChanged: (val) {
                    if (val != null) setState(() => selectedSecurity = val);
                  },
                  onFingerprintChanged: (val) => setState(() => selectedFingerprint = val),
                  onAllowInsecureChanged: (val) => setState(() => allowInsecure = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
