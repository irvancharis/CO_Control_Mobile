import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sales_model.dart';
import '../config/server.dart';

class SalesService {
  final String baseUrl = ServerConfig.baseUrl;

  Future<List<Sales>> fetchSales() async {
    final url = Uri.parse('$baseUrl/DATASALES');
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Sales.fromJson(e)).toList();
    } else {
      throw Exception('Gagal mengambil data sales');
    }
  }
}
