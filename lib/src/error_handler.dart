import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Callback type for handling captured errors.
typedef DevAllErrorCallback = Future<void> Function(
  dynamic error,
  StackTrace? stackTrace,
  String source,
);

/// Global error handler that captures Flutter and Dart errors automatically.
///
/// Registers handlers for:
/// - [FlutterError.onError] - Framework errors (widget build, layout, etc.)
/// - [PlatformDispatcher.instance.onError] - Uncaught async errors
class DevAllErrorHandler {
  static FlutterExceptionHandler? _previousFlutterHandler;
  static ErrorCallback? _previousPlatformHandler;
  static DevAllErrorCallback? _onError;
  static bool _installed = false;

  /// Installs global error handlers.
  ///
  /// [onError] is called for each captured error with the error, stack trace,
  /// and a source string ('flutter' or 'platform').
  static void install(DevAllErrorCallback onError) {
    if (_installed) return;

    _onError = onError;
    _installed = true;

    // Capture Flutter framework errors
    _previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = _handleFlutterError;

    // Capture uncaught platform errors
    _previousPlatformHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = _handlePlatformError;

    if (kDebugMode) {
      print('DevAllAnalytics: Global error handlers installed.');
    }
  }

  /// Uninstalls global error handlers, restoring previous handlers.
  static void uninstall() {
    if (!_installed) return;

    FlutterError.onError = _previousFlutterHandler;
    PlatformDispatcher.instance.onError = _previousPlatformHandler;

    _previousFlutterHandler = null;
    _previousPlatformHandler = null;
    _onError = null;
    _installed = false;
  }

  /// Whether error handlers are currently installed.
  static bool get isInstalled => _installed;

  static void _handleFlutterError(FlutterErrorDetails details) {
    _onError?.call(
      details.exception,
      details.stack,
      'flutter',
    );

    // Forward to previous handler
    if (_previousFlutterHandler != null) {
      _previousFlutterHandler!(details);
    }
  }

  static bool _handlePlatformError(Object error, StackTrace stack) {
    _onError?.call(error, stack, 'platform');

    // Forward to previous handler
    if (_previousPlatformHandler != null) {
      return _previousPlatformHandler!(error, stack);
    }
    return false;
  }

  /// Resets state for testing.
  @visibleForTesting
  static void reset() {
    uninstall();
  }
}
