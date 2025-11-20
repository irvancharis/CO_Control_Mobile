import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/feature_model.dart';
// import '../config/server.dart'; // Hapus ini karena sudah pakai api_config
import '../utils/api_config.dart'; // Perbaiki path (tambah .. di depan)

class FeatureService {
  Future<List<Feature>> fetchFeatures() async {
    // LOGIKA SUDAH BENAR
    // Tapi kita pisah variable-nya biar enak buat debugging (print log)
    final String fullUrl = ApiConfig.getUrl('/FEATURE');
    print("GET Features: $fullUrl");

    final url = Uri.parse(fullUrl);
    final response = await http.get(url);

    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.map((item) => Feature.fromJson(item)).toList();
    } else {
      print("❌ Gagal memuat fitur: ${response.statusCode}");
      throw Exception('Gagal memuat fitur: ${response.statusCode}');
    }
  }
}
