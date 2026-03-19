import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _consentKey = 'devall_consent_granted';

/// Manages user consent for GDPR/privacy compliance.
///
/// When consent is not granted, all tracking is blocked.
/// Consent state is persisted across app restarts.
class DevAllConsentManager {
  static bool? _consentGranted;

  /// Sets the user's consent status and persists it.
  static Future<void> setConsent({required bool granted}) async {
    _consentGranted = granted;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, granted);

    if (kDebugMode) {
      print('DevAllAnalytics: Consent ${granted ? "granted" : "revoked"}.');
    }
  }

  /// Returns whether consent is granted.
  ///
  /// Returns null if consent hasn't been set yet (user hasn't decided).
  /// Returns true/false based on the persisted consent state.
  static Future<bool?> isConsentGranted() async {
    if (_consentGranted != null) return _consentGranted;

    final prefs = await SharedPreferences.getInstance();
    _consentGranted = prefs.getBool(_consentKey);
    return _consentGranted;
  }

  /// Returns the cached consent value (synchronous).
  /// Returns null if not yet loaded. Call [isConsentGranted] first.
  static bool? get cachedConsent => _consentGranted;

  /// Whether tracking is allowed.
  ///
  /// Returns true if consent is granted or if consent hasn't been configured
  /// (opt-out model — tracking is on by default until user revokes).
  static bool get isTrackingAllowed => _consentGranted ?? true;

  /// Resets in-memory consent state for testing (synchronous).
  @visibleForTesting
  static void resetSync() {
    _consentGranted = null;
  }

  /// Resets consent state for testing (clears persisted state too).
  @visibleForTesting
  static Future<void> reset() async {
    _consentGranted = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_consentKey);
  }
}
