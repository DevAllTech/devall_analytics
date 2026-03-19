/// Stub implementation - should never be called directly.
/// Used as the default for conditional imports.
Map<String, dynamic> getPlatformDeviceInfo() {
  throw UnsupportedError('Cannot get device info without dart:io or dart:html');
}

String getPlatformName() {
  return 'unknown';
}
