import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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
  String? latitude;
  String? longitude;
  DateTime? mulai;
  String catatan = '';
  bool isSubmitting = false;
  String visitId = '';
  bool isLoadingChecklist = true;
  late TextEditingController catatanController;

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

  // NOTE: This method is not used directly, as the onChanged handlers already save the data.
  // It's kept here for reference if a bulk update is ever needed.
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

  Future<void> submitChecklist() async {
    if (idSpv == null ||
        latitude == null ||
        longitude == null ||
        mulai == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data supervisor/posisi belum lengkap!')),
      );
      return;
    }

    setState(() => isSubmitting = true);
    final selesai = DateTime.now();

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
      idSales: 0,
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
  }

  // === FETCH HISTORY SELLING ===
  Future<void> _fetchHistorySelling() async {
    final idPelanggan = widget.pelanggan.id;
    final url =
        Uri.parse("http://192.168.3.253:3000/DATAHISTORYSELLING/$idPelanggan");

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
                            final tanggal = DateFormat("dd MMM yyyy").format(
                                DateTime.parse(row['TANGGAL']).toLocal());

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: _UX.cardBorder),
                              ),
                              child: ExpansionTile(
                                tilePadding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                leading: CircleAvatar(
                                  backgroundColor: _UX.primarySurface,
                                  child: const Icon(Icons.shopping_cart,
                                      color: _UX.primaryDark),
                                ),
                                title: Text(
                                  tanggal,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15),
                                ),
                                childrenPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                children: [
                                  FutureBuilder<List<dynamic>>(
                                    future: _fetchDetail(row['TANGGAL'],
                                        row['IDSALES'], idPelanggan),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Center(
                                              child:
                                                  CircularProgressIndicator()),
                                        );
                                      } else if (snapshot.hasError) {
                                        return Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                              "Error: ${snapshot.error}",
                                              style: TextStyle(
                                                  color: _UX.danger,
                                                  fontWeight: FontWeight.w600)),
                                        );
                                      } else if (!snapshot.hasData ||
                                          snapshot.data!.isEmpty) {
                                        return const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text("Tidak ada detail."),
                                        );
                                      } else {
                                        final details = snapshot.data!;
                                        return Column(
                                          children: [
                                            // Header row
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 6,
                                                      horizontal: 10),
                                              decoration: BoxDecoration(
                                                color: _UX.primarySurface,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: const [
                                                  Expanded(
                                                      flex: 3,
                                                      child: Text("Produk",
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700))),
                                                  Expanded(
                                                      flex: 2,
                                                      child: Text("Qty",
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700))),
                                                  Expanded(
                                                      flex: 2,
                                                      child: Text("Harga",
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700))),
                                                  Expanded(
                                                      flex: 2,
                                                      child: Text("Promo",
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700))),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 4),

                                            // Data rows
                                            ...details.map((detail) {
                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 6,
                                                        horizontal: 10),
                                                margin: const EdgeInsets.only(
                                                    bottom: 2),
                                                decoration: const BoxDecoration(
                                                  color: Colors.white,
                                                  border: Border(
                                                    bottom: BorderSide(
                                                        color: _UX.cardBorder,
                                                        width: 0.6),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 3,
                                                      child: Text(
                                                        detail['IDITEMPRODUK'] ??
                                                            "-",
                                                        style: const TextStyle(
                                                            fontSize: 13),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        "${detail['QTY']} ${detail['UNIT']}",
                                                        style: const TextStyle(
                                                            fontSize: 13),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        "Rp ${detail['HARGA']}",
                                                        style: const TextStyle(
                                                            fontSize: 13,
                                                            color: _UX.success,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        detail['SOURCE'] ?? "-",
                                                        style: const TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                _UX.textMuted),
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
                                  )
                                ],
                              ),
                            );
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text("Gagal load history selling (${response.statusCode})")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Fetch error: $e")));
    }
  }

  Future<List<dynamic>> _fetchDetail(
      String tanggal, String idSales, String idPelanggan) async {
    final tgl =
        DateFormat("yyyy-MM-dd").format(DateTime.parse(tanggal).toLocal());

    final url = Uri.parse(
        "http://192.168.3.253:3000/DETAILHISTORYSELLING/$idSales/$tgl/$idPelanggan");

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
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              if (detail.subDetails.isNotEmpty)
                const Divider(height: 0, color: Color(0xFFEDECF4)),
              ...detail.subDetails.map((sub) => CheckboxListTile(
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
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    activeColor: _UX.primaryDark,
                  )),
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
        onChanged: (val) async {
          setState(() => catatan = val);
          // Note: The onChanged handler for the text field automatically updates the state.
          // The data is saved to the DB upon submit.
        },
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
                onPressed: submitChecklist,
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

  @override
  Widget build(BuildContext context) {
    // START: Added PopScope to handle back button press.
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        // Only run the logic if the system navigation is popping the route.
        if (didPop) {
          // Check if any checklist item is checked OR if the notes field has content.
          final hasChanges = _details.any(
                  (detail) => detail.subDetails.any((sub) => sub.isChecked)) ||
              catatanController.text.trim().isNotEmpty;

          // If no changes were made, delete the empty visit transaction.
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
                  SliverList.builder(
                    itemCount: _details.length,
                    itemBuilder: (context, i) => _buildDetailCard(_details[i]),
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
    // END: Added PopScope.
  }
}
