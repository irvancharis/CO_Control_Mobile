import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../config/server.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../models/feature_detail_model.dart';
import '../models/feature_subdetail_model.dart';
import '../models/pelanggan_model.dart';
import '../services/database_helper.dart';
import '../services/submit_visit_service.dart';
import 'pelanggan_list_screen.dart';
import 'pelanggan_list_custom_screen.dart';

class _UX {
  static const primary = Color(0xFF8E7CC3);
  static const primaryDark = Color(0xFF6F5AA8);
  static const primarySurface = Color(0xFFF0ECFA);
  static const success = Color(0xFF2EAD54);
  static const bg = Color(0xFFF7F1FF);
  static const surface = Colors.white;
  static const cardBorder = Color(0xFFE6E2F2);
  static const textMuted = Color(0xFF7A7A7A);
  static const danger = Color(0xFFD9534F);
  static const r10 = 10.0;
  static const r12 = 12.0;
  static const r16 = 16.0;
  static const r999 = 999.0;

  static InputBorder roundedBorder() => OutlineInputBorder(
        borderRadius: BorderRadius.circular(r12),
        borderSide: const BorderSide(color: Color(0xFFE1E1E8)),
      );
}

class DetailFeatureChecklistScreen extends StatefulWidget {
  final String featureId;
  final String title;
  final Pelanggan pelanggan;
  final String featureType;

  const DetailFeatureChecklistScreen({
    Key? key,
    required this.featureId,
    required this.title,
    required this.pelanggan,
    required this.featureType,
  }) : super(key: key);

  @override
  State<DetailFeatureChecklistScreen> createState() =>
      _DetailFeatureChecklistScreenState();
}

