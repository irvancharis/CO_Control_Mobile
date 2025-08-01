import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/feature_detail_model.dart'; // path model detail saja
import '../services/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class FeatureDetailService {
  final String baseUrl;
  final DatabaseHelper db;

  FeatureDetailService({required this.baseUrl, required this.db});

  // Fetch all details from API
  Future<List<FeatureDetail>> fetchFeatureDetailsFromApi() async {
    final response = await http.get(Uri.parse('$baseUrl/DETAIL_FEATURE'));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      // PENTING: mapping tanpa subdetails, dari model detail saja
      return data.map((e) => FeatureDetail.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load feature details');
    }
  }

  // Get all details from DB
  Future<List<FeatureDetail>> getAllFromDb() async {
    final dbClient = await db.database;
    final List<Map<String, dynamic>> maps =
        await dbClient.query('feature_detail');
    return maps.map((e) => FeatureDetail.fromMap(e)).toList();
  }

  // Insert single detail to DB
  Future<void> insertToDb(FeatureDetail detail) async {
    final dbClient = await db.database;
    await dbClient.insert(
      'feature_detail',
      detail.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Delete all details
  Future<void> clearTable() async {
    final dbClient = await db.database;
    await dbClient.delete('feature_detail');
  }

  // Get detail by ID (tanpa subdetail)
  Future<FeatureDetail?> getDetailById(int id) async {
    final dbClient = await db.database;
    final maps = await dbClient
        .query('feature_detail', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return FeatureDetail.fromMap(maps.first);
  }
}
