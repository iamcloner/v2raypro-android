// Config Form Constants
// Defines supported options and dropdown choices for manual proxy configuration.
// Includes TLS fingerprints, encryption ciphers, flow protocols, and transport modes.
// Shared across form tabs and validators.

/// Configuration constants and allowed options for proxy editor fields.
/// Maintains allowed choices for flows, ciphers, fingerprints, and XHTTP modes.
abstract class ConfigFormConstants {
  static const List<String> availableFlows = [
    '',
    'xtls-rprx-vision',
    'xtls-rprx-vision-udp443',
  ];

  static const List<String> availableCiphers = [
    'auto',
    'none',
    'zero',
    'aes-128-gcm',
    'aes-256-gcm',
    'chacha20-poly1305',
    '2022-blake3-aes-128-gcm',
    '2022-blake3-aes-256-gcm',
    '2022-blake3-chacha20-poly1305',
  ];

  static const List<String> availableFingerprints = [
    'chrome',
    'firefox',
    'safari',
    'ios',
    'android',
    'edge',
    '360',
    'qq',
    'random',
    'randomized',
  ];

  static const List<String> availableXhttpModes = [
    'auto',
    'packet-up',
    'stream-up',
    'stream-one',
  ];

  static const List<String> availableHeaderTypes = [
    'none',
    'http',
  ];
}
