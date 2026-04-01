//lib\features\meeting\models\clf_model.dart
class CLF {
  final String id;
  final String districtId;

  final String blockId;

  final String name;
  final String code;

  CLF({
    required this.id,
    required this.districtId,

    required this.blockId,

    required this.name,
    required this.code,
  });

  factory CLF.fromMap(Map<String, dynamic> map) {
    return CLF(
      id: map['id'],
      districtId: map['district_id'],

      blockId: map['block_id'],

      name: map['clf_name'],
      code: map['clf_code'] ?? '',
    );
  }
}