import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:devall_analytics/enums.dart';
import 'package:devall_analytics/device_identity.dart';

import 'breadcrumbs.dart';
import 'compression_stub.dart'
    if (dart.library.io) 'compression_io.dart'
    if (dart.library.js_interop) 'compression_web.dart';
import 'consent_manager.dart';
import 'debug_overlay.dart';
import 'error_handler.dart';
import 'event_destination.dart';
import 'lifecycle_observer.dart';
import 'middleware.dart';
import 'offline_storage.dart';
import 'platform_info_stub.dart'
    if (dart.library.io) 'platform_info_io.dart'
    if (dart.library.js_interop) 'platform_info_web.dart';
import 'rate_limiter.dart';
import 'screen_tracker.dart';
import 'session_manager.dart';
import 'user_identity.dart';

const _defaultBaseUrl = 'https://api-logs.devalltech.com.br/api/v1';
const _defaultBatchSize = 10;
const _defaultFlushInterval = Duration(seconds: 30);
const _defaultOfflineRetryInterval = Duration(minutes: 2);
const _maxRetries = 3;

class DevAllAnalytics {
  static String? _projectToken;
  static String _baseUrl = _defaultBaseUrl;
  static http.Client? _httpClient;
  static bool _batchEnabled = false;
  static int _batchSize = _defaultBatchSize;
  static Duration _flushInterval = _defaultFlushInterval;
  static Timer? _flushTimer;
  static final List<Map<String, dynamic>> _eventQueue = [];

  // Offline support
  static bool _offlineEnabled = true;
  static Duration _offlineRetryInterval = _defaultOfflineRetryInterval;
  static Timer? _offlineRetryTimer;
  static bool _isRetryingOffline = false;

  // Sampling
  static double _samplingRate = 1.0;
  static final Random _random = Random();

  // Compression
  static bool _compressionEnabled = false;

  /// Initializes the SDK with the project token and optional configuration.
  ///
  /// [projectToken] - Required. Your project token from DevAll Tech.
  /// [baseUrl] - Optional. Custom API base URL.
  /// [httpClient] - Optional. Custom HTTP client (useful for testing).
  /// [enableBatch] - Optional. Enable event batching (default: false).
  /// [batchSize] - Optional. Number of events before auto-flush (default: 10).
  /// [flushInterval] - Optional. Max time between batch flushes (default: 30s).
  /// [enableOffline] - Optional. Enable offline queue with auto-retry (default: true).
  /// [offlineRetryInterval] - Optional. Interval to retry sending offline events (default: 2min).
  /// [maxOfflineEvents] - Optional. Max events to keep offline (default: 500).
  /// [samplingRate] - Optional. Percentage of events to send (0.0-1.0, default: 1.0).
  /// [maxEventsPerMinute] - Optional. Rate limit per minute (0 = disabled, default: 0).
  /// [maxBreadcrumbs] - Optional. Max breadcrumbs to keep (default: 50).
  /// [enableCompression] - Optional. Enable gzip compression for payloads (default: false).
  static void init({
    required String projectToken,
    String? baseUrl,
    http.Client? httpClient,
    bool enableBatch = false,
    int batchSize = _defaultBatchSize,
    Duration flushInterval = _defaultFlushInterval,
    bool enableOffline = true,
    Duration offlineRetryInterval = _defaultOfflineRetryInterval,
    int maxOfflineEvents = 500,
    double samplingRate = 1.0,
    int maxEventsPerMinute = 0,
    int maxBreadcrumbs = 50,
    bool enableCompression = false,
  }) {
    if (projectToken.trim().isEmpty) {
      throw ArgumentError('projectToken must not be empty.');
    }

    _projectToken = projectToken;
    _baseUrl = baseUrl ?? _defaultBaseUrl;
    _httpClient = httpClient;
    _batchEnabled = enableBatch;
    _batchSize = batchSize;
    _flushInterval = flushInterval;
    _offlineEnabled = enableOffline;
    _offlineRetryInterval = offlineRetryInterval;
    _samplingRate = samplingRate.clamp(0.0, 1.0);
    _compressionEnabled = enableCompression;

    DevAllOfflineStorage.setMaxOfflineEvents(maxOfflineEvents);
    DevAllRateLimiter.setMaxEventsPerMinute(maxEventsPerMinute);
    DevAllBreadcrumbs.setMaxBreadcrumbs(maxBreadcrumbs);

    if (_batchEnabled) {
      _startFlushTimer();
    }

    if (_offlineEnabled) {
      _startOfflineRetryTimer();
      // Try to drain offline queue on init
      retryOfflineEvents();
    }
  }

