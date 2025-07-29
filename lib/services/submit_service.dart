import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/server.dart';
import '../models/feature_detail_model.dart';

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
  }) async {
    final url = Uri.parse('${ServerConfig.baseUrl}/SUBMIT_VISIT');

    final body = {
      'id_visit': idVisit,
      'tanggal': tanggal.toIso8601String(),
      'idspv': idSpv,
      'idpelanggan': idPelanggan,
      'latitude': latitude,
      'longitude': longitude,
      'mulai': mulai.toIso8601String(),
      'selesai': selesai.toIso8601String(),
      'catatan': catatan,
      'id_feature': idFeature,
      'details': details.map((detail) {
        return {
          'id': detail.id,
          'subDetails': detail.subDetails.map((sub) {
            return {
              'id': sub.id,
              'nama': sub.nama,
              'isChecked': sub.isChecked,
            };
          }).toList(),
        };
      }).toList(),
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print("❌ Error: ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ Exception: $e");
      return false;
    }
  }
}
