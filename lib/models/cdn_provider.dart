// File: lib/models/cdn_provider.dart
// Description: CDN provider definitions and CIDR registries.
// Defines supported CDN providers (Cloudflare, Fastly, AWS CloudFront, G-Core, ArvanCloud),
// mapping default CIDR subnets, known domain patterns, and localized display names.

/// Supported CDN providers and configuration metadata.
/// Includes identifiers, display names, default IP ranges, and known domains.
enum CdnProvider {
  cloudflare,
  fastly,
  awsCloudFront,
  gcore,
  arvancloud;

  /// Unique string identifier for the CDN provider.
  String get id {
    switch (this) {
      case CdnProvider.cloudflare:
        return "cloudflare";
      case CdnProvider.fastly:
        return "fastly";
      case CdnProvider.awsCloudFront:
        return "cloudfront";
      case CdnProvider.gcore:
        return "gcore";
      case CdnProvider.arvancloud:
        return "arvancloud";
    }
  }

  /// English display name for the CDN provider.
  String get displayName {
    switch (this) {
      case CdnProvider.cloudflare:
        return "Cloudflare";
      case CdnProvider.fastly:
        return "Fastly";
      case CdnProvider.awsCloudFront:
        return "AWS CloudFront";
      case CdnProvider.gcore:
        return "G-Core";
      case CdnProvider.arvancloud:
        return "ArvanCloud";
    }
  }

  /// Persian display name for the CDN provider in localized UI.
  String get displayNameFa {
    switch (this) {
      case CdnProvider.cloudflare:
        return "کلودفلر";
      case CdnProvider.fastly:
        return "فستلی";
      case CdnProvider.awsCloudFront:
        return "کلودفرانت (AWS)";
      case CdnProvider.gcore:
        return "جی‌کور (G-Core)";
      case CdnProvider.arvancloud:
        return "ابر آروان (ArvanCloud)";
    }
  }

  /// Default CIDR subnets for the CDN provider.
  List<String> get defaultCidrs {
    switch (this) {
      case CdnProvider.cloudflare:
        return const [
          "104.16.0.0/13",
          "104.24.0.0/14",
          "172.64.0.0/13",
          "162.158.0.0/15",
          "198.41.128.0/17",
          "173.245.48.0/20",
          "108.162.192.0/18",
          "190.93.240.0/20",
          "188.114.96.0/20",
          "197.234.240.0/22",
          "141.101.64.0/18",
          "103.21.244.0/22",
          "103.22.200.0/22",
          "103.31.4.0/22",
          "131.0.72.0/22",
          "162.159.0.0/16",
          "1.0.0.0/24",
          "1.1.1.0/24",
          "8.6.112.0/24",
        ];
      case CdnProvider.fastly:
        return const [
          "151.101.0.0/16",
          "199.232.0.0/16",
          "157.52.64.0/18",
          "167.82.0.0/17",
          "146.75.0.0/16",
          "151.106.0.0/16",
          "199.27.72.0/21",
        ];
      case CdnProvider.awsCloudFront:
        return const [
          "13.32.0.0/15",
          "13.35.0.0/16",
          "18.64.0.0/14",
          "18.160.0.0/15",
          "52.84.0.0/15",
          "54.192.0.0/16",
          "54.230.0.0/16",
          "54.239.128.0/18",
          "54.239.192.0/19",
          "54.240.128.0/18",
          "64.252.64.0/18",
          "65.8.0.0/16",
          "65.9.0.0/17",
          "99.84.0.0/16",
          "99.86.0.0/16",
          "143.204.0.0/16",
          "204.246.164.0/22",
          "205.251.192.0/19",
        ];
      case CdnProvider.gcore:
        return const [
          "92.223.64.0/18",
          "92.38.128.0/17",
          "92.223.0.0/18",
          "146.185.128.0/19",
          "188.114.128.0/19",
          "194.26.28.0/22",
          "195.123.208.0/20",
          "5.188.120.0/21",
        ];
      case CdnProvider.arvancloud:
        return const [
          "185.143.232.0/22",
          "94.182.152.0/21",
          "188.114.86.0/24",
          "185.228.238.0/23",
          "185.231.112.0/22",
          "188.121.96.0/22",
          "89.39.208.0/21",
          "185.211.56.0/22",
          "185.215.232.0/22",
        ];
    }
  }

  /// Well-known domains and host patterns associated with the CDN provider.
  List<String> get wellKnownDomains {
    switch (this) {
      case CdnProvider.cloudflare:
        return const [
          "cloudflare.com",
          ".cloudflare.com",
          "workers.dev",
          ".workers.dev",
          "pages.dev",
          ".pages.dev",
          ".cfargotunnel.com",
        ];
      case CdnProvider.fastly:
        return const [
          "fastly.net",
          ".fastly.net",
          "fastlylb.net",
          ".fastlylb.net",
        ];
      case CdnProvider.awsCloudFront:
        return const [
          "cloudfront.net",
          ".cloudfront.net",
          "amazonaws.com",
          ".amazonaws.com",
        ];
      case CdnProvider.gcore:
        return const [
          "gcore.com",
          ".gcore.com",
          "gcore.lu",
          ".gcore.lu",
          "gcdn.co",
          ".gcdn.co",
        ];
      case CdnProvider.arvancloud:
        return const [
          "arvancloud.ir",
          ".arvancloud.ir",
          "arvancloud.com",
          ".arvancloud.com",
          "arvancdn.ir",
          ".arvancdn.ir",
        ];
    }
  }
}