class _DetailFeatureChecklistScreenState
    extends State<DetailFeatureChecklistScreen> {
  List<FeatureDetail> _details = [];
  String? idSpv;
  String? idSalesStr;
  int? idSales;
  String? latitude;
  String? longitude;
  DateTime? mulai;
  String catatan = '';
  bool isSubmitting = false;
  String visitId = '';
  bool isLoadingChecklist = true;
  late TextEditingController catatanController;

  // PASTIKAN hanya 1 deklarasi ini dan tipenya File?
  File? _fotoFile;

  @override
  void initState() {
    super.initState();
    mulai = DateTime.now();
    catatanController = TextEditingController();
    getSpvFromPrefs().then((_) => checkOrCreateVisit());
    getCurrentLocation();
  }

  @override
  void dispose() {
    catatanController.dispose();
    super.dispose();
  }

  // ==================== FOTO: ambil & kompres (konversi XFile -> File) ====================
  Future<void> _ambilFoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile =
          await picker.pickImage(source: ImageSource.camera);

      if (pickedFile == null) return;

      // konversi XFile -> File
      final File originalFile = File(pickedFile.path);

      // buat path sementara untuk hasil kompres
      final Directory dir = await getTemporaryDirectory();
      final String targetPath = "${dir.path}/$visitId.jpg";

      // kompres
      final XFile? compressedXFile =
          await FlutterImageCompress.compressAndGetFile(
        originalFile.path,
        targetPath,
        quality: 50,
      );

// konversi ke File
      final File? compressedFile =
          compressedXFile != null ? File(compressedXFile.path) : null;

      if (!mounted) return;

      setState(() {
        // kalau hasil kompres null, fallback ke foto asli
        _fotoFile = compressedFile ?? originalFile;
      });
    } catch (e) {
      debugPrint('Error ambil/kompres foto: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal ambil foto: $e')),
      );
    }
  }

  // ==================== FOTO: upload ke server ====================
  Future<String?> _uploadFoto(File foto) async {
    try {
      final Uri uri = Uri.parse("${ServerConfig.baseUrl}/upload-selfie");

      final request = http.MultipartRequest("POST", uri)
        ..files.add(
          await http.MultipartFile.fromPath(
            "selfie",
            foto.path,
            filename: "$visitId.jpg", // <- jadikan nama file sesuai id_visit
          ),
        );

      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        // karena kita sudah tentukan nama file, langsung return saja
        return "$visitId.jpg";
      } else {
        debugPrint("Upload gagal: ${response.statusCode} - $respStr");
        return null;
      }
    } catch (e) {
      debugPrint("Error upload foto: $e");
      return null;
    }
  }

  // ==================== PREFS & LOCATION ====================
  Future<void> getSpvFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    idSpv = prefs.getString('user_id');
    idSalesStr = prefs.getString('selectedSalesId');

    // Konversi ke int
    if (idSalesStr != null) {
      idSales = int.tryParse(idSalesStr!);
    }
  }

  Future<void> getCurrentLocation() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Layanan lokasi tidak diaktifkan.')),
      );
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin lokasi ditolak.')),
        );
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Izin lokasi ditolak secara permanen, tidak dapat meminta izin.')),
      );
      return;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      latitude = position.latitude.toString();
      longitude = position.longitude.toString();
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mendapatkan lokasi: $e')),
      );
    }
  }

  // ==================== VISIT: check/create ====================
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
        idSales: idSales ?? 0,
        noCall: widget.pelanggan.nocall ?? '',
        latitude: latitude,
        longitude: longitude,
      );
    }

    await _loadCatatanFromDB();
    await loadChecklist();
  }

  Future<void> _loadCatatanFromDB() async {
    final result = await DatabaseHelper.instance.getCatatanByVisitId(visitId);
    if (!mounted) return;
    setState(() {
      catatan = result ?? '';
      catatanController.text = catatan;
    });
  }

  // ==================== LOAD CHECKLIST ====================
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
        final Map<String, bool> checkedMap = {
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

      if (!mounted) return;
      setState(() {
        _details = details;
        isLoadingChecklist = false;
      });
    } catch (e) {
      debugPrint('loadChecklist error: $e');
      if (!mounted) return;
      setState(() => isLoadingChecklist = false);
    }
  }

  Future<void> _saveAllChecklistDetails() async {
    // Pastikan semua kombinasi detail-subdetail tersimpan
    for (final detail in _details) {
      for (final sub in detail.subDetails) {
        await DatabaseHelper.instance.upsertChecklistDetail(
          idVisit: visitId,
          idFeature: widget.featureId,
          idFeatureDetail: detail.id,
          idFeatureSubDetail: sub.id,
          isChecked: sub.isChecked, // true jika dicentang, false jika tidak
        );
      }
    }
  }

  // ==================== SUBMIT CHECKLIST (simpan lokal) ====================
  Future<void> submitChecklist(String selfieFilename) async {
    catatan = catatanController.text.trim();

    if (idSpv == null ||
        latitude == null ||
        longitude == null ||
        mulai == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data supervisor/posisi belum lengkap!')),
      );
      return;
    }

    setState(() => isSubmitting = true);
    final selesai = DateTime.now();

    try {
      // >>>>> Tambahan penting: persist semua subdetail termasuk yang tidak dicentang
      await _saveAllChecklistDetails();

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
        idSales: idSales ?? 0,
        nocall: widget.pelanggan.nocall,
      );

      if (!mounted) return;
      setState(() => isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checklist berhasil disimpan secara lokal'),
          backgroundColor: Colors.green,
        ),
      );

      final isCustom = widget.featureType.toLowerCase() == 'custom';
      final screen = isCustom
          ? PelangganListCustomScreen(
              featureId: widget.featureId,
              title: widget.title,
              featureType: widget.featureType,
            )
          : PelangganListScreen(
              featureId: widget.featureId,
              title: widget.title,
              featureType: widget.featureType,
            );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );
    } catch (e) {
      debugPrint('submitChecklist error: $e');
      if (!mounted) return;
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan checklist: $e')),
      );
    }
  }

  // ==================== HISTORY SELLING ====================
  Future<void> _fetchHistorySelling() async {
    final idPelanggan = widget.pelanggan.id;
    final url =
        Uri.parse("${ServerConfig.baseUrl}/DATAHISTORYSELLING/$idPelanggan");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) {
            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, controller) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const Text(
                        "History Selling",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          controller: controller,
                          itemCount: data.length,
                          itemBuilder: (context, i) {
                            final row = data[i];
                            return _buildHistoryCard(row);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("Gagal load history selling (${response.statusCode})"),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Fetch error: $e")),
      );
    }
  }

  Future<List<dynamic>> _fetchDetail(
      String tanggal, String idSales, String idPelanggan) async {
    final tgl =
        DateFormat("yyyy-MM-dd").format(DateTime.parse(tanggal).toLocal());

    final url = Uri.parse(
        "${ServerConfig.baseUrl}/DETAILHISTORYSELLING/$idSales/$tgl/$idPelanggan");

    final response = await http.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Gagal fetch detail");
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

  Widget _headerCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Material(
        color: _UX.surface,
        elevation: 1,
        borderRadius: BorderRadius.circular(_UX.r16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _UX.primarySurface,
                child: const Icon(Icons.store_mall_directory,
                    color: _UX.primaryDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.pelanggan.nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      widget.pelanggan.alamat,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _UX.textMuted),
                    ),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () async {
                  final lat = widget.pelanggan.latitude;
                  final lng = widget.pelanggan.longitude;
                  final googleMapsUrl =
                      "https://www.google.com/maps/search/?api=1&query=$lat,$lng";

                  final uri = Uri.parse(googleMapsUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Tidak bisa buka Google Maps")),
                    );
                  }
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.redAccent.withOpacity(0.15),
                  child: const Icon(Icons.location_on,
                      color: Colors.redAccent, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          if (icon != null) Icon(icon, color: _UX.primaryDark, size: 18),
          if (icon != null) const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const Expanded(child: Divider(indent: 10, thickness: .6)),
        ],
      ),
    );
  }

  Widget _buildDetailCard(FeatureDetail detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: _UX.surface,
        elevation: 1,
        borderRadius: BorderRadius.circular(_UX.r12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                horizontalTitleGap: 10,
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: _UX.primarySurface,
                  child: Icon(getIconData(detail.icon), color: _UX.primaryDark),
                ),
                title: Text(
                  detail.nama,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              if (detail.subDetails.isNotEmpty) ...[
                const Divider(height: 0, color: Color(0xFFEDECF4)),
                ...detail.subDetails.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final sub = entry.value;

                  return Column(
                    children: [
                      CheckboxListTile(
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
                        title: Text(
                          sub.nama,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.trailing,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        activeColor: _UX.primaryDark,
                      ),
                      if (idx != detail.subDetails.length - 1)
                        const Divider(height: 0.5, color: Color(0xFFEDECF4)),
                    ],
                  );
                }).toList(),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _catatanField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: TextField(
        controller: catatanController,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: 'Catatan',
          hintText: 'Tambahkan catatan kunjungan...',
          filled: true,
          fillColor: _UX.surface,
          border: _UX.roundedBorder(),
          enabledBorder: _UX.roundedBorder(),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_UX.r12),
            borderSide: const BorderSide(color: _UX.primaryDark, width: 1.4),
          ),
          prefixIcon: const Icon(Icons.edit_note),
        ),
      ),
    );
  }

  Widget _submitBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: isSubmitting
            ? const SizedBox(
                height: 52, child: Center(child: CircularProgressIndicator()))
            : ElevatedButton.icon(
                onPressed: () async {
                  // ambil foto
                  await _ambilFoto();
                  if (_fotoFile == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Foto wajib diambil sebelum submit!')),
                    );
                    return;
                  }

                  // upload foto
                  final filename = await _uploadFoto(_fotoFile!);
                  if (filename == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Upload foto gagal!')),
                    );
                    return;
                  }

                  // lanjut submit checklist (simpan lokal)
                  await submitChecklist(filename);
                },
                icon:
                    const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text('SELESAI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _UX.success,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  elevation: 2,
                ),
              ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> row) {
    final tanggal = DateFormat("dd MMM yyyy")
        .format(DateTime.parse(row['TANGGAL']).toLocal());

    return _HistoryCard(
      title: tanggal,
      fetchDetails: () =>
          _fetchDetail(row['TANGGAL'], row['IDSALES'], widget.pelanggan.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (didPop) {
          final hasChanges = _details.any(
                  (detail) => detail.subDetails.any((sub) => sub.isChecked)) ||
              catatanController.text.trim().isNotEmpty;
          if (!hasChanges) {
            await DatabaseHelper.instance.deleteVisit(visitId);
          }
        }
      },
      child: Scaffold(
        backgroundColor: _UX.bg,
        body: isLoadingChecklist
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _headerCard()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ElevatedButton.icon(
                        onPressed: _fetchHistorySelling,
                        icon: const Icon(Icons.history),
                        label: const Text("Lihat History Selling"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _UX.primaryDark,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                      child: _sectionHeader('Checklist', icon: Icons.task_alt)),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _buildDetailCard(_details[i]),
                      childCount: _details.length,
                    ),
                  ),
                  SliverToBoxAdapter(
                      child: _sectionHeader('Catatan', icon: Icons.edit_note)),
                  SliverToBoxAdapter(child: _catatanField()),
                  const SliverToBoxAdapter(child: SizedBox(height: 90)),
                ],
              ),
        bottomNavigationBar: _submitBar(),
      ),
    );
  }
}

