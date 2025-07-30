import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/pelanggan_model.dart';
import 'database_helper.dart';
import '../config/server.dart';

class PelangganService {
  final String baseUrl = ServerConfig.baseUrl;

  Future<void> downloadAndSavePelanggan(String nocall) async {
    final url = Uri.parse('$baseUrl/JOINT_CALL_DETAIL/$nocall');
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      if (data.isNotEmpty) {
        for (final pelJson in data) {
          final pelanggan = Pelanggan.fromJson(pelJson);
          await DatabaseHelper.instance.insertOrReplacePelanggan(pelanggan);
        }
      }
    } else {
      throw Exception('Gagal download pelanggan');
    }
  }

  Future<void> clearLocalPelanggan() async {
    await DatabaseHelper.instance.clearPelanggan();
  }

  Future<List<Pelanggan>> fetchAllPelangganLocal() async {
    return await DatabaseHelper.instance.getAllPelanggan();
  }
}
