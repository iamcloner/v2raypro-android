// File: lib/models/update_info.dart
// Description: Data model holding application and core update information.
// Stores current version, latest available version, download URL, and release notes.

/// Version inspection and update metadata model.
class UpdateInfo {
  /// Currently installed application version on the device.
  final String currentVersion;

  /// Latest published version available in the remote repository.
  final String latestVersion;

  /// Indicates whether a newer version is available.
  final bool hasUpdate;

  /// Direct download URL for the update package (e.g., APK artifact).
  final String? downloadUrl;

  /// Release notes and changelog description for the newer version.
  final String? releaseNotes;

  /// Creates an update information instance.
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    this.downloadUrl,
    this.releaseNotes,
  });
}
