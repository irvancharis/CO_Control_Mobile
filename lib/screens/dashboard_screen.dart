import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
    _futureFeatures = _loadFeaturesFiltered();
  }

  // =========================
  // FILTER FITUR DARI DATABASE
  // =========================
  Future<List<Feature>> _loadFeaturesFiltered() async {
    try {
      final all = await FeatureService().fetchFeatures();
      final activeFeatureIds = await _getActiveFeatureIdsFromDb();

      if (activeFeatureIds.isEmpty) {
        // Tidak ada transaksi → tampilkan semua fitur
        return all;
      }

      // Ada transaksi → filter hanya id yang muncul di visit_checklist
      final filtered =
          all.where((f) => activeFeatureIds.contains(f.id)).toList();
      // Safety fallback
      return filtered.isEmpty ? all : filtered;
    } catch (e) {
      debugPrint('Gagal memfilter fitur: $e');
      // Fallback ke semua fitur jika error
      return FeatureService().fetchFeatures();
    }
  }

  /// Ambil DISTINCT id_feature dari table visit_checklist.
  /// Aman untuk kasus: table belum ada / sedang diubah saat sync.
  Future<Set<String>> _getActiveFeatureIdsFromDb() async {
    final dbPath = join(await getDatabasesPath(), 'appdb.db');
    Database? db;
    try {
      db = await openDatabase(dbPath);
      final existRows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        ['pelanggan'],
      );
      if (existRows.isEmpty) {
        // Tabel belum dibuat → anggap belum ada transaksi
        return <String>{};
      }

      final rows = await db.rawQuery('''
        SELECT DISTINCT fitur AS feature_id
        FROM pelanggan        
      ''');

      return rows
          .map((r) => (r['feature_id'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toSet();
    } catch (e) {
      debugPrint('getActiveFeatureIds error: $e');
      // Jangan jatuhkan UI, fallback kosong
      return <String>{};
    } finally {
      await db?.close();
    }
  }

  // =========================
  // SYNC LOGIC
  // =========================
  Future<void> doSync(BuildContext context) async {
    setState(() => isSyncing = true);
    try {
      await SyncService.syncAll();
      if (!mounted) return;
      setState(() {
        _futureFeatures = _loadFeaturesFiltered();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync selesai!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync gagal: $e')),
      );
    } finally {
      if (mounted) setState(() => isSyncing = false);
    }
  }

  // =========================
  // EXPORT LOGIC
  // =========================
  Future<void> exportDatabase(BuildContext context) async {
    setState(() => isExporting = true);

    try {
      final dbPath = join(await getDatabasesPath(), 'appdb.db');
      final dbFile = File(dbPath);

      if (!(await dbFile.exists())) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database tidak ditemukan')),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final kodeUser = prefs.getString('kodeUser') ?? '';
      final tanggalStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = '${kodeUser}_$tanggalStr.db';

      final fileBytes = await dbFile.readAsBytes();

      final url = Uri.parse('${ServerConfig.baseUrl}/upload-db');
      var request = http.MultipartRequest('POST', url)
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: fileName,
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
    } finally {
      if (mounted) setState(() => isExporting = false);
    }
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
      // Biarkan sistem pop kalau masih ada page sebelumnya.
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return; // sudah dipop (mis. kembali ke pelanggan)

        // Kalau sudah root (tidak bisa pop), baru tampilkan dialog keluar.
        final canPop = Navigator.of(context).canPop();

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
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
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
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
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
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
