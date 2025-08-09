import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;

import '../models/feature_model.dart';
import '../services/feature_service.dart';
import '../services/sync_service.dart';
import 'pelanggan_list_screen.dart';
import 'pelanggan_list_custom_screen.dart';
import '../config/server.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Feature>> _futureFeatures;
  bool isSyncing = false;
  bool isExporting = false;

  @override
  void initState() {
    super.initState();
    _futureFeatures = FeatureService().fetchFeatures();
  }

  // SYNC LOGIC
  Future<void> doSync(BuildContext context) async {
    setState(() => isSyncing = true);
    try {
      await SyncService.syncAll();
      if (!mounted) return;
      setState(() {
        _futureFeatures = FeatureService().fetchFeatures();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync selesai!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync gagal: $e')),
      );
    }
    if (!mounted) return;
    setState(() => isSyncing = false);
  }

  // EXPORT LOGIC
  Future<void> exportDatabase(BuildContext context) async {
    setState(() => isExporting = true);

    try {
      // Ambil path database
      final dbPath = join(await getDatabasesPath(), 'appdb.db');
      final dbFile = File(dbPath);

      if (!(await dbFile.exists())) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database tidak ditemukan')),
        );
        setState(() => isExporting = false);
        return;
      }

      // 🔧 Buat nama file dengan format KODEUSER_TANGGAL.db
      final kodeUser = 'DIDIK'; // Ganti sesuai user aktif
      final tanggalStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = '${kodeUser}_$tanggalStr.db';

      // 🔄 Baca isi file sebagai bytes
      final fileBytes = await dbFile.readAsBytes();

      // 🔼 Kirim ke server
      final url = Uri.parse('${ServerConfig.baseUrl}/upload-db');
      var request = http.MultipartRequest('POST', url)
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: fileName, // <-- di sini kita override nama file
          ),
        );

      final response = await request.send();

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Database berhasil di-upload ke server!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload gagal: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export gagal: $e')),
      );
    }

    if (!mounted) return;
    setState(() => isExporting = false);
  }

  IconData getIconData(String iconName) {
    switch (iconName) {
      case 'dashboard':
        return Icons.dashboard;
      case 'visit':
        return Icons.location_on;
      case 'call':
        return Icons.call;
      case 'report':
        return Icons.insert_chart;
      default:
        return Icons.extension;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Keluar Aplikasi'),
            content: const Text('Yakin ingin keluar dari aplikasi?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Tidak'),
              ),
              TextButton(
                onPressed: () => exit(0),
                child: const Text('Ya'),
              ),
            ],
          ),
        );

        if (shouldExit == true) {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Dashboard"),
          actions: [
            // EXPORT DB BUTTON
            IconButton(
              icon: isExporting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.file_upload),
              tooltip: 'Export Database (Download)',
              onPressed: isExporting ? null : () => exportDatabase(context),
            ),
            // SYNC BUTTON
            IconButton(
              icon: isSyncing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync),
              tooltip: 'Sync Data Master (Server → Lokal)',
              onPressed: isSyncing ? null : () => doSync(context),
            ),
          ],
        ),
        body: FutureBuilder<List<Feature>>(
          future: _futureFeatures,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting ||
                isSyncing) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("Tidak ada menu fitur"));
            }

            final features = snapshot.data!;
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: features.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 3 / 2,
              ),
              itemBuilder: (context, index) {
                final feature = features[index];
                return GestureDetector(
                  onTap: () {
                    final action = feature.type?.toLowerCase();
                    final screen = action == 'custom'
                        ? PelangganListCustomScreen(
                            featureId: feature.id,
                            title: feature.nama,
                            featureType: feature.type,
                          )
                        : PelangganListScreen(
                            featureId: feature.id,
                            title: feature.nama,
                            featureType: feature.type,
                          );

                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => screen),
                    );
                  },
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(getIconData(feature.icon), size: 40),
                          const SizedBox(height: 10),
                          Text(
                            feature.nama,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
