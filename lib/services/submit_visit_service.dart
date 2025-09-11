import 'database_helper.dart';

class SubmitVisitLocalService {
  static Future<void> saveChecklistToLocal({
    required String idVisit,
    required String idSpv,
    required String idPelanggan,
    required DateTime tanggal,
    required DateTime mulai,
    required DateTime selesai,
    required String? catatan,
    required String idFeature,
    required String? latitude,
    required String? longitude,
    required int idSales,
    required String nocall,
  }) async {
    // Cek apakah visit dengan idVisit sudah ada
    final exists = await DatabaseHelper.instance.visitExists(idPelanggan);

    if (!exists) {
      // Insert hanya jika belum ada
      await DatabaseHelper.instance.insertVisitIfNotExists(
        idVisit: idVisit,
        idPelanggan: idPelanggan,
        idSpv: idSpv,
        idSales: idSales,
        noCall: nocall,
        latitude: latitude,
        longitude: longitude,
      );
    }

    // Update visit jadi completed + simpan catatan
    await DatabaseHelper.instance.markVisitAsCompleted(
      idVisit: idVisit,
      catatan: catatan,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
