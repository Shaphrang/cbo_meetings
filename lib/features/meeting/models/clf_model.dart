class CLF {
  final String id;
  final String district;
  final String block;
  final String name;
  final String code;

  CLF({
    required this.id,
    required this.district,
    required this.block,
    required this.name,
    required this.code,
  });

  factory CLF.fromMap(Map<String, dynamic> map) {
    return CLF(
      id: map['id'],
      district: map['district'],
      block: map['block'],
      name: map['clf_name'],
      code: map['clf_code'] ?? '',
    );
  }
}