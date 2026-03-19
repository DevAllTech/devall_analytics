import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storageKey = 'devall_offline_events';
const _defaultMaxOfflineEvents = 500;

/// Persistent offline event storage using SharedPreferences.
///
/// When events fail to send (network error, server down, etc.),
/// they are saved locally and retried when connectivity returns.
class DevAllOfflineStorage {
  static int _maxOfflineEvents = _defaultMaxOfflineEvents;

  /// Sets the maximum number of events to keep offline.
  /// Oldest events are dropped when the limit is exceeded.
  static void setMaxOfflineEvents(int max) {
    _maxOfflineEvents = max;
  }

  /// Saves a list of failed events to persistent storage.
  static Future<void> saveEvents(List<Map<String, dynamic>> events) async {
    if (events.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final existing = await loadEvents();
    existing.addAll(events);

    // Drop oldest events if over the limit
    while (existing.length > _maxOfflineEvents) {
      existing.removeAt(0);
    }

    final encoded = jsonEncode(existing);
    await prefs.setString(_storageKey, encoded);

    if (kDebugMode) {
      print('DevAllAnalytics: ${events.length} event(s) saved offline. '
          'Total queued: ${existing.length}');
    }
  }

  /// Loads all pending offline events from storage.
  static Future<List<Map<String, dynamic>>> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('DevAllAnalytics: Failed to decode offline events: $e');
      }
      // Corrupted data - clear it
      await clear();
      return [];
    }
  }

  /// Returns the number of events stored offline.
  static Future<int> get pendingCount async {
    final events = await loadEvents();
    return events.length;
  }

  /// Clears all offline events from storage.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Resets configuration to defaults. Useful for testing.
  @visibleForTesting
  static void resetConfig() {
    _maxOfflineEvents = _defaultMaxOfflineEvents;
  }
}
