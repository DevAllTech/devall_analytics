import 'package:flutter/foundation.dart';

/// Interface for custom event destinations.
///
/// Implement this to forward events to external services
/// like Sentry, Firebase, Mixpanel, etc.
///
/// Example:
/// ```dart
/// class SentryDestination implements DevAllEventDestination {
///   @override
///   String get name => 'Sentry';
///
///   @override
///   Future<void> sendEvent(Map<String, dynamic> event) async {
///     // Forward to Sentry SDK
///   }
/// }
///
/// DevAllAnalytics.addDestination(SentryDestination());
/// ```
abstract class DevAllEventDestination {
  /// Name of this destination (for debug logs).
  String get name;

  /// Sends an event to this destination.
  Future<void> sendEvent(Map<String, dynamic> event);
}

/// Manages multiple event destinations for multi-service forwarding.
class DevAllDestinationManager {
  static final List<DevAllEventDestination> _destinations = [];

  /// Adds a destination.
  static void add(DevAllEventDestination destination) {
    _destinations.add(destination);
    if (kDebugMode) {
      print('DevAllAnalytics: Destination added: ${destination.name}');
    }
  }

  /// Removes a destination.
  static void remove(DevAllEventDestination destination) {
    _destinations.remove(destination);
  }

  /// Clears all destinations.
  static void clear() {
    _destinations.clear();
  }

  /// Forwards an event to all registered destinations.
  /// Errors in individual destinations don't block others.
  static Future<void> forwardEvent(Map<String, dynamic> event) async {
    for (final destination in _destinations) {
      try {
        await destination.sendEvent(event);
      } catch (e) {
        if (kDebugMode) {
          print('DevAllAnalytics: Destination "${destination.name}" '
              'failed: $e');
        }
      }
    }
  }

  /// Returns the number of registered destinations.
  static int get count => _destinations.length;

  /// Returns the names of all registered destinations.
  static List<String> get destinationNames =>
      _destinations.map((d) => d.name).toList();

  /// Resets state for testing.
  @visibleForTesting
  static void reset() {
    _destinations.clear();
  }
}
