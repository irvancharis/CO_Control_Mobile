class Pelanggan {
  final String id;
  final String nama;
  final String nocall;
  final String alamat;
  final String kecamatan;
  final String kotakabupaten;
  final String latitude;
  final String longitude;
  final String tipePelanggan;
  final String tipePembayaran;
  final String fitur;

  Pelanggan({
    required this.id,
    required this.nama,
    required this.nocall,
    required this.alamat,
    required this.kecamatan,
    required this.kotakabupaten,
    required this.latitude,
    required this.longitude,
    required this.tipePelanggan,
    required this.tipePembayaran,
    required this.fitur,
  });

  factory Pelanggan.fromJson(Map<String, dynamic> json) => Pelanggan(
        id: json['IDPELANGGAN'].toString(),
        nama: json['NAMAPELANGGAN'] ?? '',
        nocall: json['NOCALL'] ?? '',
        alamat: json['ALAMAT'] ?? '',
        kecamatan: json['KECAMATAN'] ?? '',
        kotakabupaten: json['KOTAKABUPATEN'] ?? '',
        latitude: json['LATITUDE'] ?? '',
        longitude: json['LONGITUDE'] ?? '',
        tipePelanggan: json['TIPEPELANGGAN'] ?? '',
        tipePembayaran: json['TIPEPEMBAYARAN'] ?? '',
        fitur: json['FITUR'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'nama': nama,
        'nocall': nocall,
        'alamat': alamat,
        'kecamatan': kecamatan,
        'kotakabupaten': kotakabupaten,
        'latitude': latitude,
        'longitude': longitude,
        'tipePelanggan': tipePelanggan,
        'tipePembayaran': tipePembayaran,
        'fitur': fitur,
      };

  factory Pelanggan.fromMap(Map<String, dynamic> map) => Pelanggan(
        id: map['id'],
        nama: map['nama'],
        nocall: map['nocall'],
        alamat: map['alamat'],
        kecamatan: map['kecamatan'],
        kotakabupaten: map['kotakabupaten'],
        latitude: map['latitude'],
        longitude: map['longitude'],
        tipePelanggan: map['tipePelanggan'],
        tipePembayaran: map['tipePembayaran'],
        fitur: map['fitur'],
      );
}
