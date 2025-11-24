import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../models/feature_model.dart';
import '../services/feature_service.dart';
import '../services/sync_service.dart';
import '../config/server.dart';
import 'pelanggan_list_screen.dart';
import 'pelanggan_list_custom_screen.dart';
import '../utils/api_config.dart';

// ===================== Tokens (selaras layar lain) =====================
class _UX {
  static const primary = Color(0xFF8E7CC3);
  static const primaryDark = Color(0xFF6F5AA8);
  static const primarySurface = Color(0xFFF0ECFA);
  static const success = Color(0xFF2EAD54);
  static const bg = Color(0xFFF7F1FF);
  static const surface = Colors.white;
  static const cardBorder = Color(0xFFE6E2F2);
  static const textMuted = Color(0xFF7A7A7A);
  static const r12 = 12.0;
  static const r16 = 16.0;
  static const r999 = 999.0;

  static InputBorder roundedBorder() => OutlineInputBorder(
        borderRadius: BorderRadius.circular(r12),
        borderSide: const BorderSide(color: Color(0xFFE1E1E8)),
      );
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Feature>> _futureFeatures;
  bool _syncing = false;
  bool _exporting = false;
  String? username;

  @override
  void initState() {
    super.initState();
    _futureFeatures = _loadFeaturesFiltered();
    _loadUsername();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        _doSync();
      }
    });
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final storedName =
        prefs.getString('user_id') ?? 'Pengguna'; // default jika null
    setState(() {
      username = storedName;
    });
  }

  // ========================= FILTER FITUR =========================
  Future<List<Feature>> _loadFeaturesFiltered() async {
    try {
      final all = await FeatureService().fetchFeatures();
      final activeFeatureIds = await _getActiveFeatureIdsFromDb();

      if (activeFeatureIds.isEmpty) {
        // Tidak ada transaksi → tampilkan semua fitur
        return all;
      }

      final filtered =
          all.where((f) => activeFeatureIds.contains(f.id)).toList();
      return filtered.isEmpty ? all : filtered; // safety fallback
    } catch (e) {
      debugPrint('Gagal memfilter fitur: $e');
      // Fallback ke semua fitur jika error
      return FeatureService().fetchFeatures();
    }
  }

  /// Ambil DISTINCT fitur aktif dari tabel pelanggan (kolom `fitur`)
  Future<Set<String>> _getActiveFeatureIdsFromDb() async {
    final dbPath = p.join(await getDatabasesPath(), 'appdb.db');
    Database? db;
    try {
      db = await openDatabase(dbPath);
      // pastikan tabel ada
      final existRows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        ['pelanggan'],
      );
      if (existRows.isEmpty) return <String>{};

      final rows = await db
          .rawQuery('SELECT DISTINCT fitur AS feature_id FROM pelanggan');
      return rows
          .map((r) => (r['feature_id'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toSet();
    } catch (e) {
      debugPrint('getActiveFeatureIds error: $e');
      return <String>{};
    } finally {
      await db?.close();
    }
  }

  // ========================= SYNC =========================
  Future<void> _doSync() async {
    // JANGAN set _syncing = true di sini agar UI tidak loading full screen
    // setState(() => _syncing = true); <--- HAPUS ATAU KOMENTAR INI

    try {
      // Tampilkan indikator loading kecil di bawah/snack bar saja jika perlu
      await SyncService.syncAll();

      if (!mounted) return;
      // Refresh data setelah sync selesai
      setState(() {
        _futureFeatures = _loadFeaturesFiltered();
      });
    } catch (e) {
      // Error handling silent atau snackbar
      debugPrint('Auto sync error: $e');
    }
    // finally block juga bisa dihapus
  }

  // ========================= EXPORT DB =========================
  Future<void> _exportDatabase() async {
    setState(() => _exporting = true);
    try {
      final dbPath = p.join(await getDatabasesPath(), 'appdb.db');
      final dbFile = File(dbPath);

      if (!(await dbFile.exists())) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database tidak ditemukan')),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final kodeUser = prefs.getString('user_id') ?? '';
      final tanggalStr =
          DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
      final fileName = '${kodeUser}_$tanggalStr.db';

      final fileBytes = await dbFile.readAsBytes();

      final url = Uri.parse(ApiConfig.getUrl('/upload-db'));
      final request = http.MultipartRequest('POST', url)
        ..files.add(http.MultipartFile.fromBytes('file', fileBytes,
            filename: fileName));

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
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ========================= UTIL =========================
  IconData _iconFromName(String? iconName) {
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

  Future<void> _refresh() async {
    setState(() => _futureFeatures = _loadFeaturesFiltered());
    await _futureFeatures;
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('EEEE, d MMM yyyy', 'id_ID').format(DateTime.now());

    return WillPopScope(
      onWillPop: () async {
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
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Ya'),
              ),
            ],
          ),
        );
        if (shouldExit == true) {
          // keluar app
          exit(0);
        }
        return false;
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize:
              const Size.fromHeight(70), // tinggi AppBar (default 56)
          child: Padding(
            padding: const EdgeInsets.only(top: 30), // jarak dari atas
            child: AppBar(
              automaticallyImplyLeading: false,
              elevation: 0,
              foregroundColor: Colors.black87,
              title: const Text(
                'Dashboard',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              actions: [
                IconButton(
                  tooltip: 'Export Database (Upload ke server)',
                  onPressed: _exporting ? null : _exportDatabase,
                  icon: _exporting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.file_upload),
                ),
                IconButton(
                  tooltip: 'Sync Data Master (Server → Lokal)',
                  onPressed: _syncing ? null : _doSync,
                  icon: _syncing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync),
                ),
              ],
            ),
          ),
        ),
        body: FutureBuilder<List<Feature>>(
          future: _futureFeatures,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final features = snapshot.data ?? const <Feature>[];
            if (features.isEmpty) {
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 160),
                    Center(
                        child: Text('Tidak ada menu fitur',
                            style: TextStyle(color: _UX.textMuted))),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Header salam + tanggal
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: Material(
                        color: _UX.surface,
                        elevation: 1,
                        borderRadius: BorderRadius.circular(_UX.r16),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: _UX.primarySurface,
                                child: const Icon(Icons.calendar_today,
                                    color: _UX.primaryDark),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Halo, ${username ?? ''} 👋',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16)),
                                    const SizedBox(height: 2),
                                    Text(dateStr,
                                        style: const TextStyle(
                                            color: _UX.textMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Judul section
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
                      child: _SectionTitle(
                          title: 'Fitur Tersedia', icon: Icons.apps),
                    ),
                  ),

                  // Grid fitur
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final f = features[index];
                          return _FeatureCard(
                            title: f.nama,
                            icon: _iconFromName(f.icon),
                            onTap: () {
                              final type = (f.type ?? '').toLowerCase();
                              final screen = type == 'custom'
                                  ? PelangganListCustomScreen(
                                      featureId: f.id,
                                      title: f.nama,
                                      featureType: f.type ?? 'custom',
                                    )
                                  : PelangganListScreen(
                                      featureId: f.id,
                                      title: f.nama,
                                      featureType: f.type ?? 'standard',
                                    );
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => screen));
                            },
                          );
                        },
                        childCount: features.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 3 / 2,
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 90)),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 4),
          child: Column(
            mainAxisSize: MainAxisSize
                .min, // penting agar tidak mengambil seluruh tinggi layar
            children: const [
              Divider(thickness: 0.4, color: Color(0xFFE1E1E8)),
              SizedBox(height: 6),
              Text(
                'Versi 1.0.0',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _UX.textMuted,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Reusable UI =====================
class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _UX.primaryDark, size: 18),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const Expanded(child: Divider(indent: 10, thickness: .6)),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _UX.surface,
      elevation: 1.5,
      borderRadius: BorderRadius.circular(_UX.r16),
      child: InkWell(
        borderRadius: BorderRadius.circular(_UX.r16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: _UX.primarySurface,
                child: Icon(icon, color: _UX.primaryDark, size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
