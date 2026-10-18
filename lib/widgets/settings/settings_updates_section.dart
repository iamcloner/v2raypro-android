// Settings Updates Center Section
// Manages automated and manual OTA updates for GeoIP/GeoSite assets,
// Xray core binaries, and application APK releases on Android devices.
// Includes progress indicators and download failure recovery.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/translations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../services/update_service.dart';

/// Core and application update center section widget.
/// Manages downloading the latest Geo files, Xray core binaries, and Android APK releases.
class SettingsUpdatesSection extends ConsumerStatefulWidget {
  final String locale;

  /// Creates the update center section.
  const SettingsUpdatesSection({
    super.key,
    required this.locale,
  });

  @override
  ConsumerState<SettingsUpdatesSection> createState() => _SettingsUpdatesSectionState();
}

class _SettingsUpdatesSectionState extends ConsumerState<SettingsUpdatesSection> {
  bool _geoUpdating = false;
  double _geoProgress = 0.0;
  String? _geoStatusMsg;

  bool _xrayChecking = false;
  bool _xrayUpdating = false;
  double _xrayProgress = 0.0;
  UpdateInfo? _xrayInfo;
  String? _xrayStatusMsg;

  bool _appChecking = false;
  bool _appUpdating = false;
  double _appProgress = 0.0;
  UpdateInfo? _appInfo;
  String? _appStatusMsg;

