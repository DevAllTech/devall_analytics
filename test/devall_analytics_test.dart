import 'dart:convert';

import 'package:devall_analytics/devall_analytics.dart';
import 'package:devall_analytics/src/offline_storage.dart';
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

  tearDown(() async {
    DevAllAnalytics.reset();
    await DevAllOfflineStorage.clear();
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
        () => DevAllAnalytics.init(
          projectToken: 'valid-token',
          httpClient: mockClient,
        ),
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
        enableOffline: false,
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

    test('sends single event to /events endpoint', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'single event',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      expect(capturedRequests, hasLength(1));
      expect(
        capturedRequests.first.url.path,
        endsWith('/events'),
      );
      expect(
        capturedRequests.first.url.path.endsWith('/events/batch'),
        isFalse,
      );
    });

    test('truncates message to 500 characters', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
      );

      final longMessage = 'A' * 600;

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: longMessage,
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      final body =
          jsonDecode(capturedRequests.first.body) as Map<String, dynamic>;
      expect((body['message'] as String).length, equals(500));
    });

    test('omits ip from payload when null', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'no ip',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      final body =
          jsonDecode(capturedRequests.first.body) as Map<String, dynamic>;
      expect(body.containsKey('ip'), isFalse);
    });

    test('uses default timestamp when not provided', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.log,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'auto timestamp',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      final body =
          jsonDecode(capturedRequests.first.body) as Map<String, dynamic>;
      expect(body['timestamp'], isA<String>());
      expect(() => DateTime.parse(body['timestamp']), returnsNormally);
    });

    test('sends to custom base URL when configured', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        baseUrl: 'https://custom-api.example.com/v2',
        enableOffline: false,
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
        enableOffline: false,
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
        enableOffline: false,
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
        enableOffline: false,
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'batch event 1',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      expect(capturedRequests, isEmpty);
      expect(DevAllAnalytics.queueLength, equals(1));
    });

    test('flushes when batch size is reached', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableBatch: true,
        batchSize: 2,
        enableOffline: false,
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

      expect(capturedRequests, hasLength(1));
      expect(DevAllAnalytics.queueLength, equals(0));

      // Batch requests should use /events/batch endpoint
      expect(
        capturedRequests.first.url.path,
        endsWith('/events/batch'),
      );

      final body =
          jsonDecode(capturedRequests.first.body) as Map<String, dynamic>;
      expect(body['events'], isA<List>());
      expect((body['events'] as List), hasLength(2));
    });

    test('flush() sends queued events manually', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableBatch: true,
        batchSize: 100,
        enableOffline: false,
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
        enableOffline: false,
      );

      await DevAllAnalytics.flush();

      expect(capturedRequests, isEmpty);
    });
  });

  group('offline', () {
    test('saves events to offline storage on network failure', () async {
      final failClient = MockClient((request) async {
        throw Exception('No internet');
      });

      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: failClient,
        enableOffline: true,
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.error,
        environment: DevAllEnvironment.prod,
        category: 'test',
        message: 'offline event',
        payload: {'key': 'value'},
        deviceInfo: {'platform': 'test'},
      );

      final pendingCount = await DevAllAnalytics.offlinePendingCount;
      expect(pendingCount, equals(1));

      final events = await DevAllOfflineStorage.loadEvents();
      expect(events.first['message'], equals('offline event'));
      expect(events.first['payload'], equals({'key': 'value'}));
    });

    test('saves events on server error after max retries', () async {
      final serverErrorClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: serverErrorClient,
        enableOffline: true,
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'server down event',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      final pendingCount = await DevAllAnalytics.offlinePendingCount;
      expect(pendingCount, equals(1));
    });

    test('does NOT save to offline on 4xx (client error)', () async {
      final clientErrorClient = MockClient((request) async {
        return http.Response('Bad Request', 400);
      });

      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: clientErrorClient,
        enableOffline: true,
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'bad data',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      final pendingCount = await DevAllAnalytics.offlinePendingCount;
      expect(pendingCount, equals(0));
    });

    test('retryOfflineEvents sends stored events when online', () async {
      // First, store events offline
      await DevAllOfflineStorage.saveEvents([
        {
          'deviceId': 'test-device',
          'timestamp': '2025-01-01T00:00:00.000Z',
          'type': 'info',
          'environment': 'dev',
          'category': 'test',
          'message': 'offline event 1',
          'payload': {},
          'deviceInfo': {'platform': 'test'},
        },
        {
          'deviceId': 'test-device',
          'timestamp': '2025-01-01T00:01:00.000Z',
          'type': 'error',
          'environment': 'prod',
          'category': 'test',
          'message': 'offline event 2',
          'payload': {},
          'deviceInfo': {'platform': 'test'},
        },
      ]);

      // Initialize with a working client
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: true,
      );

      // Wait a bit for the init's automatic retry
      await Future.delayed(Duration(milliseconds: 100));

      // Verify events were sent
      expect(capturedRequests, hasLength(1));

      final body =
          jsonDecode(capturedRequests.first.body) as Map<String, dynamic>;
      expect(body['events'], isA<List>());
      expect((body['events'] as List), hasLength(2));

      // Verify offline storage is now empty
      final pendingCount = await DevAllAnalytics.offlinePendingCount;
      expect(pendingCount, equals(0));
    });

    test('clearOfflineEvents removes all stored events', () async {
      await DevAllOfflineStorage.saveEvents([
        {'message': 'event1'},
        {'message': 'event2'},
      ]);

      expect(await DevAllOfflineStorage.pendingCount, equals(2));

      await DevAllAnalytics.clearOfflineEvents();

      expect(await DevAllOfflineStorage.pendingCount, equals(0));
    });

    test('does not save offline when enableOffline is false', () async {
      final failClient = MockClient((request) async {
        throw Exception('No internet');
      });

      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: failClient,
        enableOffline: false,
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'lost event',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      final pendingCount = await DevAllOfflineStorage.pendingCount;
      expect(pendingCount, equals(0));
    });

    test('respects maxOfflineEvents limit', () async {
      DevAllOfflineStorage.setMaxOfflineEvents(3);

      await DevAllOfflineStorage.saveEvents([
        {'message': 'event1'},
        {'message': 'event2'},
        {'message': 'event3'},
      ]);

      // Adding more should drop the oldest
      await DevAllOfflineStorage.saveEvents([
        {'message': 'event4'},
        {'message': 'event5'},
      ]);

      final events = await DevAllOfflineStorage.loadEvents();
      expect(events, hasLength(3));
      // Oldest events dropped, newest kept
      expect(events[0]['message'], equals('event3'));
      expect(events[1]['message'], equals('event4'));
      expect(events[2]['message'], equals('event5'));
    });
  });

  group('reset', () {
    test('clears all state', () {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
      );
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
      expect(
        DevAllEventType.values.map((e) => e.name),
        containsAll(['error', 'warning', 'info', 'log', 'metric', 'custom']),
      );
    });

    test('DevAllEnvironment has all expected values', () {
      expect(DevAllEnvironment.values, hasLength(3));
      expect(
        DevAllEnvironment.values.map((e) => e.name),
        containsAll(['dev', 'staging', 'prod']),
      );
    });
  });

  // ─── New Feature Tests ───

  group('user identity', () {
    test('identify adds userId to events', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
      );

      DevAllAnalytics.identify(
        userId: 'user-123',
        traits: {'email': 'test@example.com', 'name': 'Test User'},
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'identified event',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      final body =
          jsonDecode(capturedRequests.first.body) as Map<String, dynamic>;
      expect(body['userId'], equals('user-123'));
      expect(body['userTraits'], equals({
        'email': 'test@example.com',
        'name': 'Test User',
      }));
    });

    test('clearIdentity removes userId from events', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
      );

      DevAllAnalytics.identify(userId: 'user-123');
      DevAllAnalytics.clearIdentity();

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'anonymous event',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      final body =
          jsonDecode(capturedRequests.first.body) as Map<String, dynamic>;
      expect(body.containsKey('userId'), isFalse);
    });

    test('identify throws on empty userId', () {
      expect(
        () => DevAllAnalytics.identify(userId: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('currentUserId returns correct value', () {
      DevAllAnalytics.identify(userId: 'u1');
      expect(DevAllAnalytics.currentUserId, equals('u1'));

      DevAllAnalytics.clearIdentity();
      expect(DevAllAnalytics.currentUserId, isNull);
    });
  });

  group('session tracking', () {
    test('startSession generates a sessionId', () {
      final sessionId = DevAllAnalytics.startSession();
      expect(sessionId, isA<String>());
      expect(sessionId, isNotEmpty);
      expect(DevAllAnalytics.currentSessionId, equals(sessionId));
    });

    test('sessionId is included in events', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
      );

      final sessionId = DevAllAnalytics.startSession();

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'session event',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      final body =
          jsonDecode(capturedRequests.first.body) as Map<String, dynamic>;
      expect(body['sessionId'], equals(sessionId));
      expect(body.containsKey('sessionStart'), isTrue);
    });

    test('endSession clears the sessionId', () {
      DevAllAnalytics.startSession();
      DevAllAnalytics.endSession();
      expect(DevAllAnalytics.currentSessionId, isNull);
    });
  });

  group('breadcrumbs', () {
    test('addBreadcrumb stores breadcrumbs', () {
      DevAllAnalytics.addBreadcrumb(
        category: 'ui',
        message: 'Button clicked',
        data: {'button': 'submit'},
      );

      expect(DevAllBreadcrumbs.length, equals(1));
      final json = DevAllBreadcrumbs.toJsonList();
      expect(json.first['category'], equals('ui'));
      expect(json.first['message'], equals('Button clicked'));
      expect(json.first['data'], equals({'button': 'submit'}));
    });

    test('breadcrumbs are included in error events', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
      );

      DevAllAnalytics.addBreadcrumb(
        category: 'navigation',
        message: 'Opened settings',
      );
      DevAllAnalytics.addBreadcrumb(
        category: 'ui',
        message: 'Clicked save',
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.error,
        environment: DevAllEnvironment.prod,
        category: 'crash',
        message: 'Null pointer exception',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      final body =
          jsonDecode(capturedRequests.first.body) as Map<String, dynamic>;
      expect(body['breadcrumbs'], isA<List>());
      expect((body['breadcrumbs'] as List).length, greaterThanOrEqualTo(2));
    });

    test('breadcrumbs respect max limit', () {
      DevAllBreadcrumbs.setMaxBreadcrumbs(3);

      for (var i = 0; i < 5; i++) {
        DevAllBreadcrumbs.add(category: 'test', message: 'crumb $i');
      }

      expect(DevAllBreadcrumbs.length, equals(3));
      final json = DevAllBreadcrumbs.toJsonList();
      expect(json.first['message'], equals('crumb 2'));
      expect(json.last['message'], equals('crumb 4'));
    });

    test('clearBreadcrumbs removes all breadcrumbs', () {
      DevAllAnalytics.addBreadcrumb(category: 'test', message: 'crumb');
      DevAllAnalytics.clearBreadcrumbs();
      expect(DevAllBreadcrumbs.length, equals(0));
    });
  });

  group('sampling', () {
    test('samplingRate 0.0 blocks all events', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
        samplingRate: 0.0,
      );

      for (var i = 0; i < 10; i++) {
        await DevAllAnalytics.trackEvent(
          type: DevAllEventType.info,
          environment: DevAllEnvironment.dev,
          category: 'test',
          message: 'sampled event $i',
          payload: {},
          deviceInfo: {'platform': 'test'},
        );
      }

      expect(capturedRequests, isEmpty);
    });

    test('samplingRate 1.0 sends all events', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
        samplingRate: 1.0,
      );

      for (var i = 0; i < 5; i++) {
        await DevAllAnalytics.trackEvent(
          type: DevAllEventType.info,
          environment: DevAllEnvironment.dev,
          category: 'test',
          message: 'event $i',
          payload: {},
          deviceInfo: {'platform': 'test'},
        );
      }

      expect(capturedRequests, hasLength(5));
    });
  });

  group('rate limiting', () {
    test('rate limiter blocks events over the limit', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
        maxEventsPerMinute: 3,
      );

      for (var i = 0; i < 5; i++) {
        await DevAllAnalytics.trackEvent(
          type: DevAllEventType.info,
          environment: DevAllEnvironment.dev,
          category: 'test',
          message: 'rate limited event $i',
          payload: {},
          deviceInfo: {'platform': 'test'},
        );
      }

      // Only first 3 should be sent
      expect(capturedRequests, hasLength(3));
    });

    test('rate limiter disabled by default (0)', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
      );

      for (var i = 0; i < 10; i++) {
        await DevAllAnalytics.trackEvent(
          type: DevAllEventType.info,
          environment: DevAllEnvironment.dev,
          category: 'test',
          message: 'event $i',
          payload: {},
          deviceInfo: {'platform': 'test'},
        );
      }

      expect(capturedRequests, hasLength(10));
    });
  });

  group('middleware', () {
    test('middleware can modify events', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
      );

      DevAllAnalytics.addMiddleware((event) {
        event['custom_field'] = 'injected';
        return event;
      });

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'middleware test',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      final body =
          jsonDecode(capturedRequests.first.body) as Map<String, dynamic>;
      expect(body['custom_field'], equals('injected'));
    });

    test('middleware can block events by returning null', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
      );

      DevAllAnalytics.addMiddleware((event) {
        if (event['category'] == 'blocked') return null;
        return event;
      });

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'blocked',
        message: 'should be blocked',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'allowed',
        message: 'should be sent',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      expect(capturedRequests, hasLength(1));
      final body =
          jsonDecode(capturedRequests.first.body) as Map<String, dynamic>;
      expect(body['category'], equals('allowed'));
    });

    test('middleware can redact sensitive data', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
      );

      DevAllAnalytics.addMiddleware((event) {
        final payload = event['payload'] as Map<String, dynamic>?;
        if (payload != null) {
          payload.remove('password');
          payload.remove('creditCard');
        }
        return event;
      });

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'auth',
        message: 'login attempt',
        payload: {
          'email': 'user@test.com',
          'password': 'secret123',
          'creditCard': '4111-1111-1111-1111',
        },
        deviceInfo: {'platform': 'test'},
      );

      final body =
          jsonDecode(capturedRequests.first.body) as Map<String, dynamic>;
      final sentPayload = body['payload'] as Map<String, dynamic>;
      expect(sentPayload['email'], equals('user@test.com'));
      expect(sentPayload.containsKey('password'), isFalse);
      expect(sentPayload.containsKey('creditCard'), isFalse);
    });

    test('clearMiddleware removes all middleware', () {
      DevAllAnalytics.addMiddleware((e) => e);
      DevAllAnalytics.addMiddleware((e) => e);
      expect(DevAllMiddlewareManager.count, equals(2));

      DevAllAnalytics.clearMiddleware();
      expect(DevAllMiddlewareManager.count, equals(0));
    });
  });

  group('consent/GDPR', () {
    test('events are blocked when consent is revoked', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
      );

      await DevAllAnalytics.setConsent(granted: false);

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'should be blocked',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      expect(capturedRequests, isEmpty);
    });

    test('events are sent when consent is granted', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
      );

      await DevAllAnalytics.setConsent(granted: true);

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'should be sent',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      expect(capturedRequests, hasLength(1));
    });

    test('consent defaults to allowed (opt-out model)', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'default consent',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      expect(capturedRequests, hasLength(1));
    });
  });

  group('screen tracking', () {
    test('trackScreen adds screen data to events', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
      );

      DevAllAnalytics.trackScreen('HomePage');

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'event on home',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      final body =
          jsonDecode(capturedRequests.first.body) as Map<String, dynamic>;
      expect(body['screen'], equals('HomePage'));
    });

    test('currentScreen returns active screen', () {
      DevAllAnalytics.trackScreen('ProfilePage');
      expect(DevAllAnalytics.currentScreen, equals('ProfilePage'));

      DevAllAnalytics.endScreen();
      expect(DevAllAnalytics.currentScreen, isNull);
    });
  });

  group('multi-destination', () {
    test('events are forwarded to custom destinations', () async {
      final receivedEvents = <Map<String, dynamic>>[];

      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
      );

      DevAllAnalytics.addDestination(_TestDestination(receivedEvents));

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'multi-dest event',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      // Should be sent to both API and custom destination
      expect(capturedRequests, hasLength(1));
      expect(receivedEvents, hasLength(1));
      expect(receivedEvents.first['message'], equals('multi-dest event'));
    });

    test('destination errors do not block main send', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
      );

      DevAllAnalytics.addDestination(_FailingDestination());

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'should still send',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      // Main API should still receive the event
      expect(capturedRequests, hasLength(1));
    });
  });

  group('debug log', () {
    test('events are logged to debug log', () async {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'debug log test',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      // In debug mode, entries should be logged
      // DevAllDebugLog entries are only added in kDebugMode
      // In tests, kDebugMode is true
      expect(DevAllDebugLog.length, greaterThan(0));
    });
  });

  group('error handler', () {
    test('captureFlutterErrors installs handlers', () {
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
      );

      DevAllAnalytics.captureFlutterErrors();
      expect(DevAllErrorHandler.isInstalled, isTrue);

      DevAllAnalytics.stopCapturingErrors();
      expect(DevAllErrorHandler.isInstalled, isFalse);
    });
  });

  group('init with new options', () {
    test('accepts all new configuration options', () {
      expect(
        () => DevAllAnalytics.init(
          projectToken: 'test-token',
          httpClient: mockClient,
          samplingRate: 0.5,
          maxEventsPerMinute: 100,
          maxBreadcrumbs: 25,
          enableCompression: true,
        ),
        returnsNormally,
      );
    });

    test('clamps samplingRate to 0.0-1.0', () async {
      // samplingRate > 1.0 should be clamped to 1.0 (all events sent)
      DevAllAnalytics.init(
        projectToken: 'test-token',
        httpClient: mockClient,
        enableOffline: false,
        samplingRate: 2.0,
      );

      await DevAllAnalytics.trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.dev,
        category: 'test',
        message: 'clamped rate',
        payload: {},
        deviceInfo: {'platform': 'test'},
      );

      expect(capturedRequests, hasLength(1));
    });
  });
}

/// Test helper: a custom destination that collects events.
class _TestDestination implements DevAllEventDestination {
  final List<Map<String, dynamic>> events;

  _TestDestination(this.events);

  @override
  String get name => 'Test';

  @override
  Future<void> sendEvent(Map<String, dynamic> event) async {
    events.add(event);
  }
}

/// Test helper: a destination that always throws.
class _FailingDestination implements DevAllEventDestination {
  @override
  String get name => 'Failing';

  @override
  Future<void> sendEvent(Map<String, dynamic> event) async {
    throw Exception('Destination error');
  }
}