// History card widget (tetap sama)
class _HistoryCard extends StatefulWidget {
  final String title;
  final Future<List<dynamic>> Function() fetchDetails;

  const _HistoryCard({
    required this.title,
    required this.fetchDetails,
  });

  @override
  _HistoryCardState createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _isExpanded = false;
  Future<List<dynamic>>? _futureDetails;

  final NumberFormat _currencyFormatter = NumberFormat.decimalPattern('id');

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded && _futureDetails == null) {
        _futureDetails = widget.fetchDetails();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _UX.cardBorder),
      ),
      child: InkWell(
        onTap: _toggleExpansion,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _UX.primarySurface,
                    child:
                        const Icon(Icons.shopping_cart, color: _UX.primaryDark),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  RotationTransition(
                    turns: AlwaysStoppedAnimation(_isExpanded ? 0.5 : 0),
                    child: const Icon(Icons.keyboard_arrow_down),
                  ),
                ],
              ),
            ),
            if (_isExpanded)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: FutureBuilder<List<dynamic>>(
                  future: _futureDetails,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    } else if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text("Error: ${snapshot.error}",
                            style: TextStyle(
                                color: _UX.danger,
                                fontWeight: FontWeight.w600)),
                      );
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text("Tidak ada detail."),
                      );
                    } else {
                      final details = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 10),
                            decoration: BoxDecoration(
                              color: _UX.primarySurface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: const [
                                Expanded(
                                    flex: 2,
                                    child: Text("Produk",
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700))),
                                Expanded(
                                    flex: 2,
                                    child: Text("Qty",
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700))),
                                Expanded(
                                    flex: 2,
                                    child: Text("Harga",
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700))),
                                Expanded(
                                    flex: 2,
                                    child: Text("Promo",
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...details.map((detail) {
                            final hargaRaw = detail['HARGA'] ?? 0;
                            final formattedHarga =
                                _currencyFormatter.format(hargaRaw);

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 10),
                              margin: const EdgeInsets.only(bottom: 2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                  bottom: BorderSide(
                                      color: _UX.cardBorder, width: 0.6),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      detail['IDITEMPRODUK'] ?? "-",
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "${detail['QTY']} ${detail['UNIT']}",
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "Rp $formattedHarga",
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: _UX.success,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      detail['SOURCE'] ?? "-",
                                      style: const TextStyle(
                                          fontSize: 12, color: _UX.textMuted),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      );
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
