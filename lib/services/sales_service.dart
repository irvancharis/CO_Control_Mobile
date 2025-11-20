import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sales_model.dart';
// import '../config/server.dart'; // Hapus ini karena sudah pakai api_config
import '../utils/api_config.dart';

class SalesService {
  Future<List<Sales>> fetchSales() async {
    // --- PERBAIKAN: Panggil fungsi getUrl ---
    final String fullUrl = ApiConfig.getUrl('/DATASALES');
    print("GET Sales: $fullUrl"); // Debugging

    final url = Uri.parse(fullUrl);
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Sales.fromJson(e)).toList();
    } else {
      print("❌ Gagal mengambil data sales: ${res.statusCode}");
      throw Exception('Gagal mengambil data sales');
    }
  }
}
