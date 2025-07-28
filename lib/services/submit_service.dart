import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/server.dart';
import '../models/feature_detail_model.dart';

class SubmitService {
  static Future<void> submitChecklist(List<FeatureSubDetail> data) async {
    final url = Uri.parse('${ServerConfig.baseUrl}/SUBMIT_CHECKLIST');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'checklist': data.map((e) => e.toJson()).toList()}),
    );

    if (response.statusCode != 200) {
      throw Exception('Gagal submit checklist');
    }
  }
}