  bool _updatingAll = false;
  String? _updateAllStatusMsg;

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildUpdateAllHeader(locale),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            _buildGeoUpdateTile(locale),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildXrayUpdateTile(locale),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildAppUpdateTile(locale),
          ],
        ),
      ),
    );
  }

  /// Builds header row and bulk check/download button for all updates.
  Widget _buildUpdateAllHeader(String locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.sync_rounded, color: AppTheme.primaryAccent, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppStrings.get('update_all_title', locale: locale),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              icon: _updatingAll
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_rounded, size: 16),
              label: Text(
                _updatingAll ? AppStrings.get('updating', locale: locale) : AppStrings.get('update_all_btn', locale: locale),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: _updatingAll ? null : _handleUpdateAll,
            ),
          ],
        ),
        if (_updateAllStatusMsg != null) ...[
          const SizedBox(height: 6),
          Text(_updateAllStatusMsg!, style: const TextStyle(fontSize: 11, color: Colors.cyanAccent)),
        ],
      ],
    );
  }

  /// Builds tile for updating geographic databases (GeoIP and GeoSite).
  Widget _buildGeoUpdateTile(String locale) {
    return Row(
      children: [
        const Icon(Icons.public_rounded, size: 20, color: Colors.tealAccent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppStrings.get('geo_assets_title', locale: locale), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(_geoStatusMsg ?? AppStrings.get('geo_assets_desc', locale: locale), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              if (_geoUpdating) ...[
                const SizedBox(height: 4),
                LinearProgressIndicator(value: _geoProgress > 0 ? _geoProgress : null, minHeight: 4),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: _geoUpdating ? null : _handleGeoUpdate,
          child: Text(_geoUpdating ? '...' : AppStrings.get('update_now', locale: locale), style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  /// Builds tile for checking and updating Xray core.
  Widget _buildXrayUpdateTile(String locale) {
    return Row(
      children: [
        const Icon(Icons.memory_rounded, size: 20, color: Colors.purpleAccent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Xray Core', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(_xrayStatusMsg ?? 'Core Engine binary', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              if (_xrayUpdating) ...[
                const SizedBox(height: 4),
                LinearProgressIndicator(value: _xrayProgress > 0 ? _xrayProgress : null, minHeight: 4),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: (_xrayChecking || _xrayUpdating) ? null : _handleXrayUpdate,
          child: Text((_xrayChecking || _xrayUpdating) ? '...' : AppStrings.get('check_update', locale: locale), style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  /// Builds tile for updating the Android application APK.
  Widget _buildAppUpdateTile(String locale) {
    return Row(
      children: [
        const Icon(Icons.system_update_rounded, size: 20, color: Colors.orangeAccent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppStrings.get('app_update_title', locale: locale), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(_appStatusMsg ?? 'v${UpdateService.currentAppVersion}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              if (_appUpdating) ...[
                const SizedBox(height: 4),
                LinearProgressIndicator(value: _appProgress > 0 ? _appProgress : null, minHeight: 4),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: (_appChecking || _appUpdating) ? null : _handleAppUpdate,
          child: Text((_appChecking || _appUpdating) ? '...' : AppStrings.get('check_update', locale: locale), style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  /// Simultaneously executes updates for Geo assets, Xray core, and Android APK.
  Future<void> _handleUpdateAll() async {
    if (_updatingAll || _xrayUpdating || _geoUpdating || _appUpdating) return;
    setState(() {
      _updatingAll = true;
      _updateAllStatusMsg = AppStrings.get('updating', locale: widget.locale);
    });

    try {
      await _handleGeoUpdate();
      await _handleXrayUpdate();
      await _handleAppUpdate();
      if (mounted) {
        setState(() {
          _updatingAll = false;
          _updateAllStatusMsg = widget.locale == 'fa' ? 'تمام به‌روزرسانی‌ها بررسی شدند.' : 'All updates checked.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _updatingAll = false;
          _updateAllStatusMsg = 'Error: $e';
        });
      }
    }
  }

  /// Updates geographic database assets.
  Future<void> _handleGeoUpdate() async {
    setState(() {
      _geoUpdating = true;
      _geoProgress = 0.0;
      _geoStatusMsg = 'Downloading Geo files...';
    });
    try {
      final success = await UpdateService.instance.updateGeoFiles(
        onProgress: (p) {
          if (mounted) setState(() => _geoProgress = p);
        },
      );
      if (mounted) {
        setState(() {
          _geoUpdating = false;
          _geoStatusMsg = success ? 'Geo files updated!' : 'Update failed';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _geoUpdating = false;
          _geoStatusMsg = 'Error: $e';
        });
      }
    }
  }

  /// Checks for and applies Xray core updates.
  Future<void> _handleXrayUpdate() async {
    setState(() {
      _xrayChecking = true;
      _xrayStatusMsg = null;
    });
    try {
      final info = await UpdateService.instance.checkXrayUpdate();
      if (!mounted) return;
      setState(() {
        _xrayInfo = info;
        _xrayChecking = false;
        _xrayStatusMsg = info.hasUpdate ? 'Update available!' : 'Up to date';
      });

      if (info.hasUpdate && info.downloadUrl != null) {
        setState(() {
          _xrayUpdating = true;
          _xrayProgress = 0.0;
          _xrayStatusMsg = 'Downloading...';
        });
        final success = await UpdateService.instance.updateXray(
          info.downloadUrl!,
          onProgress: (p) {
            if (mounted) setState(() => _xrayProgress = p);
          },
        );
        if (mounted) {
          setState(() {
            _xrayUpdating = false;
            _xrayStatusMsg = success ? 'Xray updated!' : 'Failed';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _xrayChecking = false;
          _xrayUpdating = false;
          _xrayStatusMsg = 'Failed: $e';
        });
      }
    }
  }

  /// Checks for and installs Android application updates.
  Future<void> _handleAppUpdate() async {
    setState(() {
      _appChecking = true;
      _appStatusMsg = null;
    });
    try {
      final info = await UpdateService.instance.checkAppUpdate();
      if (!mounted) return;
      setState(() {
        _appInfo = info;
        _appChecking = false;
        _appStatusMsg = info.hasUpdate
            ? (widget.locale == 'fa' ? 'نسخه جدید موجود است' : 'New version available')
            : AppStrings.get('up_to_date', locale: widget.locale);
      });

      if (info.hasUpdate && info.downloadUrl != null) {
        setState(() {
          _appUpdating = true;
          _appProgress = 0.0;
        });
        await UpdateService.instance.downloadAndApplyAppUpdate(
          info.downloadUrl!,
          onProgress: (phase, p) {
            if (mounted) setState(() => _appProgress = p);
          },
        );
        if (mounted) setState(() => _appUpdating = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appChecking = false;
          _appUpdating = false;
          _appStatusMsg = 'Error: $e';
        });
      }
    }
  }
}
