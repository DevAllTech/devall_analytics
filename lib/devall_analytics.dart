library devall_analytics;

import 'dart:io';

import 'package:devall_analytics/enums.dart';
import 'package:devall_analytics/device_identity.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DevAllAnalytics {
  static String? _projectToken;

  static void init({required String projectToken}) {
    _projectToken = projectToken;
  }

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
    if (_projectToken == null) {
      throw Exception('DevallAnalytics not initialized. Call init() first.');
    }

    final deviceId = await DevAllDeviceIdentity.getOrCreateDeviceId();
    timestamp ??= DateTime.now();
    deviceInfo ??= await getDefaultDeviceInfo();

    final body = {
      "deviceId": deviceId,
      "timestamp": timestamp.toUtc().toIso8601String(),
      "type": type.name,
      "environment": environment.name,
      "category": category,
      "message": message,
      "payload": payload,
      "deviceInfo": deviceInfo,
      "ip": ip,
    };

    try {
      final response = await http.post(
        Uri.parse('https://api-logs.devalltech.com.br/api/v1/events'),
        headers: {
          'Content-Type': 'application/json',
          'x-project-token': _projectToken!,
        },
        body: jsonEncode(body),
      );

      if (response.statusCode >= 400) {
        if (kDebugMode) {
          print(
              'DevallAnalytics error: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('DevallAnalytics failed to send event: $e');
      }
    }
  }

  static Future<Map<String, dynamic>> getDefaultDeviceInfo() async {
    String platform = _getPlatform();
    String osVersion = _getOsVersion();

    return {
      'platform': platform,
      'osVersion': osVersion,
      'locale': Platform.localeName,
      'isPhysicalDevice': !kIsWeb,
    };
  }

  static String _getPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  static String _getOsVersion() {
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return 'unknown';
    }
  }
}
