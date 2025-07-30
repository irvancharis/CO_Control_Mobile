import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../models/feature_detail_model.dart';
import '../models/pelanggan_model.dart';
import '../services/feature_detail_service.dart';
import '../services/submit_service.dart';

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
  late Future<List<FeatureDetail>> _futureDetails;
  final String visitId = const Uuid().v4();

  String? idSpv;
  String? latitude;
  String? longitude;
  DateTime? mulai;
  String catatan = '';
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    mulai = DateTime.now();
    _futureDetails = FeatureDetailService().fetchDetails(widget.featureId);
    getSpvFromPrefs();
    getCurrentLocation();
  }

  Future<void> getSpvFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      idSpv = prefs.getString('user_id');
    });
  }

  Future<void> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Layanan lokasi tidak aktif')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin lokasi ditolak')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Izin lokasi ditolak permanen')),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      latitude = position.latitude.toString();
      longitude = position.longitude.toString();
    });
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
              title: Text(
                detail.nama,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            const Divider(height: 0),
            ...detail.subDetails.map((sub) {
              return CheckboxListTile(
                title: Text(
                  sub.nama,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                value: sub.isChecked,
                onChanged: (val) {
                  setState(() {
                    sub.isChecked = val ?? false;
                  });
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

  Future<void> submitChecklist(List<FeatureDetail> details) async {
    if (idSpv == null || latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data supervisor/posisi belum lengkap!')),
      );
      return;
    }

    setState(() => isSubmitting = true);
    final selesai = DateTime.now();

    final success = await SubmitService.submitVisit(
      idVisit: visitId,
      tanggal: DateTime.now(),
      idSpv: idSpv!,
      idPelanggan: widget.pelanggan.id,
      latitude: latitude!,
      longitude: longitude!,
      mulai: mulai!,
      selesai: selesai,
      catatan: catatan,
      idFeature: widget.featureId,
      details: details,
      idSales: null, // optional, atau bisa tambahkan jika pakai sales
      nocall: widget.pelanggan.nocall,
    );

    setState(() => isSubmitting = false);
    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checklist berhasil disimpan'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan data')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.title} (${widget.pelanggan.nama})')),
      backgroundColor: const Color(0xFFF2F4F8),
      body: FutureBuilder<List<FeatureDetail>>(
        future: _futureDetails,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Tidak ada checklist tersedia'));
          }

          final details = snapshot.data!;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  margin: const EdgeInsets.all(12),
                  color: Colors.blue[50],
                  child: ListTile(
                    title: Text(widget.pelanggan.nama,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('NOCALL: ${widget.pelanggan.nocall ?? "-"}'),
                  ),
                ),
                ...details.map(buildChecklist).toList(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Catatan',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    onChanged: (val) => catatan = val,
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: isSubmitting
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: () => submitChecklist(details),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Submit Checklist'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(50),
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
