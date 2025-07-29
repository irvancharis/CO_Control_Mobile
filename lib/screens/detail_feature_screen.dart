import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/feature_detail_model.dart';
import '../services/feature_detail_service.dart';
import '../services/submit_service.dart';
import '../models/pelanggan_model.dart';
import '../services/pelanggan_service.dart';

class DetailFeatureScreen extends StatefulWidget {
  final String featureId;
  final String title;

  const DetailFeatureScreen({
    Key? key,
    required this.featureId,
    required this.title,
  }) : super(key: key);

  @override
  State<DetailFeatureScreen> createState() => _DetailFeatureScreenState();
}

class _DetailFeatureScreenState extends State<DetailFeatureScreen> {
  late Future<List<FeatureDetail>> _futureDetails;
  final String visitId = const Uuid().v4();

  String? idSpv;
  String? idPelanggan;
  String? latitude;
  String? longitude;
  DateTime? mulai;
  String catatan = '';
  bool formCompleted = false;
  bool isSubmitting = false;

  List<Pelanggan> pelangganList = [];

  @override
  void initState() {
    super.initState();
    mulai = DateTime.now();
    requestPermissions();
    getSpvFromPrefs();
    getCurrentLocation();
    fetchPelanggan();
    _futureDetails = FeatureDetailService().fetchDetails(widget.featureId);
  }

  Future<void> requestPermissions() async {
    await [
      Permission.location,
      Permission.storage,
      Permission.camera,
      Permission.microphone,
    ].request();
  }

  void getSpvFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('user_id');
    print("SPV dari SharedPrefs: $id");
    setState(() => idSpv = id);
  }

  void getCurrentLocation() async {
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
    print("Lokasi: ${position.latitude}, ${position.longitude}");
    setState(() {
      latitude = position.latitude.toString();
      longitude = position.longitude.toString();
    });
  }

  void fetchPelanggan() async {
    final list = await PelangganService().fetchPelanggan();
    setState(() => pelangganList = list);
  }

  void submitChecklist(List<FeatureDetail> details) async {
    setState(() => isSubmitting = true);
    final selesai = DateTime.now();

    final success = await SubmitService.submitVisit(
      idVisit: visitId,
      tanggal: DateTime.now(),
      idSpv: idSpv!,
      idPelanggan: idPelanggan!,
      latitude: latitude!,
      longitude: longitude!,
      mulai: mulai!,
      selesai: selesai,
      catatan: catatan,
      idFeature: widget.featureId,
      details: details,
    );

    setState(() => isSubmitting = false);

    if (success && mounted) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checklist berhasil disimpan'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan data')),
      );
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

  Widget buildInitialForm() {
    final isReady = idSpv != null &&
        latitude != null &&
        longitude != null &&
        idPelanggan != null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Lengkapi Data Kunjungan",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[800],
                    ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: idPelanggan,
                decoration: const InputDecoration(
                  labelText: 'Pilih Pelanggan',
                  border: OutlineInputBorder(),
                ),
                items: pelangganList
                    .map((pel) => DropdownMenuItem(
                          value: pel.id,
                          child: Text(pel.nama),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => idPelanggan = val),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Catatan',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                onChanged: (val) => catatan = val,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Lanjut ke Checklist'),
                onPressed:
                    isReady ? () => setState(() => formCompleted = true) : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor:
                      isReady ? Theme.of(context).primaryColor : Colors.grey,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 16),
                ),
              )
            ],
          ),
        ),
      ),
    );
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
              ),
            ),
            const Divider(height: 0),
            ...detail.subDetails.map((sub) {
              return CheckboxListTile(
                title: Text(sub.nama),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      backgroundColor: const Color(0xFFF2F4F8),
      body: FutureBuilder<List<FeatureDetail>>(
        future: _futureDetails,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Tidak ada detail tersedia'));
          }

          final details = snapshot.data!;

          return Column(
            children: [
              if (!formCompleted) buildInitialForm(),
              if (formCompleted) ...[
                Expanded(
                  child: ListView.builder(
                    itemCount: details.length,
                    itemBuilder: (context, index) {
                      return buildChecklist(details[index]);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
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
                )
              ]
            ],
          );
        },
      ),
    );
  }
}
