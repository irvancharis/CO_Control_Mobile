import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/pelanggan_model.dart';
import '../models/sales_model.dart';
import '../models/feature_model.dart';
import '../models/feature_detail_model.dart';
import '../models/feature_subdetail_model.dart';

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
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS pelanggan (
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

        await db.execute('''
          CREATE TABLE IF NOT EXISTS sales (
            id TEXT PRIMARY KEY,
            idCabang TEXT,
            nama TEXT,
            kodeSales TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS feature (
            id TEXT PRIMARY KEY,
            nama TEXT,
            icon TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS feature_detail (
            id TEXT PRIMARY KEY,
            idFeature TEXT,
            nama TEXT,
            icon TEXT,
            seq INTEGER,
            isRequired INTEGER,
            isActive INTEGER,
            keterangan TEXT,
            type TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS feature_subdetail (
            id TEXT PRIMARY KEY,
            idFeatureDetail TEXT,
            nama TEXT,
            seq INTEGER,
            isRequired INTEGER,
            isActive INTEGER,
            keterangan TEXT,
            icon TEXT,
            type TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS visit (
            id_visit TEXT PRIMARY KEY,
            tanggal TEXT,
            idspv TEXT,
            idpelanggan TEXT,
            latitude TEXT,
            longitude TEXT,
            mulai TEXT,
            selesai TEXT,
            catatan TEXT,
            idsales INTEGER,
            nocall TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS visit_checklist (
            id_visit TEXT,
            id_feature TEXT,
            id_featuredetail TEXT,
            id_featuresubdetail TEXT,
            checklist INTEGER,
            PRIMARY KEY (id_visit, id_feature, id_featuredetail, id_featuresubdetail)
          )
        ''');
      },
    );
  }

  // ==== PELANGGAN ====
  Future<void> insertOrReplacePelanggan(Pelanggan pelanggan) async {
    final db = await database;
    await db.insert('pelanggan', pelanggan.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
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

  // ==== SALES ====
  Future<void> insertSales(Sales sales) async {
    final db = await database;
    await db.insert('sales', sales.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Sales>> getAllSales() async {
    final db = await database;
    final maps = await db.query('sales');
    return maps.map((e) => Sales.fromMap(e)).toList();
  }

  // ==== FEATURE ====
  Future<void> insertFeature(Feature feature) async {
    final db = await database;
    await db.insert('feature', feature.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Feature>> getAllFeature() async {
    final db = await database;
    final maps = await db.query('feature');
    return maps.map((e) => Feature.fromMap(e)).toList();
  }

  // ==== FEATURE DETAIL ====
  Future<void> insertAllFeatureDetails(List<FeatureDetail> details) async {
    final db = await database;
    final batch = db.batch();
    for (final detail in details) {
      batch.insert('feature_detail', detail.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<FeatureDetail>> getFeatureDetailsByFeatureId(
      String featureId) async {
    final db = await database;
    final maps = await db.query('feature_detail',
        where: 'idFeature = ?', whereArgs: [featureId]);
    return maps.map((e) => FeatureDetail.fromMap(e, [])).toList();
  }

  Future<List<FeatureDetail>> getFeatureDetailsWithSubDetailByFeatureId(
      String featureId) async {
    final db = await database;
    final detailMaps = await db.query('feature_detail',
        where: 'idFeature = ?', whereArgs: [featureId]);

    List<FeatureDetail> result = [];
    for (final d in detailMaps) {
      final subs = await db.query('feature_subdetail',
          where: 'idFeatureDetail = ?', whereArgs: [d['id']]);
      final subList = subs.map((e) => FeatureSubDetail.fromMap(e)).toList();
      result.add(FeatureDetail.fromMap(d, subList));
    }
    return result;
  }

  // ==== SUBDETAIL ====
  Future<void> insertFeatureSubDetail(FeatureSubDetail sub) async {
    final db = await database;
    await db.insert('feature_subdetail', sub.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<FeatureSubDetail>> getAllFeatureSubDetails() async {
    final db = await database;
    final maps = await db.query('feature_subdetail');
    return maps.map((e) => FeatureSubDetail.fromMap(e)).toList();
  }

  // ==== VISIT ====
  Future<void> insertVisitIfNotExists({
    required String idVisit,
    required String idPelanggan,
    required String idSpv,
    required int idSales,
    required String noCall,
    String? latitude,
    String? longitude,
  }) async {
    final db = await database;
    final existing =
        await db.query('visit', where: 'id_visit = ?', whereArgs: [idVisit]);
    if (existing.isEmpty) {
      await db.insert('visit', {
        'id_visit': idVisit,
        'tanggal': DateTime.now().toIso8601String(),
        'idpelanggan': idPelanggan,
        'idspv': idSpv,
        'idsales': idSales,
        'nocall': noCall,
        'latitude': latitude,
        'longitude': longitude,
        'mulai': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> upsertChecklistDetail({
    required String idVisit,
    required String idFeature,
    required String idFeatureDetail,
    required String idFeatureSubDetail,
    required bool isChecked,
  }) async {
    final db = await database;
    await db.insert(
      'visit_checklist',
      {
        'id_visit': idVisit,
        'id_feature': idFeature,
        'id_featuredetail': idFeatureDetail,
        'id_featuresubdetail': idFeatureSubDetail,
        'checklist': isChecked ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getChecklistDetail({
    required String idVisit,
    required String idFeature,
  }) async {
    final db = await database;
    return await db.query(
      'visit_checklist',
      where: 'id_visit = ? AND id_feature = ?',
      whereArgs: [idVisit, idFeature],
    );
  }

  Future<void> markVisitAsCompleted({
    required String idVisit,
    String? catatan,
    String? latitude,
    String? longitude,
  }) async {
    final db = await database;
    await db.update(
      'visit',
      {
        'selesai': DateTime.now().toIso8601String(),
        if (catatan != null) 'catatan': catatan,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
      where: 'id_visit = ?',
      whereArgs: [idVisit],
    );
  }

  Future<Map<String, dynamic>?> getVisitByPelangganAndFeature({
    required String idPelanggan,
    required String idFeature,
  }) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT v.id_visit FROM visit v
      INNER JOIN visit_checklist vc ON vc.id_visit = v.id_visit
      WHERE v.idpelanggan = ? AND vc.id_feature = ?
      LIMIT 1
    ''', [idPelanggan, idFeature]);

    if (result.isNotEmpty) return result.first;
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllVisits() async {
    final db = await database;
    return await db.query('visit');
  }

  Future<List<Map<String, dynamic>>> getAllVisitChecklist() async {
    final db = await database;
    return await db.query('visit_checklist');
  }

  Future<void> clearTable(String table) async {
    final db = await database;
    await db.delete(table);
  }
}