  /// Resets the SDK state. Useful for testing.
  @visibleForTesting
  static void reset() {
    _projectToken = null;
    _baseUrl = _defaultBaseUrl;
    _httpClient = null;
    _batchEnabled = false;
    _batchSize = _defaultBatchSize;
    _flushInterval = _defaultFlushInterval;
    _flushTimer?.cancel();
    _flushTimer = null;
    _eventQueue.clear();
    _offlineEnabled = true;
    _offlineRetryInterval = _defaultOfflineRetryInterval;
    _offlineRetryTimer?.cancel();
    _offlineRetryTimer = null;
    _isRetryingOffline = false;
    _samplingRate = 1.0;
    _compressionEnabled = false;
    DevAllOfflineStorage.resetConfig();
    DevAllUserIdentity.reset();
    DevAllSessionManager.reset();
    DevAllBreadcrumbs.reset();
    DevAllErrorHandler.reset();
    DevAllRateLimiter.reset();
    DevAllMiddlewareManager.reset();
    DevAllLifecycleObserver.reset();
    DevAllScreenTracker.reset();
    DevAllDestinationManager.reset();
    DevAllDebugLog.reset();
    DevAllConsentManager.resetSync();
  }

  // ─── User Identity ───

  /// Identifies the current user. All subsequent events include user data.
  static void identify({
    required String userId,
    Map<String, dynamic>? traits,
  }) {
    DevAllUserIdentity.identify(userId: userId, traits: traits);
  }

  /// Clears the current user identity (e.g., on logout).
  static void clearIdentity() {
    DevAllUserIdentity.clear();
  }

  /// Returns the current userId, or null.
  static String? get currentUserId => DevAllUserIdentity.userId;

  // ─── Session Tracking ───

  /// Starts a new session. Returns the sessionId.
  static String startSession() {
    return DevAllSessionManager.start();
  }

  /// Ends the current session.
  static void endSession() {
    DevAllSessionManager.end();
  }

  /// Returns the current sessionId, or null.
  static String? get currentSessionId => DevAllSessionManager.sessionId;

  // ─── Breadcrumbs ───

  /// Adds a breadcrumb for error context.
  static void addBreadcrumb({
    required String category,
    required String message,
    Map<String, dynamic>? data,
  }) {
    DevAllBreadcrumbs.add(category: category, message: message, data: data);
  }

  /// Clears all breadcrumbs.
  static void clearBreadcrumbs() {
    DevAllBreadcrumbs.clear();
  }

  // ─── Global Error Handler ───

  /// Installs global error handlers that auto-track errors.
  static void captureFlutterErrors() {
    DevAllErrorHandler.install((error, stackTrace, source) async {
      if (_projectToken == null) return;

      await trackEvent(
        type: DevAllEventType.error,
        environment: DevAllEnvironment.prod,
        category: 'crash.$source',
        message: error.toString(),
        payload: {
          'source': source,
          if (stackTrace != null) 'stackTrace': stackTrace.toString(),
          'breadcrumbs': DevAllBreadcrumbs.toJsonList(),
        },
      );
    });
  }

  /// Uninstalls global error handlers.
  static void stopCapturingErrors() {
    DevAllErrorHandler.uninstall();
  }

