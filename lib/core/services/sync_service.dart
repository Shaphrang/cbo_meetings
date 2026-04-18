import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'offline_meeting_service.dart';
import 'storage_service.dart';

class SyncService {
  SyncService({OfflineMeetingService? offlineMeetingService})
      : offline = offlineMeetingService ?? OfflineMeetingService();

  final supabase = Supabase.instance.client;
  final storage = StorageService();
  final OfflineMeetingService offline;

  static bool _syncInProgress = false;

  Future<Map<String, dynamic>> _preparePayload(Map<String, dynamic> meeting) async {
    final data = Map<String, dynamic>.from(meeting);

    final photoPath = data['photo_path']?.toString();
    if (photoPath != null && photoPath.isNotEmpty) {
      final file = File(photoPath);
      if (await file.exists()) {
        final imageUrl = await storage.uploadImage(file).timeout(const Duration(seconds: 25));
        data['photo_url'] = imageUrl;
      }
    }

    data.remove('photo_path');
    data.remove('uploaded');
    data.remove('local_id');
    data.remove('status');
    data.remove('sync_attempts');
    data.remove('last_error');
    data.remove('updated_at');
    data.remove('fingerprint');
    data.remove('remote_id');
    data.removeWhere((_, value) => value == null);

    if (data['district_id'] == null || data['block_id'] == null) {
      throw Exception('Missing district_id or block_id');
    }

    return data;
  }

  /// Upload one meeting payload. If localId is passed, queue state is updated.
  Future<void> syncSingleMeeting(
    Map<String, dynamic> meeting, {
    String? localId,
  }) async {
    try {
      if (localId != null) {
        await offline.markSyncing(localId);
      }

      final payload = await _preparePayload(meeting);
      final response = await supabase
          .from('meetings')
          .insert(payload)
          .select('id')
          .timeout(const Duration(seconds: 25));

      final inserted = List<Map<String, dynamic>>.from(response);
      final remoteId = inserted.isNotEmpty ? inserted.first['id']?.toString() : null;

      if (localId != null) {
        await offline.markUploaded(localId, remoteId: remoteId);
      }

      debugPrint('✅ Meeting uploaded local_id=$localId remote_id=$remoteId');
    } catch (e) {
      if (localId != null) {
        await offline.markFailed(localId, e);
      }
      rethrow;
    }
  }

  /// Sync all pending meetings with guard against concurrent loops.
  Future<Map<String, dynamic>> syncMeetings() async {
    if (_syncInProgress) {
      return {'total': 0, 'uploaded': 0, 'failed': 0, 'busy': true};
    }

    _syncInProgress = true;
    try {
      final pending = await offline.getPendingMeetings();
      if (pending.isEmpty) {
        return {'total': 0, 'uploaded': 0, 'failed': 0, 'busy': false};
      }

      var uploaded = 0;
      var failed = 0;

      for (final item in pending) {
        final localId = item['local_id']?.toString();
        if (localId == null) {
          failed++;
          continue;
        }

        try {
          await syncSingleMeeting(item, localId: localId);
          uploaded++;
        } catch (e) {
          failed++;
          debugPrint('❌ Sync failed for $localId: $e');
        }
      }

      if (uploaded > 0) {
        await offline.clearSynced();
      }

      return {
        'total': pending.length,
        'uploaded': uploaded,
        'failed': failed,
        'busy': false,
      };
    } finally {
      _syncInProgress = false;
    }
  }
}
