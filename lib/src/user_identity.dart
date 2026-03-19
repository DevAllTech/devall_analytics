import 'package:flutter/foundation.dart';

/// Manages user identity for associating events with logged-in users.
///
/// Usage:
/// ```dart
/// DevAllAnalytics.identify(userId: '123', traits: {'email': 'x@y.com'});
/// DevAllAnalytics.clearIdentity();
/// ```
class DevAllUserIdentity {
  static String? _userId;
  static Map<String, dynamic> _traits = {};

  /// Sets the current user identity.
  static void identify({
    required String userId,
    Map<String, dynamic>? traits,
  }) {
    if (userId.trim().isEmpty) {
      throw ArgumentError('userId must not be empty.');
    }
    _userId = userId;
    _traits = traits ?? {};

    if (kDebugMode) {
      print('DevAllAnalytics: User identified as $userId');
    }
  }

  /// Clears the current user identity (e.g., on logout).
  static void clear() {
    _userId = null;
    _traits = {};
  }

  /// Returns the current userId, or null if not identified.
  static String? get userId => _userId;

  /// Returns the current user traits.
  static Map<String, dynamic> get traits => Map.unmodifiable(_traits);

  /// Returns user data to embed in events, or empty map if not identified.
  static Map<String, dynamic> toEventData() {
    if (_userId == null) return {};
    return {
      'userId': _userId,
      if (_traits.isNotEmpty) 'userTraits': _traits,
    };
  }

  /// Resets state for testing.
  @visibleForTesting
  static void reset() {
    _userId = null;
    _traits = {};
  }
}
