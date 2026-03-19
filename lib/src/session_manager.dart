import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Manages session tracking for grouping events by app session.
///
/// A new session is created on [start] and ended on [end].
/// The sessionId is included in all events while active.
class DevAllSessionManager {
  static String? _sessionId;
  static DateTime? _sessionStart;
  static const _uuid = Uuid();

  /// Starts a new session, generating a unique sessionId.
  static String start() {
    _sessionId = _uuid.v4();
    _sessionStart = DateTime.now();

    if (kDebugMode) {
      print('DevAllAnalytics: Session started ($_sessionId)');
    }
    return _sessionId!;
  }

  /// Ends the current session.
  static void end() {
    if (kDebugMode && _sessionId != null) {
      final duration = DateTime.now().difference(_sessionStart!);
      print('DevAllAnalytics: Session ended ($_sessionId) '
          'duration: ${duration.inSeconds}s');
    }
    _sessionId = null;
    _sessionStart = null;
  }

  /// Returns the current sessionId, or null if no active session.
  static String? get sessionId => _sessionId;

  /// Returns the session start time, or null if no active session.
  static DateTime? get sessionStart => _sessionStart;

  /// Returns session data to embed in events, or empty map if no session.
  static Map<String, dynamic> toEventData() {
    if (_sessionId == null) return {};
    return {
      'sessionId': _sessionId,
      'sessionStart': _sessionStart?.toUtc().toIso8601String(),
    };
  }

  /// Resets state for testing.
  @visibleForTesting
  static void reset() {
    _sessionId = null;
    _sessionStart = null;
  }
}
