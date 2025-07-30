import '../models/feature_detail_model.dart';

class SubmitService {
  // Kembalikan Future<bool> (success/failed)
  static Future<bool> submitVisit({
    required String idVisit,
    required DateTime tanggal,
    required String idSpv,
    required String idPelanggan,
    required String latitude,
    required String longitude,
    required DateTime mulai,
    required DateTime selesai,
    required String catatan,
    required String idFeature,
    required List<FeatureDetail> details,
    String? idSales,
    String? nocall,
  }) async {
    // Simulasi submit ke API/database
    await Future.delayed(const Duration(seconds: 1));
    // TODO: Ganti dengan post ke API/server atau simpan ke lokal

    // Contoh: tampilkan ke console
    print('Submit Visit');
    print('idVisit: $idVisit');
    print('tanggal: $tanggal');
    print('idSpv: $idSpv');
    print('idPelanggan: $idPelanggan');
    print('latitude: $latitude');
    print('longitude: $longitude');
    print('mulai: $mulai');
    print('selesai: $selesai');
    print('catatan: $catatan');
    print('idFeature: $idFeature');
    print('details: $details');
    print('idSales: $idSales');
    print('nocall: $nocall');

    // Anggap success
    return true;
  }
}
