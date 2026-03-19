import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:devall_analytics/enums.dart';
import 'package:devall_analytics/device_identity.dart';

import 'offline_storage.dart';
import 'platform_info_stub.dart'
    if (dart.library.io) 'platform_info_io.dart'
    if (dart.library.js_interop) 'platform_info_web.dart';

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

    DevAllOfflineStorage.setMaxOfflineEvents(maxOfflineEvents);

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
    DevAllOfflineStorage.resetConfig();
  }

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

    final deviceId = await DevAllDeviceIdentity.getOrCreateDeviceId();
    timestamp ??= DateTime.now();
    deviceInfo ??= _getDefaultDeviceInfo();

    final body = {
      'deviceId': deviceId,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'type': type.name,
      'environment': environment.name,
      'category': category,
      'message': message,
      'payload': payload,
      'deviceInfo': deviceInfo,
      if (ip != null) 'ip': ip,
    };

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
      final uri = Uri.parse('$_baseUrl/events');
      final headers = {
        'Content-Type': 'application/json',
        'x-project-token': _projectToken!,
      };

      final body = events.length == 1
          ? jsonEncode(events.first)
          : jsonEncode({'events': events});

      for (var attempt = 0; attempt <= _maxRetries; attempt++) {
        try {
          final response = await client.post(
            uri,
            headers: headers,
            body: body,
          );

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
