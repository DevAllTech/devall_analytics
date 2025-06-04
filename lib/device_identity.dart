import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DevAllDeviceIdentity {
  static const _key = 'device_id';

  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_key);

    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString(_key, deviceId);
    }

    return deviceId;
  }
}
