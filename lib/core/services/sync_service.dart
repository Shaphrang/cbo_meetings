//lib\core\services\sync_service.dart
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'offline_meeting_service.dart';
import 'storage_service.dart';

class SyncService {

  final supabase = Supabase.instance.client;
  final storage = StorageService();
  final offline = OfflineMeetingService();

  /// ------------------------------------------------------------
  /// Upload ONE meeting (instant submit)
  /// ------------------------------------------------------------
  Future<void> syncSingleMeeting(Map<String, dynamic> meeting) async {

    final data = Map<String, dynamic>.from(meeting);

    try {
      /// 📸 Upload image if exists
      if (data["photo_path"] != null) {
        final file = File(data["photo_path"]);

        if (await file.exists()) {
          print("📸 Uploading image...");

          final imageUrl = await storage.uploadImage(file);
          data["photo_url"] = imageUrl;
        }
      }

      data.remove("photo_path");
      data.remove("uploaded"); // ✅ add here too
      data.removeWhere((key, value) => value == null);

      /// 📡 Insert to Supabase
      final response = await supabase
          .from('meetings')
          .insert(data)
          .select();

      print("✅ Single meeting uploaded: $response");

    } catch (e) {
      print("❌ Upload failed → saving offline: $e");

      await offline.saveOffline(meeting);
      rethrow;
    }
  }

  /// ------------------------------------------------------------
  /// Sync ALL pending meetings
  /// ------------------------------------------------------------
  Future<Map<String, dynamic>> syncMeetings() async {

    final meeting = await offline.getPendingMeeting();

    if (meeting == null) {
      print("📦 No pending meeting");

      return {
        "total": 0,
        "uploaded": 0,
        "failed": 0,
      };
    }

    try {
      print("⬆️ Uploading meeting...");

      final data = Map<String, dynamic>.from(meeting);

      /// 📸 Upload image
      if (data["photo_path"] != null) {

        final file = File(data["photo_path"]);

        if (await file.exists()) {
          final imageUrl = await storage.uploadImage(file);
          data["photo_url"] = imageUrl;
        }
      }

      data.remove("photo_path");
      data.remove("uploaded"); // ✅ VERY IMPORTANT FIX
      data.removeWhere((key, value) => value == null);
      
      final response = await supabase
          .from('meetings')
          .insert(data)
          .select();

      print("✅ Upload success: $response");

      await offline.markUploaded();

      return {
        "total": 1,
        "uploaded": 1,
        "failed": 0,
      };

    } catch (e) {

      print("❌ Upload failed: $e");

      return {
        "total": 1,
        "uploaded": 0,
        "failed": 1,
      };
    }
  }
}