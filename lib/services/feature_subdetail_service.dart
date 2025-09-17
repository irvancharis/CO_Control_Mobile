import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/feature_subdetail_model.dart'; // sesuaikan path
import '../services/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class FeatureSubDetailService {
  final String baseUrl;
  final DatabaseHelper db;

  FeatureSubDetailService({required this.baseUrl, required this.db});

  // Fetch all from API
  Future<List<FeatureSubDetail>> fetchFeatureSubDetailsFromApi() async {
    final response = await http.get(Uri.parse('$baseUrl/SUBDETAIL_FEATURE'));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => FeatureSubDetail.fromJson(e)).toList();
    } else {
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
