import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/server.dart';
import '../utils/api_config.dart';

class AuthService {
  Future<bool> login(String username, String password) async {
    // --- PERBAIKAN DI SINI ---
    // Panggil fungsi getUrl dengan parameter endpoint '/login'
    final String fullUrl = ApiConfig.getUrl('/login');

    print("Mencoba login ke: $fullUrl"); // Debugging untuk memastikan URL benar

    try {
      final response = await http.post(
        Uri.parse(fullUrl), // Gunakan hasil string URL yang sudah jadi
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final token = data['token'];
        final userId = username;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('authToken', token);
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('user_id', userId);

        print('✅ Login sukses. Token dan ID SPV tersimpan.');
        return true;
      }

      print('❌ Login gagal. Status: ${response.statusCode}');
      print('Body: ${response.body}');
      return false;
    } catch (e) {
      print("❌ Error Koneksi: $e");
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');
    await prefs.remove('user_id');
    await prefs.setBool('isLoggedIn', false);
  }
}
