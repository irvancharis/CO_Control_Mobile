import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../models/feature_detail_model.dart';
import '../models/feature_subdetail_model.dart';
import '../models/pelanggan_model.dart';
import '../services/database_helper.dart';
import '../services/submit_visit_service.dart';

class DetailFeatureChecklistScreen extends StatefulWidget {
  final String featureId;
  final String title;
  final Pelanggan pelanggan;

  const DetailFeatureChecklistScreen({
    Key? key,
    required this.featureId,
    required this.title,
    required this.pelanggan,
  }) : super(key: key);

  @override
  State<DetailFeatureChecklistScreen> createState() =>
      _DetailFeatureChecklistScreenState();
}

class _DetailFeatureChecklistScreenState
    extends State<DetailFeatureChecklistScreen> {
  List<FeatureDetail> _details = [];
  String? idSpv;
  String? latitude;
  String? longitude;
  DateTime? mulai;
  String catatan = '';
  bool isSubmitting = false;
  String visitId = '';
  bool isLoadingChecklist = true;

  @override
  void initState() {
    super.initState();
    mulai = DateTime.now();
    getSpvFromPrefs().then((_) => checkOrCreateVisit());
    getCurrentLocation();
  }

  Future<void> getSpvFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    idSpv = prefs.getString('user_id');
  }

  Future<void> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    latitude = position.latitude.toString();
    longitude = position.longitude.toString();
  }

  Future<void> checkOrCreateVisit() async {
    final existing =
        await DatabaseHelper.instance.getVisitByPelangganAndFeature(
      idPelanggan: widget.pelanggan.id,
      idFeature: widget.featureId,
    );

    if (existing != null) {
      visitId = existing['id_visit'];
    } else {
      visitId = const Uuid().v4();
      await DatabaseHelper.instance.insertVisitIfNotExists(
        idVisit: visitId,
        idPelanggan: widget.pelanggan.id,
        idSpv: idSpv ?? '',
        idSales: 0,
        noCall: widget.pelanggan.nocall ?? '',
        latitude: latitude,
        longitude: longitude,
      );
    }

    await loadChecklist(); // load setelah visitId pasti ada
  }

  Future<void> loadChecklist() async {
    setState(() => isLoadingChecklist = true);

    try {
      final localDetails = await DatabaseHelper.instance.getChecklistDetail(
        idVisit: visitId,
        idFeature: widget.featureId,
      );

      final details = await DatabaseHelper.instance
          .getFeatureDetailsWithSubDetailByFeatureId(widget.featureId);

      if (localDetails.isNotEmpty) {
        final checkedMap = {
          for (var row in localDetails)
            '${row['id_featuredetail']}_${row['id_featuresubdetail']}':
                row['checklist'] == 1
        };

        for (var detail in details) {
          for (var sub in detail.subDetails) {
            final key = '${detail.id}_${sub.id}';
            sub.isChecked = checkedMap[key] ?? false;
          }
        }
      }

      setState(() {
        _details = details;
        isLoadingChecklist = false;
      });
    } catch (e) {
      debugPrint('loadChecklist error: $e');
      setState(() => isLoadingChecklist = false);
    }
  }

  Future<void> _updateChecklistToLocal() async {
    for (final detail in _details) {
      for (final sub in detail.subDetails) {
        await DatabaseHelper.instance.upsertChecklistDetail(
          idVisit: visitId,
          idFeature: widget.featureId,
          idFeatureDetail: detail.id,
          idFeatureSubDetail: sub.id,
          isChecked: sub.isChecked,
        );
      }
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

  Widget buildChecklist(FeatureDetail detail) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(getIconData(detail.icon), color: Colors.blue),
              title: Text(detail.nama,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            if (detail.subDetails.isNotEmpty) const Divider(height: 0),
            ...detail.subDetails.map((sub) {
              return CheckboxListTile(
                title: Text(sub.nama),
                value: sub.isChecked,
                onChanged: (val) async {
                  setState(() => sub.isChecked = val ?? false);
                  await DatabaseHelper.instance.upsertChecklistDetail(
                    idVisit: visitId,
                    idFeature: widget.featureId,
                    idFeatureDetail: detail.id,
                    idFeatureSubDetail: sub.id,
                    isChecked: sub.isChecked,
                  );
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Future<void> submitChecklist() async {
    if (idSpv == null || latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data supervisor/posisi belum lengkap!')),
      );
      return;
    }

    setState(() => isSubmitting = true);
    final selesai = DateTime.now();

    // Cetak semua data sebelum submit
    print('📤 Submit Visit Payload:');
    print('idVisit: $visitId');
    print('tanggal: ${DateTime.now()}');
    print('idSpv: $idSpv');
    print('idPelanggan: ${widget.pelanggan.id}');
    print('latitude: $latitude');
    print('longitude: $longitude');
    print('mulai: $mulai');
    print('selesai: $selesai');
    print('catatan: $catatan');
    print('idFeature: ${widget.featureId}');
    print('idSales: null');
    print('nocall: ${widget.pelanggan.nocall}');
    print('details:');

    for (var detail in _details) {
      print('  FeatureDetail: ${detail.id} - ${detail.nama}');
      for (var sub in detail.subDetails) {
        print(
            '    SubDetail: ${sub.id} - ${sub.nama} | checked: ${sub.isChecked}');
      }
    }

    await SubmitVisitLocalService.saveChecklistToLocal(
      idVisit: visitId,
      tanggal: DateTime.now(),
      mulai: mulai!,
      selesai: selesai,
      idSpv: idSpv!,
      idPelanggan: widget.pelanggan.id,
      latitude: latitude,
      longitude: longitude,
      catatan: catatan,
      idFeature: widget.featureId,
      idSales: 0, // ganti jika kamu sudah tahu idSales-nya
      nocall: widget.pelanggan.nocall,
    );

    setState(() => isSubmitting = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Checklist berhasil disimpan secara lokal'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoadingChecklist
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    margin: const EdgeInsets.all(12),
                    color: Colors.blue[50],
                    child: ListTile(
                      title: Text(widget.pelanggan.nama,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle:
                          Text('NOCALL: ${widget.pelanggan.nocall ?? "-"}'),
                    ),
                  ),
                  ..._details.map(buildChecklist).toList(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextFormField(
                      initialValue: catatan,
                      decoration: const InputDecoration(
                        labelText: 'Catatan',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      onChanged: (val) async {
                        catatan = val;
                        await _updateChecklistToLocal();
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: isSubmitting
                        ? const SizedBox(
                            height: 50,
                            child: Center(child: CircularProgressIndicator()))
                        : ElevatedButton.icon(
                            onPressed: submitChecklist,
                            icon: const Icon(Icons.check_circle_outline,
                                size: 20, color: Colors.white),
                            label: const Text('SELESAI'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(50),
                              textStyle: const TextStyle(fontSize: 18),
                            ),
                          ),
                  ),
                  const SizedBox(height: 24), // jarak bawah biar tidak mentok
                ],
              ),
            ),
    );
  }
}