  // ─── Lifecycle ───

  /// Installs lifecycle observer to auto-track app lifecycle events.
  static void enableLifecycleTracking() {
    DevAllLifecycleObserver.install((event) {
      if (_projectToken == null) return;

      // Start/end sessions based on lifecycle
      if (event == 'app_open' || event == 'app_resumed') {
        if (DevAllSessionManager.sessionId == null) {
          DevAllSessionManager.start();
        }
      } else if (event == 'app_paused' || event == 'app_detached') {
        DevAllSessionManager.end();
      }

      trackEvent(
        type: DevAllEventType.info,
        environment: DevAllEnvironment.prod,
        category: 'lifecycle',
        message: event,
        payload: {'lifecycle_event': event},
      );
    });
  }

  /// Disables lifecycle tracking.
  static void disableLifecycleTracking() {
    DevAllLifecycleObserver.uninstall();
  }

  // ─── Screen Tracking ───

  /// Tracks a screen view. Automatically ends the previous screen.
  static void trackScreen(String screenName) {
    DevAllScreenTracker.setOnScreenEnd((name, duration) {
      if (_projectToken == null) return;
      trackEvent(
        type: DevAllEventType.metric,
        environment: DevAllEnvironment.prod,
        category: 'screen_view',
        message: 'Screen ended: $name',
        payload: {
          'screen': name,
          'durationMs': duration.inMilliseconds,
        },
      );
    });

    DevAllScreenTracker.trackScreen(screenName);

    addBreadcrumb(category: 'navigation', message: 'Screen: $screenName');
  }

  /// Ends tracking of the current screen.
  static void endScreen() {
    DevAllScreenTracker.endScreen();
  }

  /// Returns the current screen name, or null.
  static String? get currentScreen => DevAllScreenTracker.currentScreen;

  // ─── Middleware ───

  /// Adds an event middleware (onBeforeSend).
  ///
  /// Middleware can modify events or return null to block them.
  /// ```dart
  /// DevAllAnalytics.addMiddleware((event) {
  ///   // Redact sensitive data
  ///   event['payload']?.remove('password');
  ///   return event;
  /// });
  /// ```
  static void addMiddleware(DevAllEventMiddleware middleware) {
    DevAllMiddlewareManager.add(middleware);
  }

  /// Removes a specific middleware.
  static void removeMiddleware(DevAllEventMiddleware middleware) {
    DevAllMiddlewareManager.remove(middleware);
  }

  /// Clears all middleware.
  static void clearMiddleware() {
    DevAllMiddlewareManager.clear();
  }

  // ─── Consent/GDPR ───

  /// Sets the user's consent status.
  static Future<void> setConsent({required bool granted}) {
    return DevAllConsentManager.setConsent(granted: granted);
  }

  /// Returns whether consent is currently granted.
  static Future<bool?> isConsentGranted() {
    return DevAllConsentManager.isConsentGranted();
  }

  // ─── Multi-Destination ───

  /// Adds an event destination for multi-service forwarding.
  static void addDestination(DevAllEventDestination destination) {
    DevAllDestinationManager.add(destination);
  }

  /// Removes an event destination.
  static void removeDestination(DevAllEventDestination destination) {
    DevAllDestinationManager.remove(destination);
  }

  // ─── Core Event Tracking ───

