class Pelanggan {
  final String id;
  final String nama;

  Pelanggan({required this.id, required this.nama});

  factory Pelanggan.fromJson(Map<String, dynamic> json) {
    return Pelanggan(
      id: json['id'],
      nama: json['nama'],
    );
  }
}
