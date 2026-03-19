import 'package:flutter/foundation.dart';

/// Callback type for event middleware.
///
/// Receives the event data map and can:
/// - Return it modified (e.g., redact sensitive data)
/// - Return it as-is
/// - Return null to block the event from being sent
typedef DevAllEventMiddleware = Map<String, dynamic>? Function(
  Map<String, dynamic> event,
);

/// Manages a chain of middleware functions for event processing.
///
/// Middleware runs in order before each event is sent.
/// Any middleware returning null will block the event.
class DevAllMiddlewareManager {
  static final List<DevAllEventMiddleware> _middlewares = [];

  /// Adds a middleware function to the chain.
  static void add(DevAllEventMiddleware middleware) {
    _middlewares.add(middleware);
  }

  /// Removes a specific middleware function.
  static void remove(DevAllEventMiddleware middleware) {
    _middlewares.remove(middleware);
  }

  /// Clears all middleware functions.
  static void clear() {
    _middlewares.clear();
  }

  /// Processes an event through all middleware.
  ///
  /// Returns the (possibly modified) event, or null if blocked.
  static Map<String, dynamic>? process(Map<String, dynamic> event) {
    Map<String, dynamic>? current = Map.from(event);

    for (final middleware in _middlewares) {
      current = middleware(current!);
      if (current == null) {
        if (kDebugMode) {
          print('DevAllAnalytics: Event blocked by middleware.');
        }
        return null;
      }
    }

    return current;
  }

  /// Returns the number of registered middleware functions.
  static int get count => _middlewares.length;

  /// Resets state for testing.
  @visibleForTesting
  static void reset() {
    _middlewares.clear();
  }
}
