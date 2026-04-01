//lib\features\meeting\models\vo_model.dart
class VO {
  final String id;
  final String districtId;

  final String blockId;

  final String village;
  final String name;
  final String code;

  VO({
    required this.id,
    required this.districtId,

    required this.blockId,

    required this.village,
    required this.name,
    required this.code,
  });

  factory VO.fromMap(Map<String, dynamic> map) {
    return VO(
      id: map['id'],
      districtId: map['district_id'],

      blockId: map['block_id'],

      village: map['village'],
      name: map['vo_name'],
      code: map['vo_code'] ?? '',
    );
  }
}