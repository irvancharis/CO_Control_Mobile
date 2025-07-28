class FeatureSubDetail {
  final String id;
  final String nama;
  bool isChecked; // untuk checkbox

  FeatureSubDetail({
    required this.id,
    required this.nama,
    this.isChecked = false,
  });

  factory FeatureSubDetail.fromJson(Map<String, dynamic> json) {
    return FeatureSubDetail(
      id: json['ID_FEATURESUBDETAIL'].toString(),
      nama: json['NAME'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'isChecked': isChecked,
      };
}

class FeatureDetail {
  final String id;
  final String nama;
  final String icon;
  final String route;
  final List<FeatureSubDetail> subDetails;

  FeatureDetail({
    required this.id,
    required this.nama,
    required this.icon,
    required this.route,
    required this.subDetails,
  });

  factory FeatureDetail.fromJson(Map<String, dynamic> json) {
    var subList = json['SUBDETAIL'] as List? ?? [];
    List<FeatureSubDetail> subDetails =
        subList.map((e) => FeatureSubDetail.fromJson(e)).toList();

    return FeatureDetail(
      id: json['ID_FEATUREDETAIL'].toString(),
      nama: json['NAME'],
      icon: json['ICON'] ?? 'extension',
      route: json['ROUTE'] ?? '/',
      subDetails: subDetails,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'icon': icon,
        'route': route,
        'subDetails': subDetails.map((e) => e.toJson()).toList(),
      };
}
