import 'dart:io';

Map<String, dynamic> getPlatformDeviceInfo() {
  return {
    'platform': getPlatformName(),
    'osVersion': _getOsVersion(),
    'locale': Platform.localeName,
    'isPhysicalDevice': true,
  };
}

String getPlatformName() {
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) return 'linux';
  return 'unknown';
}

String _getOsVersion() {
  try {
    return Platform.operatingSystemVersion;
  } catch (_) {
    return 'unknown';
  }
}
