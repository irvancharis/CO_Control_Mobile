import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/feature_detail_model.dart';
import '../config/server.dart';

class FeatureDetailService {
  Future<List<FeatureDetail>> fetchDetails(String featureId) async {
    final url = Uri.parse('${ServerConfig.baseUrl}/DETAIL_WITH_SUB/$featureId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.map((item) => FeatureDetail.fromJson(item)).toList();
    } else {
      throw Exception('Gagal memuat detail fitur');
    }
  }
}
