class FeatureItem {
  final String id; // UUID
  final String nama;
  final String route;
  final String icon;

  FeatureItem({
    required this.id,
    required this.nama,
    required this.route,
    required this.icon,
  });

  factory FeatureItem.fromJson(Map<String, dynamic> json) {
    return FeatureItem(
      id: json['ID_FEATURE'], // Tetap ambil dari kolom ini
      nama: json['NAMA'] ?? '',
      route: json['ROUTE'] ?? '',
      icon: json['ICON'] ?? 'home',
    );
  }
}
