import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:cbo_meetings/core/services/offline_meeting_service.dart';

void main() {
  late Directory tempDir;
  late OfflineMeetingService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cbo_meetings_test');
    Hive.init(tempDir.path);
    await Hive.openBox(OfflineMeetingService.boxName);
    service = OfflineMeetingService();
  });

  tearDown(() async {
    await Hive.box(OfflineMeetingService.boxName).deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test('saveOffline stores a pending record and count increments', () async {
    final id = await service.saveOffline({
      'meeting_type': 'VO',
      'district_id': 'd1',
      'block_id': 'b1',
      'member_name': 'A',
    });

    final count = await service.getPendingCount();
    final first = await service.getPendingMeeting();

    expect(id, isNotEmpty);
    expect(count, 1);
    expect(first?['local_id'], id);
    expect(first?['status'], 'pending');
  });

  test('duplicate fingerprint is not enqueued twice', () async {
    final payload = {
      'meeting_type': 'VO',
      'district_id': 'd1',
      'block_id': 'b1',
      'member_name': 'A',
    };

    final firstId = await service.saveOffline(payload);
    final secondId = await service.saveOffline(payload);

    expect(firstId, secondId);
    expect(await service.getPendingCount(), 1);
  });

  test('markUploaded and clearSynced remove synced entries', () async {
    final id = await service.saveOffline({
      'meeting_type': 'CLF',
      'district_id': 'd1',
      'block_id': 'b1',
    });

    await service.markUploaded(id, remoteId: 'remote_1');
    expect(await service.getPendingCount(), 0);

    await service.clearSynced();
    final pending = await service.getPendingMeetings();
    expect(pending, isEmpty);
  });
}
