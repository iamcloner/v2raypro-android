// CDN IP Ranges & Host Detection Providers
// Manages CDN IP ranges (Cloudflare and other CDN providers) and CDN host detection.
// Supports saving, loading, and updating custom CIDR lists used for scanner operations.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/proxy_node.dart';
import '../services/cdn_scanner_service.dart';
import '../services/storage_service.dart';

/// Manages CIDR IP ranges for all supported CDN providers.
class CdnRangesNotifier extends StateNotifier<Map<CdnProvider, List<String>>> {
  /// Initializes with default ranges for each provider and loads custom values.
  CdnRangesNotifier() : super({
    for (final p in CdnProvider.values) p: p.defaultCidrs,
  }) {
    _init();
  }

  Future<void> _init() async {
    final map = <CdnProvider, List<String>>{};
    for (final p in CdnProvider.values) {
      final saved = await StorageService.instance.loadCdnRanges(p);
      map[p] = saved.isNotEmpty ? saved : p.defaultCidrs;
    }
    if (mounted) state = map;
  }

  /// Updates IP ranges for a specific CDN and persists them to local storage.
  void updateRanges(CdnProvider provider, List<String> ranges) {
    state = {...state, provider: ranges};
    StorageService.instance.saveCdnRanges(provider, ranges);
  }

  /// Resets IP ranges for a specific CDN to default values.
  void resetToDefault(CdnProvider provider) {
    state = {...state, provider: provider.defaultCidrs};
    StorageService.instance.saveCdnRanges(provider, provider.defaultCidrs);
  }
}

/// Riverpod provider for accessing the CDN ranges map.
final cdnRangesProvider = StateNotifierProvider<CdnRangesNotifier, Map<CdnProvider, List<String>>>((ref) {
  return CdnRangesNotifier();
});

/// Manages Cloudflare IP ranges with direct synchronization with CdnRangesNotifier.
class CloudflareRangesNotifier extends StateNotifier<List<String>> {
  final Ref ref;

  /// Initializes with default Cloudflare IP ranges.
  CloudflareRangesNotifier(this.ref) : super(CdnProvider.cloudflare.defaultCidrs) {
    _init();
  }

  Future<void> _init() async {
    final saved = await StorageService.instance.loadCloudflareRanges();
    if (mounted && saved.isNotEmpty) {
      state = saved;
    }
  }

  /// Updates Cloudflare IP ranges.
  void updateRanges(List<String> ranges) {
    state = ranges;
    ref.read(cdnRangesProvider.notifier).updateRanges(CdnProvider.cloudflare, ranges);
  }

  /// Resets to default Cloudflare IP ranges.
  void resetToDefault() {
    state = CdnProvider.cloudflare.defaultCidrs;
    ref.read(cdnRangesProvider.notifier).resetToDefault(CdnProvider.cloudflare);
  }
}

/// Riverpod provider for accessing the list of Cloudflare IP ranges.
final cfRangesProvider = StateNotifierProvider<CloudflareRangesNotifier, List<String>>((ref) {
  return CloudflareRangesNotifier(ref);
});

/// Detects whether addresses and domains belong to CDN networks.
class NodeCdnDetectionNotifier extends StateNotifier<Map<String, CdnProvider?>> {
  final Ref ref;
  final Map<String, CdnProvider?> _syncCache = {};

  /// Initializes the CDN detection notifier.
  NodeCdnDetectionNotifier(this.ref) : super({});

  /// Detects CDN provider type for a raw address synchronously with async fallback.
  CdnProvider? detectCdn(String rawAddress) {
    final addr = rawAddress.trim().toLowerCase();
    if (addr.isEmpty) return null;
    if (state.containsKey(addr)) return state[addr];
    if (_syncCache.containsKey(addr)) return _syncCache[addr];

    final cdnRanges = ref.read(cdnRangesProvider);
    final syncMatch = CdnScannerService.detectCdnHostSync(addr, cdnRanges);
    _syncCache[addr] = syncMatch;

    final isIp = addr.contains(RegExp(r'^\d+\.\d+\.\d+\.\d+$')) || addr.contains(':');
    if (syncMatch == null && !isIp) {
      Future.microtask(() => checkDomainCdn(addr));
    }

    Future.microtask(() {
      if (mounted && !state.containsKey(addr)) {
        state = {...state, addr: syncMatch};
      }
    });

    return syncMatch;
  }

  /// Detects CDN provider based on node details including address, host, and SNI.
  CdnProvider? detectCdnForNode(ProxyNode node) {
    final byAddr = detectCdn(node.address);
    if (byAddr != null) return byAddr;

    if (node.host != null && node.host!.trim().isNotEmpty) {
      final byHost = detectCdn(node.host!);
      if (byHost != null) return byHost;
    }

    if (node.sni != null && node.sni!.trim().isNotEmpty) {
      final bySni = detectCdn(node.sni!);
      if (bySni != null) return bySni;
    }

    return null;
  }

  /// Asynchronously checks DNS resolution to detect CDN behind a domain.
  Future<CdnProvider?> checkDomainCdn(String domain) async {
    final addr = domain.trim().toLowerCase();
    if (addr.isEmpty) return null;
    final cdnRanges = ref.read(cdnRangesProvider);
    final resolved = await CdnScannerService.detectCdnFromHost(addr, cdnRanges);
    if (resolved != null && mounted) {
      _syncCache[addr] = resolved;
      state = {...state, addr: resolved};
      ref.read(cfCheckedHostsProvider.notifier).markCdn(addr, true);
    }
    return resolved;
  }
}

/// Riverpod provider for the node CDN detection map.
final nodeCdnMapProvider = StateNotifierProvider<NodeCdnDetectionNotifier, Map<String, CdnProvider?>>((ref) {
  return NodeCdnDetectionNotifier(ref);
});

/// Caches Cloudflare check status for addresses.
class CfCheckedHostsNotifier extends StateNotifier<Map<String, bool>> {
  final Ref ref;
  final Map<String, bool> _syncCache = {};

  /// Initializes the host check cache.
  CfCheckedHostsNotifier(this.ref) : super({});

  /// Marks an address as CDN or non-CDN.
  void markCdn(String addr, bool isCdn) {
    final key = addr.trim().toLowerCase();
    _syncCache[key] = isCdn;
    if (mounted) {
      state = {...state, key: isCdn};
    }
  }

  /// Checks whether an address belongs to Cloudflare.
  bool isCloudflare(String address) {
    final addr = address.trim().toLowerCase();
    if (state.containsKey(addr)) return state[addr]!;
    if (_syncCache.containsKey(addr)) return _syncCache[addr]!;

    final cdn = ref.read(nodeCdnMapProvider.notifier).detectCdn(addr);
    final isSupported = cdn != null;
    _syncCache[addr] = isSupported;

    Future.microtask(() {
      if (mounted && !state.containsKey(addr)) {
        state = {...state, addr: isSupported};
      }
    });

    return isSupported;
  }
}

/// Riverpod provider for the Cloudflare checked hosts cache map.
final cfCheckedHostsProvider = StateNotifierProvider<CfCheckedHostsNotifier, Map<String, bool>>((ref) {
  return CfCheckedHostsNotifier(ref);
});
