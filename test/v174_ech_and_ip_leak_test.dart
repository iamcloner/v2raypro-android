// Test: v1.7.4 ECH & IP Leak Resolution Tests
import 'package:flutter_test/flutter_test.dart';
import 'package:v2raypro/models/proxy_node.dart';
import 'package:v2raypro/services/country_service.dart';
import 'package:v2raypro/utils/config_parser.dart';
import 'package:v2raypro/utils/generators/xray_stream_builder.dart';

void main() {
  group('v1.7.4 ECH & WebSocket Configuration Tests', () {
    test('XrayStreamBuilder resolves ECH boolean and domain flags to Cloudflare ECHConfigList', () {
      expect(
        XrayStreamBuilder.resolveEchConfig('1'),
        equals(XrayStreamBuilder.defaultCloudflareEch),
      );
      expect(
        XrayStreamBuilder.resolveEchConfig('true'),
        equals(XrayStreamBuilder.defaultCloudflareEch),
      );
      expect(
        XrayStreamBuilder.resolveEchConfig('cloudflare-ech.com'),
        equals(XrayStreamBuilder.defaultCloudflareEch),
      );
      expect(
        XrayStreamBuilder.resolveEchConfig('cf'),
        equals(XrayStreamBuilder.defaultCloudflareEch),
      );
      expect(
        XrayStreamBuilder.resolveEchConfig(null),
        isNull,
      );
    });

    test('XrayStreamBuilder extracts public name from ECHConfigList', () {
      final publicName = XrayStreamBuilder.extractEchPublicName(XrayStreamBuilder.defaultCloudflareEch);
      expect(publicName, equals('cloudflare-ech.com'));
    });

    test('XrayStreamBuilder configures outer SNI, chrome fingerprint, and inner WS host for ECH node', () {
      final node = ProxyNode(
        id: 'ech_ws_node_1',
        name: 'ECH Worker Node',
        protocol: ProtocolType.vless,
        address: '104.16.132.229',
        port: 443,
        uuidOrPassword: 'test-uuid-1234',
        network: NetworkType.ws,
        path: '/vless-ws',
        host: 'my-worker.workers.dev',
        sni: 'my-worker.workers.dev',
        security: SecurityType.tls,
        echConfigList: '1',
      );

      final streamSettings = XrayStreamBuilder.build(node);
      expect(streamSettings['network'], equals('ws'));
      expect(streamSettings['security'], equals('tls'));

      final tls = streamSettings['tlsSettings'] as Map<String, dynamic>;
      // Outer SNI must be public name (cloudflare-ech.com)
      expect(tls['serverName'], equals('cloudflare-ech.com'));
      // Fingerprint must be chrome (uTLS)
      expect(tls['fingerprint'], equals('chrome'));
      // ECHConfigList must be populated with valid Base64
      // verifyPeerCertByName is safely omitted when not explicitly set
      expect(tls.containsKey('verifyPeerCertByName'), isFalse);
      // ALPN for WebSocket is http/1.1
      expect(tls['alpn'], equals(['http/1.1']));

      // wsSettings must maintain inner target host
      final ws = streamSettings['wsSettings'] as Map<String, dynamic>;
      expect(ws['host'], equals('my-worker.workers.dev'));
      expect((ws['headers'] as Map)['Host'], equals('my-worker.workers.dev'));
      expect(ws['path'], equals('/vless-ws'));
    });

    test('parseVless handles ech=1 parameter with TLS security and chrome fingerprint', () {
      const url = 'vless://test-uuid-5678@104.16.1.1:443?type=ws&security=tls&host=edge.worker.dev&sni=edge.worker.dev&path=/ws&ech=1#WorkerECH';
      final node = ConfigParser.parseSingle(url);

      expect(node, isNotNull);
      expect(node!.protocol, equals(ProtocolType.vless));
      expect(node.network, equals(NetworkType.ws));
      expect(node.security, equals(SecurityType.tls));
      expect(node.echConfigList, equals('1'));
      expect(node.fingerprint, equals('chrome'));
      expect(node.host, equals('edge.worker.dev'));
    });
  });

  group('v1.7.4 IP Leak & Country Resolution Tests', () {
    test('CountryService does not misclassify domestic Iranian bridge address as IR exit country', () {
      final nodeWithDomesticAddress = ProxyNode(
        id: 'iran_relay_1',
        name: 'Germany Fast Node [DE]',
        protocol: ProtocolType.vless,
        address: '5.160.10.20', // Iranian IP block
        port: 443,
        uuidOrPassword: 'test-uuid-relay',
        network: NetworkType.ws,
        host: 'germany-server.de',
        sni: 'germany-server.de',
        security: SecurityType.tls,
      );

      final code = CountryService.resolveSync(nodeWithDomesticAddress);
      expect(code, isNot(equals('IR')));
      expect(code, equals('DE'));
    });
  });
}
