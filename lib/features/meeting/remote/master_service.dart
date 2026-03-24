//lib\features\meeting\remote\master_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class MasterService {

  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchVOs() async {

    List<Map<String, dynamic>> allData = [];

    int from = 0;
    const batchSize = 1000;

    while (true) {

      final data = await supabase
          .from('vos')
          .select()
          .range(from, from + batchSize - 1);

      if (data.isEmpty) break;

      allData.addAll(List<Map<String, dynamic>>.from(data));

      from += batchSize;
    }

    return allData;
  }

  Future<List<Map<String, dynamic>>> fetchCLFs() async {

    final data = await supabase
        .from('clfs')
        .select();

    return List<Map<String, dynamic>>.from(data);
  }
}