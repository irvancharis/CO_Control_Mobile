import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/pelanggan_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  factory DatabaseHelper() => instance;
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'appdb.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pelanggan(
            id TEXT PRIMARY KEY,
            nama TEXT,
            nocall TEXT,
            alamat TEXT,
            kecamatan TEXT,
            kotakabupaten TEXT,
            latitude TEXT,
            longitude TEXT,
            tipePelanggan TEXT,
            tipePembayaran TEXT
          )
        ''');
      },
    );
  }

  Future<void> insertOrReplacePelanggan(Pelanggan pelanggan) async {
    final db = await database;
    await db.insert(
      'pelanggan',
      pelanggan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Pelanggan>> getAllPelanggan() async {
    final db = await database;
    final maps = await db.query('pelanggan');
    return maps.map((e) => Pelanggan.fromMap(e)).toList();
  }

  Future<void> clearPelanggan() async {
    final db = await database;
    await db.delete('pelanggan');
  }
}
