import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../features/meeting/remote/master_service.dart';

class MasterDataService {
  final box = Hive.box('offline_meetings');
  final MasterService api = MasterService();

  Future<void> syncMasterData() async {
    try {
      final vos = await api.fetchVOs();
      final clfs = await api.fetchCLFs();

      if (vos.isNotEmpty) {
        await box.put('vos_master', vos);
      }
      if (clfs.isNotEmpty) {
        await box.put('clfs_master', clfs);
      }

      debugPrint('✅ Master data synced (VO=${vos.length}, CLF=${clfs.length})');
    } catch (e) {
      debugPrint('❌ Master sync error: $e');
    }
  }

  List<Map<String, dynamic>> getVOs() => _safeList('vos_master');

  List<Map<String, dynamic>> getCLFs() => _safeList('clfs_master');

  List<Map<String, dynamic>> _safeList(String key) {
    try {
      final data = box.get(key);
      if (data == null || data is! List) return [];

      return List<Map<String, dynamic>>.from(
        data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (e) {
      debugPrint('⚠️ Corrupted master cache for $key: $e');
      box.delete(key);
      return [];
    }
  }
}
