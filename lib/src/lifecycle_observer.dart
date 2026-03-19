import 'package:flutter/widgets.dart';

/// Callback type for lifecycle events.
typedef DevAllLifecycleCallback = void Function(String event);

/// Observes app lifecycle events and fires callbacks.
///
/// Automatically tracks: app_open, app_resumed, app_paused, app_detached.
class DevAllLifecycleObserver with WidgetsBindingObserver {
  final DevAllLifecycleCallback _onLifecycleEvent;
  static DevAllLifecycleObserver? _instance;

  DevAllLifecycleObserver._(this._onLifecycleEvent);

  /// Installs the lifecycle observer.
  static void install(DevAllLifecycleCallback onLifecycleEvent) {
    if (_instance != null) return;

    _instance = DevAllLifecycleObserver._(onLifecycleEvent);
    WidgetsBinding.instance.addObserver(_instance!);

    // Fire initial app_open event
    onLifecycleEvent('app_open');
  }

  /// Uninstalls the lifecycle observer.
  static void uninstall() {
    if (_instance == null) return;
    WidgetsBinding.instance.removeObserver(_instance!);
    _instance = null;
  }

  /// Whether the observer is currently installed.
  static bool get isInstalled => _instance != null;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _onLifecycleEvent('app_resumed');
        break;
      case AppLifecycleState.paused:
        _onLifecycleEvent('app_paused');
        break;
      case AppLifecycleState.detached:
        _onLifecycleEvent('app_detached');
        break;
      case AppLifecycleState.inactive:
        _onLifecycleEvent('app_inactive');
        break;
      case AppLifecycleState.hidden:
        _onLifecycleEvent('app_hidden');
        break;
    }
  }

  /// Resets state for testing.
  static void reset() {
    uninstall();
  }
}
