//lib\features\meeting\controller\master_controller.dart
import '../../../core/services/master_data_service.dart';
import '../remote/master_service.dart';
import 'package:flutter/foundation.dart';

class MasterController {
  final MasterDataService cache = MasterDataService();
  final MasterService api = MasterService();

  List<Map<String, dynamic>> allVOs = [];
  List<Map<String, dynamic>> allCLFs = [];

  Future<void> loadMasterData() async {
    allVOs = cache.getVOs();
    allCLFs = cache.getCLFs();

    if (allVOs.isEmpty && allCLFs.isEmpty) {
      debugPrint("⚡ Fetching from API");

      final vos = await api.fetchVOs();
      final clfs = await api.fetchCLFs();

      allVOs = List<Map<String, dynamic>>.from(vos);
      allCLFs = List<Map<String, dynamic>>.from(clfs);

      await cache.syncMasterData();
    }

    debugPrint("VO count: ${allVOs.length}");
    debugPrint("CLF count: ${allCLFs.length}");
  }

  /// STRICT ACCESS (NO FALLBACK)
  String _district(Map e) => e['districts']['name'];
  String _block(Map e) => e['blocks']['name'];

  List<String> getDistricts(String type) {
    final data = type == "VO" ? allVOs : allCLFs;

    return data
        .map((e) => _district(e))
        .toSet()
        .toList()
      ..sort();
  }

  String? getDistrictId(String districtName) {
    final data = [...allVOs, ...allCLFs];

    for (var e in data) {
      if (_district(e) == districtName) {
        return e['district_id'];
      }
    }
    return null;
  }

  List<String> getBlocks(String type, String districtName) {
    final data = type == "VO" ? allVOs : allCLFs;

    return data
        .where((e) => _district(e) == districtName)
        .map((e) => _block(e))
        .toSet()
        .toList()
      ..sort();
  }

  String? getBlockId(String districtName, String blockName) {
    final data = [...allVOs, ...allCLFs];

    for (var e in data) {
      if (_district(e) == districtName && _block(e) == blockName) {
        return e['block_id'];
      }
    }
    return null;
  }

  List<String> getVillages(String district, String block) {
    return allVOs
        .where((e) => _district(e) == district && _block(e) == block)
        .map((e) => e['village'].toString())
        .toSet()
        .toList()
      ..sort();
  }

  List<String> getVOs(String district, String block, String village) {
    return allVOs
        .where((e) =>
            _district(e) == district &&
            _block(e) == block &&
            e['village'] == village)
        .map((e) => e['vo_name'].toString())
        .toList();
  }

  List<String> getCLFs(String district, String block) {
    return allCLFs
        .where((e) =>
            _district(e) == district &&
            _block(e) == block)
        .map((e) => e['clf_name'].toString())
        .toList();
  }

  /// ------------------------------------------------------------
  /// 🔐 AUTH CODE GETTERS (FAST LOOKUP - NO LOOPING FULL DATA)
  /// ------------------------------------------------------------

  String? getVOAuthCode(
    String district,
    String block,
    String village,
    String voName,
  ) {
    try {
      final match = allVOs.firstWhere(
        (e) =>
            _district(e) == district &&
            _block(e) == block &&
            e['village'] == village &&
            e['vo_name'] == voName,
      );

      return match['auth_code'];
    } catch (e) {
      return null;
    }
  }

  String? getCLFAuthCode(
    String district,
    String block,
    String clfName,
  ) {
    try {
      final match = allCLFs.firstWhere(
        (e) =>
            _district(e) == district &&
            _block(e) == block &&
            e['clf_name'] == clfName,
      );

      return match['auth_code'];
    } catch (e) {
      return null;
    }
  }
}