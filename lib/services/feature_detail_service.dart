import '../models/feature_detail_model.dart';

class FeatureDetailService {
  // Ambil data checklist dari database/server (ganti sesuai kebutuhan)
  Future<List<FeatureDetail>> fetchDetails(String featureId) async {
    // Simulasi fetch ke API/database:
    await Future.delayed(const Duration(milliseconds: 500));
    // TODO: Ganti dengan logic database sesungguhnya!
    return [
      FeatureDetail(
        nama: 'Cek Modem',
        icon: 'dashboard',
        subDetails: [
          SubDetail(nama: 'Lampu ON', isChecked: false),
          SubDetail(nama: 'Kabel terpasang', isChecked: false),
        ],
      ),
      FeatureDetail(
        nama: 'Cek Koneksi',
        icon: 'call',
        subDetails: [
          SubDetail(nama: 'Koneksi OK', isChecked: false),
          SubDetail(nama: 'Tidak ada masalah', isChecked: false),
        ],
      ),
    ];
  }
}
