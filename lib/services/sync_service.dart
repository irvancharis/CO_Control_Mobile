import 'dart:convert';
import 'package:http/http.dart' as http;

import 'database_helper.dart';
import '../models/sales_model.dart';
import '../models/feature_model.dart';
import '../models/feature_detail_model.dart';
import '../models/feature_subdetail_model.dart';
// import '../config/server.dart'; // Hapus jika tidak dipakai, karena sudah pakai api_config
import '../utils/api_config.dart';

class SyncService {
  static Future<void> syncAll() async {
    final db = DatabaseHelper.instance;

    print("--- MULAI SYNC DATA ---");

    // 1. SALES
    // PERBAIKAN: Panggil fungsi getUrl(...)
    final String salesUrl = ApiConfig.getUrl('/DATASALES');
    final salesRes = await http.get(Uri.parse(salesUrl));

    print("SALES RESPONSE: ${salesRes.statusCode} dari $salesUrl");
    if (salesRes.statusCode == 200) {
      final List data = jsonDecode(salesRes.body);
      await db.clearTable('sales');
      for (final json in data) {
        // print("INSERT SALES: $json"); // Print dimatikan biar log gak penuh
        await db.insertSales(Sales.fromJson(json));
      }
      print("✅ Sales tersimpan: ${data.length} data");
    } else {
      print("❌ Failed to get SALES");
    }

    // 2. Clear feature tables before sync
    await db.clearTable('feature');
    await db.clearTable('feature_detail');
    await db.clearTable('feature_subdetail');

    // 3. FEATURE
    // PERBAIKAN: Panggil fungsi getUrl(...)
    final String featureUrl = ApiConfig.getUrl('/FEATURE');
    final featureRes = await http.get(Uri.parse(featureUrl));

    print("FEATURE RESPONSE: ${featureRes.statusCode} dari $featureUrl");
    if (featureRes.statusCode == 200) {
      final List featureList = jsonDecode(featureRes.body);
      for (final featJson in featureList) {
        await db.insertFeature(Feature.fromJson(featJson));
      }
      print("✅ Feature tersimpan: ${featureList.length} data");
    } else {
      print("❌ Failed to get FEATURE");
    }

    // 4. DETAIL_FEATURE
    // PERBAIKAN: Panggil fungsi getUrl(...)
    final String detailUrl = ApiConfig.getUrl('/DETAIL_FEATURE');
    final detailRes = await http.get(Uri.parse(detailUrl));

    print("DETAIL RESPONSE: ${detailRes.statusCode} dari $detailUrl");
    if (detailRes.statusCode == 200) {
      final List detailList = jsonDecode(detailRes.body);

      final List<FeatureDetail> parsedDetails =
          detailList.map((json) => FeatureDetail.fromJson(json)).toList();

      await db.insertAllFeatureDetails(parsedDetails); // batch insert
      print("✅ Feature Details tersimpan: ${parsedDetails.length} data");
    } else {
      print("❌ Failed to get DETAIL_FEATURE");
    }

    // 5. SUBDETAIL_FEATURE
    // PERBAIKAN: Panggil fungsi getUrl(...)
    final String subDetailUrl = ApiConfig.getUrl('/SUBDETAIL_FEATURE');
    final subDetailRes = await http.get(Uri.parse(subDetailUrl));

    print("SUBDETAIL RESPONSE: ${subDetailRes.statusCode} dari $subDetailUrl");
    if (subDetailRes.statusCode == 200) {
      final List subDetailList = jsonDecode(subDetailRes.body);
      for (final subJson in subDetailList) {
        await db.insertFeatureSubDetail(FeatureSubDetail.fromJson(subJson));
      }
      print("✅ SubDetail tersimpan: ${subDetailList.length} data");
    } else {
      print("❌ Failed to get SUBDETAIL_FEATURE");
    }

    // 6. Optionally: print jumlah data
    final allFeatures = await db.getAllFeature();
    print('--- SYNC SELESAI. Total Feature: ${allFeatures.length} ---');
  }
}
