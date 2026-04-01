//lib\core\services\master_data_service.dart
import 'package:hive/hive.dart';
import '../../features/meeting/remote/master_service.dart';
import 'package:flutter/foundation.dart';

class MasterDataService {
  final box = Hive.box('offline_meetings');
  final MasterService api = MasterService();

  Future<void> syncMasterData() async {
    try {
      final vos = await api.fetchVOs();
      final clfs = await api.fetchCLFs();

      debugPrint("VO fetched: ${vos.length}");
      debugPrint("CLF fetched: ${clfs.length}");

      await box.put("vos_master", vos);
      await box.put("clfs_master", clfs);

      debugPrint("✅ Master data synced");
    } catch (e) {
      debugPrint("❌ Master sync error: $e");
    }
  }

  List<Map<String, dynamic>> getVOs() {
    final data = box.get("vos_master");

    if (data == null) return [];

    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  List<Map<String, dynamic>> getCLFs() {
    final data = box.get("clfs_master");

    if (data == null) return [];

    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e)),
    );
  }
}