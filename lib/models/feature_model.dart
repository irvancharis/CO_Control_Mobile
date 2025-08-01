class Feature {
  final String id;
  final String nama;
  final String icon;

  Feature({
    required this.id,
    required this.nama,
    required this.icon,
  });

  // FROM API JSON
  factory Feature.fromJson(Map<String, dynamic> json) => Feature(
        id: json['ID_FEATURE']?.toString() ?? '',
        nama: json['NAMA'] ?? '',
        icon: json['ICON'] ?? '',
      );

  // FROM DB MAP
  factory Feature.fromMap(Map<String, dynamic> map) => Feature(
        id: map['id']?.toString() ?? '',
        nama: map['nama'] ?? '',
        icon: map['icon'] ?? '',
      );

  // TO DB MAP
  Map<String, dynamic> toMap() => {
        'id': id,
        'nama': nama,
        'icon': icon,
      };
}