  /// Tracks an analytics event.
  static Future<void> trackEvent({
    required DevAllEventType type,
    required DevAllEnvironment environment,
    required String category,
    required String message,
    required Map<String, dynamic> payload,
    Map<String, dynamic>? deviceInfo,
    DateTime? timestamp,
    String? ip,
  }) async {
    if (_projectToken == null || _projectToken!.trim().isEmpty) {
      throw Exception('DevAllAnalytics not initialized. Call init() first.');
    }

    // Consent check
    if (!DevAllConsentManager.isTrackingAllowed) {
      if (kDebugMode) {
        print('DevAllAnalytics: Event blocked (consent not granted).');
      }
      return;
    }

    // Sampling
    if (_samplingRate < 1.0 && _random.nextDouble() > _samplingRate) {
      if (kDebugMode) {
        print('DevAllAnalytics: Event sampled out.');
      }
      return;
    }

    // Rate limiting
    if (!DevAllRateLimiter.allowEvent()) {
      return;
    }

    final deviceId = await DevAllDeviceIdentity.getOrCreateDeviceId();
    timestamp ??= DateTime.now();
    deviceInfo ??= _getDefaultDeviceInfo();

    var body = <String, dynamic>{
      'deviceId': deviceId,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'type': type.name,
      'environment': environment.name,
      'category': category,
      'message': message.length > 500 ? message.substring(0, 500) : message,
      'payload': payload,
      'deviceInfo': deviceInfo,
      if (ip != null) 'ip': ip,
      // Enrich with user identity
      ...DevAllUserIdentity.toEventData(),
      // Enrich with session data
      ...DevAllSessionManager.toEventData(),
      // Enrich with screen data
      ...DevAllScreenTracker.toEventData(),
    };

    // Include breadcrumbs in error events
    if (type == DevAllEventType.error) {
      body['breadcrumbs'] = DevAllBreadcrumbs.toJsonList();
    }

    // Run through middleware
    final processed = DevAllMiddlewareManager.process(body);
    if (processed == null) return;
    body = processed;

    // Add breadcrumb for this event
    DevAllBreadcrumbs.add(category: category, message: message);

    // Debug log
    DevAllDebugLog.add(type: type.name, message: '$category: $message');

    // Forward to external destinations
    DevAllDestinationManager.forwardEvent(body);

    if (_batchEnabled) {
      _eventQueue.add(body);
      if (_eventQueue.length >= _batchSize) {
        await flush();
      }
    } else {
      await _sendEvents([body]);
    }
  }

  /// Flushes all queued events immediately.
  static Future<void> flush() async {
    if (_eventQueue.isEmpty) return;

    final events = List<Map<String, dynamic>>.from(_eventQueue);
    _eventQueue.clear();

    await _sendEvents(events);
  }

  /// Manually triggers retry of all offline events.
  ///
  /// Called automatically on init and periodically by the offline retry timer.
  /// Can also be called manually, e.g., when the app detects connectivity change.
  static Future<void> retryOfflineEvents() async {
    if (_isRetryingOffline) return;
    if (_projectToken == null) return;

    _isRetryingOffline = true;

    try {
      final offlineEvents = await DevAllOfflineStorage.loadEvents();
      if (offlineEvents.isEmpty) return;

      if (kDebugMode) {
        print('DevAllAnalytics: Retrying ${offlineEvents.length} offline event(s)...');
      }

      // Send in chunks to avoid oversized payloads
      const chunkSize = 25;
      final failedEvents = <Map<String, dynamic>>[];

      for (var i = 0; i < offlineEvents.length; i += chunkSize) {
        final end = (i + chunkSize < offlineEvents.length)
            ? i + chunkSize
            : offlineEvents.length;
        final chunk = offlineEvents.sublist(i, end);

        final success = await _sendEventsRaw(chunk);
        if (!success) {
          // First failure means we're still offline - keep remaining events
          failedEvents.addAll(offlineEvents.sublist(i));
          break;
        }
      }

      // Update persistent storage with only the events that failed
      await DevAllOfflineStorage.clear();
      if (failedEvents.isNotEmpty) {
        await DevAllOfflineStorage.saveEvents(failedEvents);
      } else if (kDebugMode) {
        print('DevAllAnalytics: All offline events sent successfully.');
      }
    } finally {
      _isRetryingOffline = false;
    }
  }

  /// Returns the number of events currently stored offline.
  static Future<int> get offlinePendingCount =>
      DevAllOfflineStorage.pendingCount;

