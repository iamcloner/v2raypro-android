import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v2raypro/models/proxy_node.dart';
import 'package:v2raypro/providers/app_providers.dart';
import 'package:v2raypro/services/real_delay_service.dart';
import 'package:v2raypro/services/xray_process_service.dart';

void main() {
  group('v1.7.3 WebSocket Latency & Real Delay Tests', () {
    test('WebSocket latency probe does not inflate ping beyond handshakeLatency', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((client) {
        client.listen((data) async {
          final request = utf8.decode(data);
          if (request.contains('Upgrade: websocket')) {
            // Simulate CDN/server delay of 150ms before returning 101 Switching Protocols
            await Future.delayed(const Duration(milliseconds: 150));
            client.write('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n');
          }
        });
      });

      final wsNode = ProxyNode(
        id: 'ws_latency_test_1',
        name: 'WebSocket Test Server',
        protocol: ProtocolType.vless,
        address: '127.0.0.1',
        port: server.port,
        uuidOrPassword: 'uuid-1234',
        network: NetworkType.ws,
        path: '/ws-path',
        security: SecurityType.none,
      );

      final latency = await XrayProcessService.instance.testNodeLatency(
        wsNode,
        timeout: const Duration(seconds: 2),
      );

      await server.close();

      expect(latency, isNotNull);
      // Handshake latency on loopback is typically < 50ms, whereas the 150ms HTTP delay was NOT stacked onto it
      expect(latency! < 120, isTrue, reason: 'Latency ( ms) should reflect handshake RTT, not stacked HTTP delay');
    });

    test('FreeConfigsNotifier.updateSingleNode updates latency and keeps nodes sorted', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(freeConfigsProvider.notifier);
      final n1 = ProxyNode(id: 'f1', name: 'Free 1', protocol: ProtocolType.vless, address: '1.1.1.1', port: 443, uuidOrPassword: 'u', latencyMs: 250);
      final n2 = ProxyNode(id: 'f2', name: 'Free 2', protocol: ProtocolType.vless, address: '2.2.2.2', port: 443, uuidOrPassword: 'u', latencyMs: 150);

      notifier.updateSingleNode(n1);
      notifier.updateSingleNode(n2);

      var working = container.read(freeConfigsProvider).workingNodes;
      expect(working.length, equals(2));
      expect(working.first.id, equals('f2')); // 150 ms first

      // Now test n1 again and give it a faster ping (80ms)
      final n1Faster = n1.copyWith(latencyMs: 80);
      notifier.updateSingleNode(n1Faster);

      working = container.read(freeConfigsProvider).workingNodes;
      expect(working.length, equals(2));
      expect(working.first.id, equals('f1')); // Now 80ms is first!
      expect(working.first.latencyMs, equals(80));

      // Now test n2 and it times out (-1)
      final n2TimedOut = n2.copyWith(latencyMs: -1);
      notifier.updateSingleNode(n2TimedOut);

      final state = container.read(freeConfigsProvider);
      expect(state.workingNodes.length, equals(1));
      expect(state.workingNodes.first.id, equals('f1'));
      expect(state.timeoutNodes.length, equals(1));
      expect(state.timeoutNodes.first.id, equals('f2'));
    });

    test('testRealDelay handles single proxy node JSON with RealDelayResult', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((client) {
        client.write('HTTP/1.1 200 OK\r\n\r\n');
      });

      final testNode = ProxyNode(
        id: 'rd_test_node',
        name: 'Real Delay Test Node',
        protocol: ProtocolType.trojan,
        address: '127.0.0.1',
        port: server.port,
        uuidOrPassword: 'pass',
        network: NetworkType.tcp,
        security: SecurityType.none,
      );

      final result = await testRealDelay(
        mode: 'turbo',
        type: 'xray',
        config: testNode.toJson(),
      );

      await server.close();

      expect(result.ping, isNotNull);
      expect(result.ping! >= 0, isTrue);
      expect(result.isSuccess, isTrue);
    });

    test('testRealDelayBatch processes multiple nodes concurrently and produces mapped output', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((client) {
        client.write('connected');
      });

      final nodes = [
        ProxyNode(id: 'batch_1', name: 'Node 1', protocol: ProtocolType.vless, address: '127.0.0.1', port: server.port, uuidOrPassword: 'u', network: NetworkType.tcp, security: SecurityType.none),
        ProxyNode(id: 'batch_2', name: 'Node 2', protocol: ProtocolType.vless, address: '127.0.0.1', port: server.port, uuidOrPassword: 'u', network: NetworkType.tcp, security: SecurityType.none),
      ];

      final results = await testRealDelayBatch(
        mode: 'turbo',
        type: 'xray',
        configs: nodes.map((n) => n.toJson()).toList(),
      );

      await server.close();

      expect(results.containsKey('batch_1'), isTrue);
      expect(results.containsKey('batch_2'), isTrue);
      expect(results['batch_1']!.isSuccess, isTrue);
      expect(results['batch_2']!.isSuccess, isTrue);
    });
  });
}
