import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/pelanggan_model.dart';
import 'database_helper.dart';
// import '../config/server.dart'; // Hapus jika tidak dipakai
import '../utils/api_config.dart';

class PelangganService {
  Future<void> downloadAndSavePelanggan(String nocall, String fitur) async {
    // --- PERBAIKAN: Panggil fungsi getUrl ---
    final String fullUrl = ApiConfig.getUrl('/JOINT_CALL_DETAIL/$nocall');
    print("GET Pelanggan: $fullUrl"); // Debugging

    final url = Uri.parse(fullUrl);
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      if (data.isNotEmpty) {
        for (final pelJson in data) {
          final pelangganJson = Map<String, dynamic>.from(pelJson);
          pelangganJson['FITUR'] = fitur; // Inject fitur dinamis
          final pelanggan = Pelanggan.fromJson(pelangganJson);
          await DatabaseHelper.instance.insertOrReplacePelanggan(pelanggan);
        }
        print("✅ Berhasil simpan ${data.length} pelanggan (JOINT)");
      }
    } else {
      print("❌ Gagal download pelanggan: ${res.statusCode}");
      throw Exception('Gagal download pelanggan');
    }
  }

  Future<void> downloadAndSavePelangganCustom(
      String nocall, String fitur) async {
    // --- PERBAIKAN: Panggil fungsi getUrl ---
    final String fullUrl = ApiConfig.getUrl('/CONTROL_CALL_DETAIL/$nocall');
    print("GET Pelanggan Custom: $fullUrl"); // Debugging

    final url = Uri.parse(fullUrl);
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      if (data.isNotEmpty) {
        for (final pelJson in data) {
          final pelangganJson = Map<String, dynamic>.from(pelJson);
          pelangganJson['FITUR'] = fitur; // Inject fitur dinamis
          final pelanggan = Pelanggan.fromJson(pelangganJson);
          await DatabaseHelper.instance.insertOrReplacePelanggan(pelanggan);
        }
        print("✅ Berhasil simpan ${data.length} pelanggan (CONTROL)");
      }
    } else {
      print("❌ Gagal download pelanggan custom: ${res.statusCode}");
      throw Exception('Gagal download pelanggan');
    }
  }

  Future<void> clearLocalPelanggan() async {
    await DatabaseHelper.instance.clearPelanggan();
  }

  Future<List<Pelanggan>> fetchAllPelangganLocal({String? fitur}) async {
    return await DatabaseHelper.instance.getAllPelanggan(fitur: fitur);
  }
}
