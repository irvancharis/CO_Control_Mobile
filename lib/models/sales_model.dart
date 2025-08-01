class Sales {
  final String id;
  final String idCabang;
  final String nama;
  final String kodeSales;

  Sales({
    required this.id,
    required this.idCabang,
    required this.nama,
    required this.kodeSales,
  });

  // FROM API JSON
  factory Sales.fromJson(Map<String, dynamic> json) => Sales(
        id: json['IDSALES']?.toString() ?? '',
        idCabang: json['IDCABANG']?.toString() ?? '',
        nama: json['NAMASALES'] ?? '',
        kodeSales: json['KODESALES'] ?? '',
      );

  // FROM DB MAP
  factory Sales.fromMap(Map<String, dynamic> map) => Sales(
        id: map['id']?.toString() ?? '',
        idCabang: map['idCabang']?.toString() ?? '',
        nama: map['nama'] ?? '',
        kodeSales: map['kodeSales'] ?? '',
      );

  // TO DB MAP
  Map<String, dynamic> toMap() => {
        'id': id,
        'idCabang': idCabang,
        'nama': nama,
        'kodeSales': kodeSales,
      };
}
