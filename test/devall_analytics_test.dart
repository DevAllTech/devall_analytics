import 'dart:convert';

import 'package:devall_analytics/devall_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late List<http.Request> capturedRequests;
  late MockClient mockClient;

  setUp(() {
    DevAllAnalytics.reset();
    capturedRequests = [];
    mockClient = MockClient((request) async {
      capturedRequests.add(request);
      return http.Response('{"ok": true}', 200);
    });
  });

  tearDown(() {
    DevAllAnalytics.reset();
  });

  group('init', () {
    test('throws ArgumentError when token is empty', () {
      expect(
        () => DevAllAnalytics.init(projectToken: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when token is whitespace only', () {
      expect(
        () => DevAllAnalytics.init(projectToken: '   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('accepts a valid token', () {
      expect(
        () => DevAllAnalytics.init(projectToken: 'valid-token'),
        returnsNormally,
      );
    });
  });

  group('trackEvent', () {
    test('throws exception when not initialized', () {
      expect(
        () => DevAllAnalytics.trackEvent(
          type: DevAllEventType.log,
          environment: DevAllEnvironment.dev,
          category: 'test',
          message: 'test event',
          payload: {},
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('sends correct payload to API', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
      );

      final timestamp = DateTime.utc(2025, 1, 1, 12, 0, 0);

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.error,
        environment: DevAllEnvironment.prod,
        category: 'auth',
        message: 'Login failed',
        payload: {'code': 401},
        deviceInfo: {'platform': 'test'},
        timestamp: timestamp,
        ip: '127.0.0.1',
      );

      expect(capturedRequests, hasLength(1));

      final request = capturedRequests.first;
      expect(request.headers['x-project-token'], equals('test-token'));
      expect(request.headers['Content-Type'], equals('application/json'));

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['type'], equals('error'));
      expect(body['environment'], equals('prod'));
      expect(body['category'], equals('auth'));
      expect(body['message'], equals('Login failed'));
      expect(body['payload'], equals({'code': 401}));
      expect(body['deviceInfo'], equals({'platform': 'test'}));
      expect(body['timestamp'], equals('2025-01-01T12:00:00.000Z'));
      expect(body['ip'], equals('127.0.0.1'));
      expect(body['deviceId'], isA<String>());
    });

    test('omits ip from payload when null', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'no ip',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      final body = jsonDecode(capturedRequests.first.body) as Map<String, dynamic>;
      expect(body.containsKey('ip'), isFalse);
    });

    test('uses default timestamp when not provided', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.log,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'auto timestamp',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      final body = jsonDecode(capturedRequests.first.body) as Map<String, dynamic>;
      expect(body['timestamp'], isA<String>());
      // Should be a valid ISO 8601 string
      expect(() => DateTime.parse(body['timestamp']), returnsNormally);
    });

    test('sends to custom base URL when configured', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        baseUrl: 'https://custom-api.example.com/v2',
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.staging,
        category: 'test',
        message: 'custom url',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      expect(
        capturedRequests.first.url.toString(),
        equals('https://custom-api.example.com/v2/events'),
      );
    });
  });

  group('retry', () {
    test('retries on server error (5xx)', () async {
      var callCount = 0;
      final retryClient = MockClient((request) async {
        callCount++;
        if (callCount < 3) {
          return http.Response('Server Error', 500);
        }
        return http.Response('{"ok": true}', 200);
      });

      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: retryClient,
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.error,
        environment: DevAllEnvironment.prod,
        category: 'test',
        message: 'retry test',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      expect(callCount, equals(3));
    });

    test('does not retry on client error (4xx)', () async {
      var callCount = 0;
      final clientErrorClient = MockClient((request) async {
        callCount++;
        return http.Response('Bad Request', 400);
      });

      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: clientErrorClient,
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.error,
        environment: DevAllEnvironment.prod,
        category: 'test',
        message: 'no retry on 4xx',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      expect(callCount, equals(1));
    });
  });

  group('batching', () {
    test('queues events when batch is enabled', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableBatch: true,
        batchSize: 3,
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'batch event 1',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      // Should not have sent yet
      expect(capturedRequests, isEmpty);
      expect(DevAllAnalytics.queueLength, equals(1));
    });

    test('flushes when batch size is reached', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableBatch: true,
        batchSize: 2,
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'event 1',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'event 2',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      // Should have flushed after reaching batch size
      expect(capturedRequests, hasLength(1));
      expect(DevAllAnalytics.queueLength, equals(0));

      final body = jsonDecode(capturedRequests.first.body) as Map<String, dynamic>;
      expect(body['events'], isA<List>());
      expect((body['events'] as List), hasLength(2));
    });

    test('flush() sends queued events manually', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableBatch: true,
        batchSize: 100,
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'manual flush',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      expect(capturedRequests, isEmpty);

      await DevAllAnalytics.flush();

      expect(capturedRequests, hasLength(1));
      expect(DevAllAnalytics.queueLength, equals(0));
    });

    test('flush() does nothing when queue is empty', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableBatch: true,
      );

      await DevAllAnalytics.flush();

      expect(capturedRequests, isEmpty);
    });
  });

  group('reset', () {
    test('clears all state', () {
      DevAllAnalytics.init(projectToken: 'test-token');
      DevAllAnalytics.reset();

      expect(
        () => DevAllAnalytics.trackEvent(
          type: DevAllEventType.log,
          environment: DevAllEnvironment.dev,
          category: 'test',
          message: 'after reset',
          payload: {},
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('DevAllDeviceIdentity', () {
    test('generates a valid UUID device ID', () async {
      final deviceId = await DevAllDeviceIdentity.getOrCreateDeviceId();
      expect(deviceId, isA<String>());
      expect(deviceId, isNotEmpty);
      // UUID v4 format
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(deviceId),
        isTrue,
      );
    });

    test('returns the same device ID on subsequent calls', () async {
      final first = await DevAllDeviceIdentity.getOrCreateDeviceId();
      final second = await DevAllDeviceIdentity.getOrCreateDeviceId();
      expect(first, equals(second));
    });
  });

  group('enums', () {
    test('DevAllEventType has all expected values', () {
      expect(DevAllEventType.values, hasLength(6));
      expect(DevAllEventType.values.map((e) => e.name), containsAll([
        'error', 'warning', 'info', 'log', 'metric', 'custom',
      ]));
    });

    test('DevAllEnvironment has all expected values', () {
      expect(DevAllEnvironment.values, hasLength(3));
      expect(DevAllEnvironment.values.map((e) => e.name), containsAll([
        'dev', 'staging', 'prod',
      ]));
    });
  });
}
