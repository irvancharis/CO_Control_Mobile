import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/server.dart';

class AuthService {
  final String _baseUrl = ServerConfig.baseUrl;

  Future<bool> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Ambil token & user ID dari response
      final token = data['token'];
      final user = data['user']; // pastikan backend mengirim objek 'user'
      final userId = user['id']; // misalnya: 'SPV001'

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('authToken', token);
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('user_id', userId); // ID SPV disimpan di sini

      print('✅ Login sukses. Token dan ID SPV tersimpan.');
      return true;
    }

    print('❌ Login gagal. Status: ${response.statusCode}');
    print('Body: ${response.body}');
    return false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');
    await prefs.remove('user_id');
    await prefs.setBool('isLoggedIn', false);
  }
}
