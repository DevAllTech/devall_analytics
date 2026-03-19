import 'package:flutter/foundation.dart';

/// Callback type for screen duration events.
typedef DevAllScreenCallback = void Function(
  String screenName,
  Duration duration,
);

/// Tracks screen views and their duration for performance metrics.
///
/// Usage:
/// ```dart
/// DevAllAnalytics.trackScreen('HomePage');
/// // ... user navigates away
/// DevAllAnalytics.trackScreen('ProfilePage'); // auto-ends previous screen
/// ```
class DevAllScreenTracker {
  static String? _currentScreen;
  static DateTime? _screenStart;
  static DevAllScreenCallback? _onScreenEnd;

  /// Sets the callback fired when a screen view ends.
  static void setOnScreenEnd(DevAllScreenCallback? callback) {
    _onScreenEnd = callback;
  }

  /// Starts tracking a new screen.
  /// Automatically ends tracking of the previous screen.
  static void trackScreen(String screenName) {
    // End previous screen tracking
    _endCurrentScreen();

    _currentScreen = screenName;
    _screenStart = DateTime.now();

    if (kDebugMode) {
      print('DevAllAnalytics: Screen view started: $screenName');
    }
  }

  /// Ends tracking of the current screen.
  static void endScreen() {
    _endCurrentScreen();
    _currentScreen = null;
    _screenStart = null;
  }

  /// Returns the current screen name, or null.
  static String? get currentScreen => _currentScreen;

  /// Returns screen data to embed in events.
  static Map<String, dynamic> toEventData() {
    if (_currentScreen == null) return {};
    return {'screen': _currentScreen};
  }

  static void _endCurrentScreen() {
    if (_currentScreen != null && _screenStart != null) {
      final duration = DateTime.now().difference(_screenStart!);
      _onScreenEnd?.call(_currentScreen!, duration);
    }
  }

  /// Resets state for testing.
  @visibleForTesting
  static void reset() {
    _currentScreen = null;
    _screenStart = null;
    _onScreenEnd = null;
  }
}
