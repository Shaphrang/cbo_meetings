class VO {
  final String id;
  final String district;
  final String block;
  final String village;
  final String name;
  final String code;

  VO({
    required this.id,
    required this.district,
    required this.block,
    required this.village,
    required this.name,
    required this.code,
  });

  factory VO.fromMap(Map<String, dynamic> map) {
    return VO(
      id: map['id'],
      district: map['district'],
      block: map['block'],
      village: map['village'],
      name: map['vo_name'],
      code: map['vo_code'] ?? '',
    );
  }
}