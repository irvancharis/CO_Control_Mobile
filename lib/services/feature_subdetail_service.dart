import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../models/feature_subdetail_model.dart';
import '../services/database_helper.dart';
import '../utils/api_config.dart';

class FeatureSubDetailService {
  // Hapus final String baseUrl;
  final DatabaseHelper db;

  // Hapus required this.baseUrl dari constructor
  FeatureSubDetailService({required this.db});

  // Fetch all from API
  Future<List<FeatureSubDetail>> fetchFeatureSubDetailsFromApi() async {
    // --- PERBAIKAN: Gunakan getUrl('/ENDPOINT') ---
    final String fullUrl = ApiConfig.getUrl('/SUBDETAIL_FEATURE');
    print("GET SubDetail: $fullUrl"); // Debugging

    final response = await http.get(Uri.parse(fullUrl));

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => FeatureSubDetail.fromJson(e)).toList();
    } else {
      print("❌ Gagal ambil SubDetail: ${response.statusCode}");
      throw Exception('Failed to load feature subdetails');
    }
  }

  // Get all from DB
  Future<List<FeatureSubDetail>> getAllFromDb() async {
    final dbClient = await db.database;
    final List<Map<String, dynamic>> maps =
        await dbClient.query('feature_subdetail', orderBy: 'seq ASC');
    return maps.map((e) => FeatureSubDetail.fromMap(e)).toList();
  }

  // Get by idFeatureDetail
  Future<List<FeatureSubDetail>> getByFeatureDetailId(
      int idFeatureDetail) async {
    final dbClient = await db.database;
    final maps = await dbClient.query(
      'feature_subdetail',
      where: 'idFeatureDetail = ?',
      whereArgs: [idFeatureDetail],
      orderBy: 'seq ASC',
    );
    return maps.map((e) => FeatureSubDetail.fromMap(e)).toList();
  }

  // Insert ke DB
  Future<void> insertToDb(FeatureSubDetail subdetail) async {
    final dbClient = await db.database;
    await dbClient.insert('feature_subdetail', subdetail.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Delete All
  Future<void> clearTable() async {
    final dbClient = await db.database;
    await dbClient.delete('feature_subdetail');
  }
}
