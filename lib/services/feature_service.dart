import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/feature_model.dart';
import '../config/server.dart';

class FeatureService {
  Future<List<FeatureItem>> fetchFeatures() async {
    final url = Uri.parse('${ServerConfig.baseUrl}/FEATURE');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.map((item) => FeatureItem.fromJson(item)).toList();
    } else {
      throw Exception('Gagal memuat fitur: ${response.statusCode}');
    }
  }
}
