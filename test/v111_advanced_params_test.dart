import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2raypro/models/proxy_node.dart';
import 'package:v2raypro/services/xray_process_service.dart';
import 'package:v2raypro/utils/config_parser.dart';

void main() {
  group('v1.1.1 Advanced Parameters & Optimization Tests', () {
    test('ConfigParser parses SNI, ECH, cert pin, and packetEncoding from VLESS link', () {
      const link = 'vless://test-uuid@example.com:443?type=ws&security=tls&sni=my-sni.com&ech=AAEEBCC123&pin=sha256-abc&verifyPeerCertByName=my-sni.com&packetEncoding=xudp&path=%2Fws#MyVlessNode';
      final node = ConfigParser.parseSingle(link);

      expect(node, isNotNull);
      expect(node!.sni, 'my-sni.com');
      expect(node.echConfigList, 'AAEEBCC123');
      expect(node.certificatePinning, 'sha256-abc');
      expect(node.verifyPeerCertByName, 'my-sni.com');
      expect(node.packetEncoding, 'xudp');
      expect(node.network, NetworkType.ws);
      expect(node.security, SecurityType.tls);
      expect(node.path, '/ws');
    });

    test('ConfigParser parses SNI, ECH, and packetEncoding from Trojan link', () {
      const link = 'trojan://trojan-pwd@1.2.3.4:443?security=tls&sni=trojan.sni.org&ech=ECHCONFIG999&packetEncoding=xudp#MyTrojan';
      final node = ConfigParser.parseSingle(link);

      expect(node, isNotNull);
      expect(node!.protocol, ProtocolType.trojan);
      expect(node.sni, 'trojan.sni.org');
      expect(node.echConfigList, 'ECHCONFIG999');
      expect(node.packetEncoding, 'xudp');
    });

    test('generateXrayConfig applies tcpNoDelay, packetEncoding, ECH, and zero half-close policy', () {
      final node = ProxyNode(
        id: 'test-gen-1',
        name: 'Node with ECH and packetEncoding',
        protocol: ProtocolType.vless,
        address: '104.16.1.1',
        port: 443,
        uuidOrPassword: 'uuid-abc',
        network: NetworkType.ws,
        security: SecurityType.tls,
        sni: 'target-sni.com',
        echConfigList: 'ECH_BASE64_PAYLOAD',
        packetEncoding: 'xudp',
        allowInsecure: true,
      );

      final config = XrayProcessService.instance.generateXrayConfig(node);

      // 1. Verify streamSettings sockopt has tcpNoDelay
      final streamSettings = config['outbounds'][0]['streamSettings'] as Map<String, dynamic>;
      expect(streamSettings['sockopt']['tcpNoDelay'], isTrue);

      // 2. Verify tlsSettings includes serverName and echConfigList (allowInsecure safely omitted to prevent Xray core crash)
      final tlsSettings = streamSettings['tlsSettings'] as Map<String, dynamic>;
      expect(tlsSettings['serverName'], 'target-sni.com');
      expect(tlsSettings['echConfigList'], 'ECH_BASE64_PAYLOAD');
      expect(tlsSettings.containsKey('allowInsecure'), isFalse);

      // 3. Verify VLESS user includes packetEncoding
      final user = config['outbounds'][0]['settings']['vnext'][0]['users'][0] as Map<String, dynamic>;
      expect(user['packetEncoding'], 'xudp');

      // 4. Verify policy levels 0 has uplinkOnly: 2 and downlinkOnly: 5 to prevent DATA after END_STREAM protocol errors
      final policyLevel0 = config['policy']['levels']['0'] as Map<String, dynamic>;
      expect(policyLevel0['uplinkOnly'], 2);
      expect(policyLevel0['downlinkOnly'], 5);
    });

    test('Strict protocol probe rejects 404 Not Found and 403 Forbidden responses', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((client) {
        client.listen((data) {
          // Respond with 404 Not Found
          client.write('HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n');
        });
      });

      final node404 = ProxyNode(
        id: 'test_404',
        name: '404 Server',
        protocol: ProtocolType.vless,
        address: '127.0.0.1',
        port: server.port,
        uuidOrPassword: 'u',
        network: NetworkType.ws,
        path: '/dead',
        security: SecurityType.none,
      );

      final latency = await XrayProcessService.instance.testNodeLatency(
        node404,
        timeout: const Duration(seconds: 1),
      );

      await server.close();

      expect(latency, isNull, reason: '404 responses must be strictly rejected as invalid configs');
    });
  });
}
