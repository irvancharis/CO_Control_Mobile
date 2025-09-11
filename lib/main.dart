import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/pelanggan_list_screen.dart';
import 'providers/sales_provider.dart';

/// =======================
/// Database Helper untuk Visit
/// =======================
class VisitDatabaseHelper {
  static final VisitDatabaseHelper _instance = VisitDatabaseHelper._internal();
  factory VisitDatabaseHelper() => _instance;
  VisitDatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'visits.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE visit(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            pelangganId TEXT,
            latitude TEXT,
            longitude TEXT
          )
        ''');
      },
    );
  }

  /// Hapus visit dengan pelangganId duplikat yang punya lat/long kosong
  Future<void> cleanDuplicateVisits() async {
    final db = await database;

    // Cari pelanggan yang punya lebih dari 1 record
    final duplicates = await db.rawQuery('''
      SELECT pelangganId 
      FROM visit
      GROUP BY pelangganId
      HAVING COUNT(*) > 1
    ''');

    for (var row in duplicates) {
      final pelangganId = row['pelangganId'];

      // Cari data kosong lat/long
      final emptyVisits = await db.query(
        'visit',
        where:
            'pelangganId = ? AND (latitude IS NULL OR latitude = "" OR longitude IS NULL OR longitude = "")',
        whereArgs: [pelangganId],
      );

      for (var visit in emptyVisits) {
        await db.delete(
          'visit',
          where: 'id = ?',
          whereArgs: [visit['id']],
        );
      }
    }
  }
}

/// =======================
/// Main App
/// =======================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  await initializeDateFormatting('id_ID', null);

  // 🔑 Bersihkan data duplikat visit sebelum app jalan
  final dbHelper = VisitDatabaseHelper();
  await dbHelper.cleanDuplicateVisits();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SalesProvider()),
      ],
      child: ControlSalesApp(isLoggedIn: isLoggedIn),
    ),
  );
}

class ControlSalesApp extends StatelessWidget {
  final bool isLoggedIn;
  const ControlSalesApp({Key? key, required this.isLoggedIn}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control Sales App',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: isLoggedIn ? '/dashboard' : '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/pelanggan-list': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map?;
          return PelangganListScreen(
            featureId: args?['featureId'] ?? '',
            title: args?['title'] ?? '',
            featureType: args?['featureType'] ?? '',
          );
        },
        // Untuk checklist screen, sebaiknya pakai push biasa (MaterialPageRoute) dari PelangganListScreen,
        // karena butuh passing object pelanggan, bukan sekedar string id.
      },
    );
  }
}
