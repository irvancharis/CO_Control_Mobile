class FeatureSubDetail {
  final String id; // ID_FEATURESUBDETAIL
  final String idFeatureDetail; // ID_FEATUREDETAIL
  final String nama; // NAME
  final int seq; // SEQ
  final int isRequired; // IS_REQUIRED
  final int isActive; // IS_ACTIVE
  final String? keterangan; // KETERANGAN
  final String? icon; // ICON
  final String? type; // TYPE

  bool isChecked; // UI-only

  FeatureSubDetail({
    required this.id,
    required this.idFeatureDetail,
    required this.nama,
    required this.seq,
    required this.isRequired,
    required this.isActive,
    this.keterangan,
    this.icon,
    this.type,
    this.isChecked = false,
  });

  /// ✅ Parsing dari JSON API (server)
  factory FeatureSubDetail.fromJson(Map<String, dynamic> json) {
    return FeatureSubDetail(
      id: json['ID_FEATURESUBDETAIL']?.toString() ?? '',
      idFeatureDetail: json['ID_FEATUREDETAIL']?.toString() ?? '',
      nama: json['NAME'] ?? '',
      seq: json['SEQ'] is int
          ? json['SEQ']
          : int.tryParse(json['SEQ']?.toString() ?? '') ?? 0,
      isRequired: json['IS_REQUIRED'] is int
          ? json['IS_REQUIRED']
          : int.tryParse(json['IS_REQUIRED']?.toString() ?? '') ?? 0,
      isActive: json['IS_ACTIVE'] is int
          ? json['IS_ACTIVE']
          : int.tryParse(json['IS_ACTIVE']?.toString() ?? '') ?? 0,
      keterangan: json['KETERANGAN'],
      icon: json['ICON'],
      type: json['TYPE'],
      isChecked: json['isChecked'] == true || json['isChecked'] == 1,
    );
  }

  /// ✅ Parsing dari database (tanpa isChecked)
  factory FeatureSubDetail.fromMap(Map<String, dynamic> map) {
    return FeatureSubDetail(
      id: map['id']?.toString() ?? '',
      idFeatureDetail: map['idFeatureDetail']?.toString() ?? '',
      nama: map['nama'] ?? '',
      seq: map['seq'] is int
          ? map['seq']
          : int.tryParse(map['seq'].toString()) ?? 0,
      isRequired: map['isRequired'] is int
          ? map['isRequired']
          : int.tryParse(map['isRequired'].toString()) ?? 0,
      isActive: map['isActive'] is int
          ? map['isActive']
          : int.tryParse(map['isActive'].toString()) ?? 0,
      keterangan: map['keterangan'],
      icon: map['icon'],
      type: map['type'],
      isChecked: false, // default saat ambil dari DB
    );
  }

  /// ✅ Untuk insert ke SQLite (tanpa isChecked)
  Map<String, dynamic> toMap() => {
        'id': id,
        'idFeatureDetail': idFeatureDetail,
        'nama': nama,
        'seq': seq,
        'isRequired': isRequired,
        'isActive': isActive,
        'keterangan': keterangan,
        'icon': icon,
        'type': type,
      };

  /// ✅ Untuk simpan ke checklist_progress (jsonEncode)
  Map<String, dynamic> toJson() => {
        'id': id,
        'idFeatureDetail': idFeatureDetail,
        'nama': nama,
        'seq': seq,
        'isRequired': isRequired,
        'isActive': isActive,
        'keterangan': keterangan,
        'icon': icon,
        'type': type,
        'isChecked': isChecked,
      };
}
