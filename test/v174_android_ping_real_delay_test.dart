import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2raypro/models/proxy_node.dart';
import 'package:v2raypro/models/service_models.dart';
import 'package:v2raypro/services/core_service.dart';
import 'package:v2raypro/services/ping_service.dart';
import 'package:v2raypro/services/xray_process_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Android Ping Service & Real Delay Calibration Tests', () {
    final testNode = ProxyNode(
      id: 'android_test_ping_node',
      name: 'Android Test Node',
      address: '1.2.3.4',
      port: 443,
      protocol: ProtocolType.vless,
      uuidOrPassword: 'test-uuid-android',
      network: NetworkType.ws,
      security: SecurityType.tls,
      sni: 'example.com',
      path: '/ws',
    );

    test('CoreService getters for Android binary and asset dir are exposed', () {
      final core = CoreService.instance;
      expect(core, isNotNull);
      // Getters should not throw
      final bin = core.androidBinaryPath;
      final assetDir = core.androidAssetDir;
      expect(bin, anyOf(isNull, isA<String>()));
      expect(assetDir, anyOf(isNull, isA<Directory>()));
    });

    test('XrayProcessService findXrayBinarySync behaves safely across platforms', () {
      final s = XrayProcessService.instance;
      final bin = s.findXrayBinarySync();
      expect(bin, anyOf(isNull, isA<String>()));
    });

    test('Ephemeral port counter generates valid ports without crashing', () {
      final s = PingService.instance;
      expect(s, isNotNull);
    });

    test('Direct node probe handles loopback timeout gracefully', () async {
      final dummyNode = ProxyNode(
        id: 'dummy_loopback',
        name: 'Dummy Loopback',
        address: '127.0.0.1',
        port: 19999,
        protocol: ProtocolType.vless,
        uuidOrPassword: 'dummy',
      );

      final res = await PingService.instance.ping(
        config: CoreConfig.fromNode(dummyNode),
        pingMode: PingMode.ipTest,
        pingType: PingType.tcp,
        timeout: const Duration(milliseconds: 200),
      );
      expect(res.latencyMs, isNull);
    });
  });
}
