import 'package:flutter/foundation.dart';

/// Rate limiter to prevent event flooding.
///
/// Limits the number of events that can be sent within a time window.
/// Events exceeding the limit are silently dropped.
class DevAllRateLimiter {
  static int _maxEventsPerMinute = 0; // 0 = disabled
  static final List<DateTime> _timestamps = [];

  /// Sets the maximum events per minute. 0 disables rate limiting.
  static void setMaxEventsPerMinute(int max) {
    _maxEventsPerMinute = max;
  }

  /// Returns true if the event is allowed (under the rate limit).
  /// Returns false if the event should be dropped.
  static bool allowEvent() {
    if (_maxEventsPerMinute <= 0) return true;

    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(minutes: 1));

    // Remove timestamps older than 1 minute
    _timestamps.removeWhere((t) => t.isBefore(cutoff));

    if (_timestamps.length >= _maxEventsPerMinute) {
      if (kDebugMode) {
        print('DevAllAnalytics: Rate limit exceeded '
            '(${_timestamps.length}/$_maxEventsPerMinute per minute). '
            'Event dropped.');
      }
      return false;
    }

    _timestamps.add(now);
    return true;
  }

  /// Returns the current count of events in the window.
  static int get currentCount => _timestamps.length;

  /// Resets state for testing.
  @visibleForTesting
  static void reset() {
    _maxEventsPerMinute = 0;
    _timestamps.clear();
  }
}
