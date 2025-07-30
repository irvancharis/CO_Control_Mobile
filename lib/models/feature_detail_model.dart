class FeatureDetail {
  String nama;
  String icon;
  List<SubDetail> subDetails;

  FeatureDetail(
      {required this.nama, required this.icon, required this.subDetails});

  // Supaya bisa cloning checklist (reset)
  FeatureDetail copy() => FeatureDetail(
        nama: this.nama,
        icon: this.icon,
        subDetails: this.subDetails.map((sd) => sd.copy()).toList(),
      );
}

class SubDetail {
  String nama;
  bool isChecked;

  SubDetail({required this.nama, required this.isChecked});

  SubDetail copy() => SubDetail(nama: this.nama, isChecked: this.isChecked);
}
