import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/feature_detail_model.dart';
// import '../config/server.dart'; // Hapus ini karena sudah pakai api_config
import '../utils/api_config.dart';

class SubmitService {
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
    try {
      // Siapkan payload JSON
      final data = {
        'id_visit': idVisit,
        'tanggal': tanggal.toIso8601String(),
        'id_spv': idSpv,
        'id_pelanggan': idPelanggan,
        'latitude': latitude,
        'longitude': longitude,
        'mulai': mulai.toIso8601String(),
        'selesai': selesai.toIso8601String(),
        'catatan': catatan,
        'id_feature': idFeature,
        'id_sales': idSales,
        'nocall': nocall,
        'details': details.map((detail) {
          return {
            'id_feature_detail': detail.id,
            'nama_detail': detail.nama,
            'sub_details': detail.subDetails.map((sub) {
              return {
                'id_feature_sub_detail': sub.id,
                'nama_sub': sub.nama,
                'is_checked': sub.isChecked,
              };
            }).toList(),
          };
        }).toList(),
      };

      // --- PERBAIKAN UTAMA DI SINI ---
      final String fullUrl = ApiConfig.getUrl('/SUBMIT_VISIT');
      print('[SUBMIT] Sending to: $fullUrl'); // Debugging URL

      // Kirim ke server
      final response = await http.post(
        Uri.parse(fullUrl), // Gunakan URL hasil generate
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      print('DEBUG SUBMIT PAYLOAD');
      // print(jsonEncode(data)); // Boleh di-comment kalau log terlalu panjang

      print('[SUBMIT VISIT] Status: ${response.statusCode}');
      print('[SUBMIT VISIT] Body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['success'] == true;
      } else {
        return false;
      }
    } catch (e) {
      print('[SUBMIT VISIT] Error: $e');
      return false;
    }
  }
}
