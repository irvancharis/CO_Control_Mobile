import 'dart:convert';
import 'package:http/http.dart' as http;

import 'database_helper.dart';
import '../models/sales_model.dart';
import '../models/feature_model.dart';
import '../models/feature_detail_model.dart';
import '../models/feature_subdetail_model.dart';
import '../config/server.dart';

class SyncService {
  static Future<void> syncAll() async {
    final db = DatabaseHelper.instance;
    final baseUrl = ServerConfig.baseUrl;

    // 1. SALES
    final salesRes = await http.get(Uri.parse('$baseUrl/DATASALES'));
    print("SALES RESPONSE: ${salesRes.statusCode} ${salesRes.body}");
    if (salesRes.statusCode == 200) {
      final List data = jsonDecode(salesRes.body);
      await db.clearTable('sales');
      for (final json in data) {
        print("INSERT SALES: $json");
        await db.insertSales(Sales.fromJson(json));
      }
    } else {
      print("Failed to get SALES");
    }

    // 2. Clear feature tables before sync
    await db.clearTable('feature');
    await db.clearTable('feature_detail');
    await db.clearTable('feature_subdetail');

    // 3. FEATURE
    final featureRes = await http.get(Uri.parse('$baseUrl/FEATURE'));
    print("FEATURE RESPONSE: ${featureRes.statusCode} ${featureRes.body}");
    if (featureRes.statusCode == 200) {
      final List featureList = jsonDecode(featureRes.body);
      for (final featJson in featureList) {
        print("INSERT FEATURE: $featJson");
        await db.insertFeature(Feature.fromJson(featJson));
      }
    } else {
      print("Failed to get FEATURE");
    }

    // 4. DETAIL_FEATURE → Parse dan masukkan semua sekaligus
    final detailRes = await http.get(Uri.parse('$baseUrl/DETAIL_FEATURE'));
    print("DETAIL RESPONSE: ${detailRes.statusCode} ${detailRes.body}");
    if (detailRes.statusCode == 200) {
      final List detailList = jsonDecode(detailRes.body);

      final List<FeatureDetail> parsedDetails =
          detailList.map((json) => FeatureDetail.fromJson(json)).toList();

      print("Jumlah FeatureDetail ter-parse: ${parsedDetails.length}");

      await db.insertAllFeatureDetails(parsedDetails); // batch insert
    } else {
      print("Failed to get DETAIL_FEATURE");
    }

    // 5. SUBDETAIL_FEATURE
    final subDetailRes =
        await http.get(Uri.parse('$baseUrl/SUBDETAIL_FEATURE'));
    print(
        "SUBDETAIL RESPONSE: ${subDetailRes.statusCode} ${subDetailRes.body}");
    if (subDetailRes.statusCode == 200) {
      final List subDetailList = jsonDecode(subDetailRes.body);
      for (final subJson in subDetailList) {
        print("INSERT FEATURE SUBDETAIL: $subJson");
        await db.insertFeatureSubDetail(FeatureSubDetail.fromJson(subJson));
      }
    } else {
      print("Failed to get SUBDETAIL_FEATURE");
    }

    // 6. Optionally: print jumlah data
    final allFeatures = await db.getAllFeature();
    print('Jumlah feature setelah sync: ${allFeatures.length}');
  }
}
