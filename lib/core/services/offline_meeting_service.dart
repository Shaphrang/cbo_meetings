import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class OfflineMeetingService {
  static const String boxName = 'offline_meetings';

  // Legacy key kept for migration compatibility.
  static const String _legacyKey = 'latest_meeting';
  static const String _recordsKey = 'meeting_records_v2';

  Box get _box => Hive.box(boxName);

  Future<List<Map<String, dynamic>>> _readRecords() async {
    await _migrateLegacyIfNeeded();

    final raw = _box.get(_recordsKey);
    if (raw == null) return [];

    return List<Map<String, dynamic>>.from(
      (raw as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  Future<void> _writeRecords(List<Map<String, dynamic>> records) async {
    await _box.put(_recordsKey, records);
  }

  Future<void> _migrateLegacyIfNeeded() async {
    final legacy = _box.get(_legacyKey);
    if (legacy == null) return;

    final recordsRaw = _box.get(_recordsKey);
    if (recordsRaw != null) {
      await _box.delete(_legacyKey);
      return;
    }

    final map = Map<String, dynamic>.from(legacy as Map);
    if (map['uploaded'] == true) {
      await _box.delete(_legacyKey);
      return;
    }

    final localId = _newLocalId();
    final migrated = {
      ...map,
      'local_id': localId,
      'status': 'pending',
      'sync_attempts': 0,
      'last_error': null,
      'created_at': map['created_at'] ?? DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'fingerprint': _fingerprint(map),
    };

    await _box.put(_recordsKey, [migrated]);
    await _box.delete(_legacyKey);
  }

  String _newLocalId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = Random.secure().nextInt(1 << 32).toRadixString(16);
    return 'm_${now}_$rand';
  }

  String _fingerprint(Map<String, dynamic> meeting) {
    final normalized = Map<String, dynamic>.from(meeting)
      ..remove('uploaded')
      ..remove('last_error')
      ..remove('sync_attempts')
      ..remove('status')
      ..remove('local_id')
      ..remove('updated_at')
      ..remove('remote_id');

    return base64UrlEncode(utf8.encode(jsonEncode(normalized)));
  }

  /// Offline-first save with dedupe to avoid accidental double taps.
  Future<String> saveOffline(Map<String, dynamic> meeting) async {
    final records = await _readRecords();
    final fingerprint = _fingerprint(meeting);

    for (final record in records) {
      final status = record['status'] as String? ?? 'pending';
      if ((status == 'pending' || status == 'failed' || status == 'syncing') &&
          record['fingerprint'] == fingerprint) {
        debugPrint('ℹ️ Duplicate offline save ignored for local_id=${record['local_id']}');
        return record['local_id'] as String;
      }
    }

    final localId = _newLocalId();
    records.add({
      ...meeting,
      'local_id': localId,
      'status': 'pending',
      'sync_attempts': 0,
      'last_error': null,
      'remote_id': null,
      'created_at': meeting['created_at'] ?? DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'fingerprint': fingerprint,
    });

    await _writeRecords(records);
    debugPrint('💾 Offline meeting queued: $localId');
    return localId;
  }

  Future<List<Map<String, dynamic>>> getPendingMeetings({int? limit}) async {
    final records = await _readRecords();

    final pending = records
        .where((e) =>
            (e['status'] == 'pending' || e['status'] == 'failed') &&
            e['local_id'] != null)
        .toList()
      ..sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
        if (aDate == null || bDate == null) return 0;
        return aDate.compareTo(bDate);
      });

    if (limit == null || limit >= pending.length) return pending;
    return pending.take(limit).toList();
  }

  Future<Map<String, dynamic>?> getPendingMeeting() async {
    final items = await getPendingMeetings(limit: 1);
    return items.isEmpty ? null : items.first;
  }

  Future<int> getPendingCount() async {
    final pending = await getPendingMeetings();
    return pending.length;
  }

  Future<void> markSyncing(String localId) async {
    await _mutateById(localId, (record) {
      record['status'] = 'syncing';
      record['updated_at'] = DateTime.now().toIso8601String();
    });
  }

  Future<void> markUploaded(String localId, {String? remoteId}) async {
    await _mutateById(localId, (record) {
      record['status'] = 'synced';
      record['uploaded'] = true;
      record['remote_id'] = remoteId;
      record['last_error'] = null;
      record['updated_at'] = DateTime.now().toIso8601String();
    });
  }

  Future<void> markFailed(String localId, Object error) async {
    await _mutateById(localId, (record) {
      record['status'] = 'failed';
      record['last_error'] = error.toString();
      record['sync_attempts'] = (record['sync_attempts'] as int? ?? 0) + 1;
      record['updated_at'] = DateTime.now().toIso8601String();
    });
  }

  Future<void> clearSynced() async {
    final records = await _readRecords();
    final filtered = records.where((e) => e['status'] != 'synced').toList();
    await _writeRecords(filtered);
  }

  Future<void> clear() async {
    await _box.delete(_recordsKey);
    await _box.delete(_legacyKey);
  }

  Future<void> _mutateById(
    String localId,
    void Function(Map<String, dynamic>) update,
  ) async {
    final records = await _readRecords();
    final index = records.indexWhere((e) => e['local_id'] == localId);
    if (index == -1) return;

    final updated = Map<String, dynamic>.from(records[index]);
    update(updated);
    records[index] = updated;

    await _writeRecords(records);
  }
}
