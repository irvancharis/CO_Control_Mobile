class Sales {
  final String id; // IDSALES
  final String idCabang; // IDCABANG (kode cabang)
  final String suspend; // SUSPEND (bisa diubah ke bool jika ingin)
  final String flagKunjungan; // FLAG_KUNJUNGAN
  final String nama; // NAMASALES
  final String kodeSales; // KODESALES
  final String idSpv; // IDSPV

  Sales({
    required this.id,
    required this.idCabang,
    required this.suspend,
    required this.flagKunjungan,
    required this.nama,
    required this.kodeSales,
    required this.idSpv,
  });

  factory Sales.fromJson(Map<String, dynamic> json) => Sales(
        id: json['IDSALES'].toString(),
        idCabang: json['IDCABANG']?.toString() ?? '',
        suspend: json['SUSPEND']?.toString() ?? '',
        flagKunjungan: json['FLAG_KUNJUNGAN']?.toString() ?? '',
        nama: json['NAMASALES'] ?? '',
        kodeSales: json['KODESALES'] ?? '',
        idSpv: json['IDSPV']?.toString() ?? '',
      );
}
