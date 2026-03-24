//lib\core\services\offline_meeting_service.dart

import 'package:hive_flutter/hive_flutter.dart';

class OfflineMeetingService {

  static const String boxName = 'offline_meetings';
  static const String key = 'latest_meeting';

  Box get _box => Hive.box(boxName);

  /// Save (overwrite always)
  Future<void> saveOffline(Map<String, dynamic> meeting) async {
    await _box.put(key, {
      ...meeting,
      "uploaded": false,
    });

    print("💾 Saved latest offline meeting");
  }

  /// Get pending
  Future<Map<String, dynamic>?> getPendingMeeting() async {
    final data = _box.get(key);

    if (data == null || data["uploaded"] == true) {
      return null;
    }

    return Map<String, dynamic>.from(data);
  }

  /// Mark uploaded
  Future<void> markUploaded() async {
    final data = _box.get(key);

    if (data == null) return;

    final map = Map<String, dynamic>.from(data);
    map["uploaded"] = true;

    await _box.put(key, map);

    print("✅ Marked meeting as uploaded");
  }

  /// Clear
  Future<void> clear() async {
    await _box.delete(key);
  }
}