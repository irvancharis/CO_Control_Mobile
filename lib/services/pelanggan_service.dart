import '../models/pelanggan_model.dart';

class PelangganService {
  Future<List<Pelanggan>> fetchPelanggan() async {
    // Simulasi API, ganti dengan fetch API asli jika tersedia
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      Pelanggan(id: 'CUST001', nama: 'Toko A'),
      Pelanggan(id: 'CUST002', nama: 'Toko B'),
      Pelanggan(id: 'CUST003', nama: 'Toko C'),
    ];
  }
}
