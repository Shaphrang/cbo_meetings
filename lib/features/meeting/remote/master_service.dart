import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class MasterService {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchVOs() async {
    final allData = <Map<String, dynamic>>[];
    var from = 0;
    const batchSize = 1000;

    while (true) {
      final data = await supabase
          .from('vos')
          .select('''
            id,
            vo_name,
            vo_code,
            village,
            auth_code,
            district_id,
            block_id,
            districts(name),
            blocks(name)
          ''')
          .range(from, from + batchSize - 1)
          .timeout(const Duration(seconds: 20));

      if (data.isEmpty) break;
      allData.addAll(List<Map<String, dynamic>>.from(data));
      from += batchSize;
    }

    return allData;
  }

  Future<List<Map<String, dynamic>>> fetchCLFs() async {
    final allData = <Map<String, dynamic>>[];
    var from = 0;
    const batchSize = 1000;

    while (true) {
      final data = await supabase
          .from('clfs')
          .select('''
            id,
            clf_name,
            clf_code,
            auth_code,
            district_id,
            block_id,
            districts(name),
            blocks(name)
          ''')
          .range(from, from + batchSize - 1)
          .timeout(const Duration(seconds: 20));

      if (data.isEmpty) break;
      allData.addAll(List<Map<String, dynamic>>.from(data));
      from += batchSize;
    }

    return allData;
  }
}
