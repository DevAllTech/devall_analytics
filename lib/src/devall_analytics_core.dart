import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:devall_analytics/enums.dart';
import 'package:devall_analytics/device_identity.dart';

import 'platform_info_stub.dart'
    if (dart.library.io) 'platform_info_io.dart'
    if (dart.library.js_interop) 'platform_info_web.dart';

const _defaultBaseUrl = 'https://api-logs.devalltech.com.br/api/v1';
const _defaultBatchSize = 10;
const _defaultFlushInterval = Duration(seconds: 30);
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

  /// Initializes the SDK with the project token and optional configuration.
  ///
  /// [projectToken] - Required. Your project token from DevAll Tech.
  /// [baseUrl] - Optional. Custom API base URL (useful for self-hosted or staging).
  /// [httpClient] - Optional. Custom HTTP client (useful for testing).
  /// [enableBatch] - Optional. Enable event batching (default: false).
  /// [batchSize] - Optional. Number of events to accumulate before sending (default: 10).
  /// [flushInterval] - Optional. Max time between batch flushes (default: 30s).
  static void init({
    required String projectToken,
    String? baseUrl,
    http.Client? httpClient,
    bool enableBatch = false,
    int batchSize = _defaultBatchSize,
    Duration flushInterval = _defaultFlushInterval,
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

    if (_batchEnabled) {
      _startFlushTimer();
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

  /// Sends events to the API with retry and exponential backoff.
  static Future<void> _sendEvents(List<Map<String, dynamic>> events) async {
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
            return; // Success
          }

          if (response.statusCode >= 500 && attempt < _maxRetries) {
            // Server error - retry with backoff
            await Future.delayed(Duration(seconds: 1 << attempt));
            continue;
          }

          // Client error or max retries reached
          if (kDebugMode) {
            print(
                'DevAllAnalytics error: ${response.statusCode} - ${response.body}');
          }
          return;
        } catch (e) {
          if (attempt < _maxRetries) {
            await Future.delayed(Duration(seconds: 1 << attempt));
            continue;
          }
          if (kDebugMode) {
            print('DevAllAnalytics failed to send event: $e');
          }
        }
      }
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

  /// Exposes the event queue length for testing purposes.
  @visibleForTesting
  static int get queueLength => _eventQueue.length;
}
