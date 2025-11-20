import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_config.dart'; // Import config yang dibuat di langkah 1

class IpSetupScreen extends StatefulWidget {
  const IpSetupScreen({Key? key}) : super(key: key);

  @override
  State<IpSetupScreen> createState() => _IpSetupScreenState();
}

class _IpSetupScreenState extends State<IpSetupScreen> {
  final _ipController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _saveIp() async {
    if (_formKey.currentState!.validate()) {
      final ip = _ipController.text.trim();
      // Validasi sederhana untuk memastikan format URL (tambahkan http jika belum ada)
      String formattedUrl = ip;
      if (!ip.startsWith('http')) {
        formattedUrl = 'http://$ip';
      }

      // Simpan ke SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_ip', formattedUrl);

      // Set ke Config global agar langsung bisa dipakai
      ApiConfig.baseUrl = formattedUrl;

      // Pindah ke halaman Login (karena ini setup awal, pasti belum login)
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Setup Server")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Masukkan Alamat IP Server",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: "IP Address / Domain",
                  hintText: "Contoh: 192.168.1.10 atau my-api.com",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.dns),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'IP Server tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveIp,
                  child: const Text("Simpan & Lanjutkan"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
