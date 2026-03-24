//lib\features\meeting\controller\master_controller.dart
import '../../../core/services/master_data_service.dart';
import '../remote/master_service.dart';

class MasterController {

  final MasterDataService cache = MasterDataService();
  final MasterService api = MasterService();

  List<Map<String,dynamic>> allVOs = [];
  List<Map<String,dynamic>> allCLFs = [];

  Future<void> loadMasterData() async {

    /// Load from cache
    allVOs = cache.getVOs();
    allCLFs = cache.getCLFs();

    /// If cache empty → fetch directly
    if(allVOs.isEmpty || allCLFs.isEmpty){

      print("Cache empty → fetching from Supabase");

      final vos = await api.fetchVOs();
      final clfs = await api.fetchCLFs();

      allVOs = List<Map<String,dynamic>>.from(
          vos.map((e)=>Map<String,dynamic>.from(e)));

      allCLFs = List<Map<String,dynamic>>.from(
          clfs.map((e)=>Map<String,dynamic>.from(e)));

      await cache.syncMasterData();
    }

    print("VO count: ${allVOs.length}");
    print("CLF count: ${allCLFs.length}");
  }

  List<String> getDistricts(String type){

    final data = type == "VO" ? allVOs : allCLFs;

    return data
        .map((e)=> e['district'].toString())
        .toSet()
        .toList()
      ..sort();
  }

  List<String> getBlocks(String type,String district){

    final data = type == "VO" ? allVOs : allCLFs;

    return data
        .where((e)=> e['district']==district)
        .map((e)=> e['block'].toString())
        .toSet()
        .toList()
      ..sort();
  }

  List<String> getVillages(String district,String block){

    return allVOs
        .where((e)=>
            e['district']==district &&
            e['block']==block)
        .map((e)=> e['village'].toString())
        .toSet()
        .toList()
      ..sort();
  }

  List<String> getVOs(String district,String block,String village){

    return allVOs
        .where((e)=>
            e['district']==district &&
            e['block']==block &&
            e['village']==village)
        .map((e)=> e['vo_name'].toString())
        .toList();
  }

  List<String> getCLFs(String district,String block){

    return allCLFs
        .where((e)=>
            e['district']==district &&
            e['block']==block)
        .map((e)=> e['clf_name'].toString())
        .toList();
  }
}