  /// Clears all offline events from persistent storage.
  static Future<void> clearOfflineEvents() => DevAllOfflineStorage.clear();

  /// Sends events to the API with retry and exponential backoff.
  /// On final failure, saves events offline if enabled.
  static Future<void> _sendEvents(List<Map<String, dynamic>> events) async {
    final success = await _sendEventsRaw(events);

    DevAllDebugLog.add(
      type: 'http',
      message: success
          ? 'Sent ${events.length} event(s)'
          : 'Failed to send ${events.length} event(s)',
      success: success,
    );

    if (!success && _offlineEnabled) {
      await DevAllOfflineStorage.saveEvents(events);
    }
  }

  /// Sends events and returns true on success, false on failure.
  /// Does NOT save to offline storage (caller decides what to do).
  static Future<bool> _sendEventsRaw(
      List<Map<String, dynamic>> events) async {
    final client = _httpClient ?? http.Client();
    final shouldCloseClient = _httpClient == null;

    try {
      final isBatch = events.length > 1;
      final uri = Uri.parse(
          isBatch ? '$_baseUrl/events/batch' : '$_baseUrl/events');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'x-project-token': _projectToken!,
      };

      final jsonBody = isBatch
          ? jsonEncode({'events': events})
          : jsonEncode(events.first);

      // Encode body as bytes - using utf8.encode directly avoids the http
      // package's automatic Content-Type charset modification that can cause
      // parsing issues on some servers.
      List<int> bodyBytes = utf8.encode(jsonBody);

      // Compression support
      if (_compressionEnabled) {
        try {
          bodyBytes = _gzipEncode(jsonBody);
          headers['Content-Encoding'] = 'gzip';
        } catch (_) {
          // Fallback to uncompressed (already encoded above)
        }
      }

      for (var attempt = 0; attempt <= _maxRetries; attempt++) {
        try {
          final request = http.Request('POST', uri);
          request.headers.addAll(headers);
          request.bodyBytes = bodyBytes;
          final streamed = await client.send(request);
          final response = await http.Response.fromStream(streamed);

          if (response.statusCode < 400) {
            return true; // Success
          }

          if (response.statusCode >= 500 && attempt < _maxRetries) {
            await Future.delayed(Duration(seconds: 1 << attempt));
            continue;
          }

          // Client error (4xx) - don't save offline, data is bad
          if (response.statusCode >= 400 && response.statusCode < 500) {
            if (kDebugMode) {
              print(
                  'DevAllAnalytics error: ${response.statusCode} - ${response.body}');
            }
            return true; // Return true so we don't save to offline
          }

          if (kDebugMode) {
            print(
                'DevAllAnalytics error: ${response.statusCode} - ${response.body}');
          }
          return false;
        } catch (e) {
          if (attempt < _maxRetries) {
            await Future.delayed(Duration(seconds: 1 << attempt));
            continue;
          }
          if (kDebugMode) {
            print('DevAllAnalytics failed to send event: $e');
          }
          return false; // Network error - save offline
        }
      }
      return false;
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
    }
  }

  /// Gzip-encodes a string. Returns compressed bytes.
  /// Falls back to uncompressed on unsupported platforms (web).
  static List<int> _gzipEncode(String input) {
    return gzipEncode(utf8.encode(input));
  }

  /// Returns default device information based on the current platform.
  static Map<String, dynamic> _getDefaultDeviceInfo() {
    return getPlatformDeviceInfo();
  }

  static void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushInterval, (_) => flush());
  }

  static void _startOfflineRetryTimer() {
    _offlineRetryTimer?.cancel();
    _offlineRetryTimer = Timer.periodic(
      _offlineRetryInterval,
      (_) => retryOfflineEvents(),
    );
  }

  /// Exposes the event queue length for testing purposes.
  @visibleForTesting
  static int get queueLength => _eventQueue.length;
}
