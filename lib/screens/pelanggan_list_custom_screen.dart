import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../models/pelanggan_model.dart';
import '../models/sales_model.dart';
import '../models/feature_detail_model.dart';
import '../models/feature_subdetail_model.dart';
import '../services/pelanggan_service.dart';
import '../services/database_helper.dart';
import '../services/submit_service.dart';
import 'detail_feature_checklist_screen.dart';

// ======= Color & Style Tokens (samakan dengan screen lain) =======
class _UX {
  static const primary = Color(0xFF8E7CC3);
  static const primaryDark = Color(0xFF6F5AA8);
  static const primarySurface = Color(0xFFF0ECFA);
  static const success = Color(0xFF2EAD54);
  static const bg = Color(0xFFF7F1FF);
  static const surface = Colors.white;
  static const cardBorder = Color(0xFFE6E2F2);
  static const textMuted = Color(0xFF7A7A7A);
  static const disabledBg = Color(0xFFF2F2F6);
  static const disabledText = Color(0xFF9A9AA2);
  static const r12 = 12.0;
  static const r16 = 16.0;
  static const r999 = 999.0;

  static InputBorder roundedBorder() => OutlineInputBorder(
        borderRadius: BorderRadius.circular(r12),
        borderSide: const BorderSide(color: Color(0xFFE1E1E8)),
      );
}

enum _StatusFilter { all, belum, selesai }

class PelangganListCustomScreen extends StatefulWidget {
  final String featureId;
  final String title;
  final String featureType;

  const PelangganListCustomScreen({
    Key? key,
    required this.featureId,
    required this.title,
    required this.featureType,
  }) : super(key: key);

  @override
  State<PelangganListCustomScreen> createState() =>
      _PelangganListCustomScreenState();
}

class _PelangganListCustomScreenState extends State<PelangganListCustomScreen> {
  // Data
  List<Sales> salesList = [];
  Sales? selectedSales;

  List<Pelanggan> pelangganList = [];
  List<Pelanggan> filteredPelangganList = [];
  Map<String, bool> visitStatusMap = {};

  // UI / state
  bool isLoading = false;
  bool isSalesLocked = false;

  String? lastNocall;
  DateTime selectedDate = DateTime.now();

  final searchPelangganController = TextEditingController();
  final dateController = TextEditingController();
  _StatusFilter _filter = _StatusFilter.all;

  // Active-visit lock
  String? activeVisitPelangganId;
  Pelanggan? activeVisitPelanggan;

  @override
  void initState() {
    super.initState();
    dateController.text =
        "${selectedDate.day}-${selectedDate.month}-${selectedDate.year}";
    loadSales();
  }

  // ===== Utilities =====
  void _applyFilters() {
    final keyword = (searchPelangganController.text).toLowerCase().trim();

    List<Pelanggan> base = List.from(pelangganList);

    if (keyword.isNotEmpty) {
      base = base.where((p) {
        final n = (p.nama).toLowerCase();
        final a = (p.alamat).toLowerCase();
        final nc = (p.nocall).toLowerCase();
        return n.contains(keyword) ||
            a.contains(keyword) ||
            nc.contains(keyword);
      }).toList();
    }

    if (_filter != _StatusFilter.all) {
      final wantSelesai = _filter == _StatusFilter.selesai;
      base = base
          .where((p) => (visitStatusMap[p.id] ?? false) == wantSelesai)
          .toList();
    }

    setState(() => filteredPelangganList = base);
  }

  // ===== Back confirm (tanpa hapus stack) =====
  Future<bool> _handleWillPop() async {
    final keluar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Yakin ingin kembali ke Dashboard?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Iya'),
          ),
        ],
      ),
    );

    if (keluar == true) {
      if (mounted) {
        Navigator.of(context)
            .pushNamed('/dashboard', arguments: widget.featureId);
      }
    }
    return false;
  }

  Future<void> pilihTanggal(BuildContext context) async {
    final now = DateTime.now();
    final twoWeeksAgo = now.subtract(const Duration(days: 30));

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.isBefore(twoWeeksAgo) ? now : selectedDate,
      firstDate: twoWeeksAgo,
      lastDate: now,
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        dateController.text = "${picked.day}-${picked.month}-${picked.year}";
        if (selectedSales != null) {
          lastNocall = generateNocall(selectedSales!, tanggal: picked);
        }
      });
    }
  }

  String generateNocall(Sales sales, {DateTime? tanggal}) {
    final date = tanggal ?? DateTime.now();
    final formatted =
        "${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}";
    return "W${sales.idCabang}_${sales.id}_$formatted";
  }

  Future<void> loadSales() async {
    setState(() => isLoading = true);
    try {
      salesList = await DatabaseHelper.instance.getAllSales();
      salesList
          .sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat sales: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => isLoading = false);
      await restoreState();
    }
  }

  Future<void> restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSalesId = prefs.getString('selectedSalesId');
    final savedSalesCabang = prefs.getString('selectedSalesCabang');
    final savedNocall = prefs.getString('lastNocall');
    final savedLocked = prefs.getBool('isSalesLocked') ?? false;

    if (savedSalesId != null &&
        savedSalesCabang != null &&
        savedLocked &&
        salesList.isNotEmpty) {
      final sales = salesList.firstWhere(
        (s) => s.id == savedSalesId && s.idCabang == savedSalesCabang,
        orElse: () => salesList.first,
      );

      final pelanggan = await PelangganService()
          .fetchAllPelangganLocal(fitur: widget.featureId);
      await loadVisitStatus(pelanggan);
      await refreshActiveVisit(pelangganListOverride: pelanggan);

      setState(() {
        selectedSales = sales;
        isSalesLocked = true;
        lastNocall = savedNocall;
        pelangganList = pelanggan;
        filteredPelangganList = List.from(pelanggan);
      });
      _applyFilters();
    }
  }

  Future<void> saveState() async {
    final prefs = await SharedPreferences.getInstance();
    if (selectedSales != null) {
      await prefs.setString('selectedSalesId', selectedSales!.id);
      await prefs.setString('selectedSalesCabang', selectedSales!.idCabang);
    }
    await prefs.setString('lastNocall', lastNocall ?? '');
    await prefs.setBool('isSalesLocked', isSalesLocked);
  }

  Future<void> loadVisitStatus(List<Pelanggan> list) async {
    visitStatusMap.clear();
    for (var pelanggan in list) {
      final visit =
          await DatabaseHelper.instance.getVisitByPelangganId(pelanggan.id);
      final isSelesai = visit != null &&
          visit['selesai'] != null &&
          visit['selesai'].toString().isNotEmpty;
      visitStatusMap[pelanggan.id] = isSelesai;
    }
  }

  Future<void> loadAndDownloadPelanggan() async {
    if (selectedSales == null || lastNocall == null) return;

    setState(() {
      isLoading = true;
      pelangganList = [];
      filteredPelangganList = [];
    });

    try {
      await PelangganService().downloadAndSavePelangganCustom(
        lastNocall!,
        widget.featureId,
      );

      final downloaded = await PelangganService()
          .fetchAllPelangganLocal(fitur: widget.featureId);

      await loadVisitStatus(downloaded);

      if (downloaded.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color.fromARGB(255, 126, 8, 0),
              content: Text('Data pelanggan kosong, halaman akan di-refresh',
                  style: TextStyle(color: Colors.white)),
            ),
          );
          setState(() {
            isSalesLocked = false;
          });
        }
        return;
      }

      setState(() {
        pelangganList = downloaded;
        filteredPelangganList = List.from(downloaded);
        isSalesLocked = true;
        isLoading = false;
      });

      await refreshActiveVisit();
      _applyFilters();
      await saveState();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pelanggan berhasil di-download')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal download: $e')),
        );
      }
      setState(() => isLoading = false);
    }
  }

  Future<void> submitSemuaData() async {
    setState(() => isLoading = true);
    try {
      final visits = await DatabaseHelper.instance.getAllVisits();
      final checklistRows =
          await DatabaseHelper.instance.getAllVisitChecklist();

      final Map<String, List<Map<String, dynamic>>> groupedChecklist = {};
      for (final row in checklistRows) {
        final visitId = row['id_visit'];
        groupedChecklist.putIfAbsent(visitId, () => []).add(row);
      }

      for (final visit in visits) {
        final visitId = visit['id_visit'];
        final checklist = groupedChecklist[visitId] ?? [];

        final Map<String, FeatureDetail> detailMap = {};
        for (final row in checklist) {
          final idDetail = row['id_featuredetail'];
          final idSub = row['id_featuresubdetail'];
          final isChecked = row['checklist'] == 1;

          detailMap.putIfAbsent(
            idDetail,
            () => FeatureDetail(
              id: idDetail,
              nama: '',
              idFeature: row['id_feature'],
              seq: 0,
              isRequired: 1,
              isActive: 1,
              keterangan: '',
              icon: '',
              type: '',
              subDetails: [],
            ),
          );

          detailMap[idDetail]!.subDetails.add(
                FeatureSubDetail(
                  id: idSub,
                  nama: '',
                  isChecked: isChecked,
                  seq: 0,
                  idFeatureDetail: idDetail,
                  isActive: 1,
                  isRequired: 1,
                  keterangan: '',
                  icon: '',
                  type: '',
                ),
              );
        }

        final details = detailMap.values.toList();

        final success = await SubmitService.submitVisit(
          idVisit: visitId,
          tanggal: DateTime.parse(visit['tanggal']),
          idSpv: visit['idspv'] ?? '',
          idPelanggan: visit['idpelanggan'],
          latitude: visit['latitude'] ?? '',
          longitude: visit['longitude'] ?? '',
          mulai: DateTime.parse(visit['mulai']),
          selesai: visit['selesai'] != null
              ? DateTime.parse(visit['selesai'])
              : DateTime.now(),
          catatan: visit['catatan'] ?? '',
          idFeature: details.isNotEmpty ? details[0].idFeature : '',
          details: details,
          idSales: visit['idsales'].toString(),
          nocall: visit['nocall'],
        );

        if (!success) {
          throw Exception("Gagal submit visit $visitId");
        }
      }

      await DatabaseHelper.instance.clearAllTables();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isSalesLocked');
      await prefs.remove('selectedSales');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Semua data berhasil dikirim')),
        );
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/dashboard', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim data: $e')),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ==== Helper: deteksi kunjungan aktif (selesai null/kosong) ====
  Future<void> refreshActiveVisit(
      {List<Pelanggan>? pelangganListOverride}) async {
    await DatabaseHelper.instance.deleteVisitsWithoutChecklist();
    final visits = await DatabaseHelper.instance.getAllVisits();
    String? id;
    for (final v in visits) {
      final selesai = v['selesai'];
      if (selesai == null || selesai.toString().isEmpty) {
        id = v['idpelanggan']?.toString();
        break;
      }
    }

    Pelanggan? p;
    final sourceList = pelangganListOverride ?? pelangganList;
    if (id != null) {
      try {
        p = sourceList.firstWhere((e) => e.id == id);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      activeVisitPelangganId = id;
      activeVisitPelanggan = p;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        backgroundColor: _UX.bg,
        body: RefreshIndicator(
          onRefresh: () async {
            if (isSalesLocked && selectedSales != null && lastNocall != null) {
              await loadAndDownloadPelanggan();
            }
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // ===== Summary card: Sales + Tanggal + Download =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Material(
                    color: _UX.surface,
                    elevation: 1,
                    borderRadius: BorderRadius.circular(_UX.r16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.manage_accounts,
                                  color: _UX.primaryDark),
                              SizedBox(width: 8),
                              Text('Sales & Tanggal',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: isSalesLocked
                                    ? _LockedField(
                                        value:
                                            "${selectedSales?.kodeSales ?? '-'} - ${selectedSales?.nama ?? '-'}",
                                      )
                                    : DropdownSearch<Sales>(
                                        selectedItem: selectedSales,
                                        items: salesList,
                                        itemAsString: (s) =>
                                            "${s.kodeSales} - ${s.nama}",
                                        onChanged: (s) {
                                          setState(() {
                                            selectedSales = s;
                                            lastNocall = null;
                                            searchPelangganController.clear();
                                            activeVisitPelangganId = null;
                                            activeVisitPelanggan = null;
                                          });
                                        },
                                        dropdownDecoratorProps:
                                            const DropDownDecoratorProps(
                                          dropdownSearchDecoration:
                                              InputDecoration(
                                            labelText: 'Pilih Sales',
                                            prefixIcon:
                                                Icon(Icons.person_search),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.all(
                                                  Radius.circular(_UX.r12)),
                                            ),
                                          ),
                                        ),
                                        popupProps: PopupProps.menu(
                                          showSearchBox: true,
                                          searchFieldProps: TextFieldProps(
                                            decoration: InputDecoration(
                                              hintText:
                                                  'Cari sales (kode/nama)…',
                                              prefixIcon:
                                                  const Icon(Icons.search),
                                              border: _UX.roundedBorder(),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10),
                                            ),
                                          ),
                                          emptyBuilder: (ctx, _) =>
                                              const Padding(
                                            padding: EdgeInsets.all(16),
                                            child: Text('Tidak ada hasil'),
                                          ),
                                        ),
                                        compareFn: (a, b) =>
                                            a.id == b.id &&
                                            a.idCabang == b.idCabang,
                                        filterFn: (s, q) {
                                          final k = (q ?? '').toLowerCase();
                                          return s.nama
                                                  .toLowerCase()
                                                  .contains(k) ||
                                              s.kodeSales
                                                  .toLowerCase()
                                                  .contains(k);
                                        },
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: dateController,
                                  readOnly: true,
                                  onTap: isSalesLocked
                                      ? null
                                      : () => pilihTanggal(context),
                                  decoration: const InputDecoration(
                                    labelText: 'Tanggal',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.calendar_today),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: (!isSalesLocked &&
                                    !isLoading &&
                                    selectedSales != null &&
                                    dateController.text.isNotEmpty)
                                ? Align(
                                    alignment: Alignment.centerRight,
                                    child: FilledButton.icon(
                                      key: const ValueKey('download_btn'),
                                      onPressed: () {
                                        setState(() {
                                          lastNocall = generateNocall(
                                            selectedSales!,
                                            tanggal: selectedDate,
                                          );
                                        });
                                        loadAndDownloadPelanggan();
                                      },
                                      icon: const Icon(Icons.download),
                                      label: const Text('Download Pelanggan'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _UX.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(_UX.r12),
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ===== Banner kunjungan aktif =====
              if (activeVisitPelangganId != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: _ActiveVisitBanner(
                      text:
                          'Sedang kunjungan: ${activeVisitPelanggan?.nama ?? activeVisitPelangganId}',
                    ),
                  ),
                ),

              // ===== Chips info =====
              if (isSalesLocked && (lastNocall ?? '').isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _InfoChip(
                            icon: Icons.group,
                            label: 'Jumlah',
                            value: '${filteredPelangganList.length}'),
                        _InfoChip(
                            icon: Icons.confirmation_number,
                            label: 'NoCall',
                            value: lastNocall!),
                      ],
                    ),
                  ),
                ),

              // ===== Sticky search pelanggan (pinned) =====
              if (isSalesLocked)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SearchHeaderDelegate(
                    controller: searchPelangganController,
                    onChanged: (_) => _applyFilters(),
                  ),
                ),

              // ===== Segmented filter (kustom) =====
              if (isSalesLocked)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: _SegmentedFilterBar(
                      current: _filter,
                      onChanged: (f) {
                        setState(() => _filter = f);
                        _applyFilters();
                      },
                    ),
                  ),
                ),

              // ===== List pelanggan =====
              if (isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filteredPelangganList.isEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: const Center(
                      child: Text('Tidak ada pelanggan',
                          style: TextStyle(color: _UX.textMuted)),
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: filteredPelangganList.length,
                  itemBuilder: (context, index) {
                    final p = filteredPelangganList[index];
                    final isSelesai = visitStatusMap[p.id] ?? false;

                    final isActiveVisitThis = (activeVisitPelangganId != null &&
                        p.id == activeVisitPelangganId);
                    final isDisabled =
                        (activeVisitPelangganId != null && !isActiveVisitThis);

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: _PelangganCard(
                        index: index + 1,
                        pelanggan: p,
                        isSelesai: isSelesai,
                        isDisabled: isDisabled,
                        isActiveVisit: isActiveVisitThis,
                        onTap: isDisabled
                            ? null
                            : () async {
                                final alreadySelesai = isSelesai;
                                if (alreadySelesai) {
                                  final lanjut = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text("Kunjungan Selesai"),
                                      content: const Text(
                                          "Pelanggan ini sudah selesai kunjungan. Buka kembali checklist?"),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(false),
                                          child: const Text("Batal"),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(true),
                                          child: const Text("Lanjutkan"),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (lanjut != true) return;
                                }

                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DetailFeatureChecklistScreen(
                                      featureId: widget.featureId,
                                      title: 'Checklist',
                                      pelanggan: p,
                                      featureType: widget.featureType,
                                    ),
                                  ),
                                );

                                await loadVisitStatus(pelangganList);
                                _applyFilters();
                                await refreshActiveVisit();
                              },
                      ),
                    );
                  },
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 90)),
            ],
          ),
        ),
        bottomNavigationBar: isSalesLocked
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: ElevatedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final konfirmasi = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Konfirmasi Upload'),
                                content: const Text(
                                  'Apakah Anda yakin ingin mengirim semua data kunjungan yang sudah selesai?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Batal'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _UX.success,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Ya, Upload Sekarang'),
                                  ),
                                ],
                              ),
                            );

                            if (konfirmasi == true) {
                              await submitSemuaData();
                            }
                          },
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Selesai & Upload Semua'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _UX.success,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

// ================= Reusable UI bits =================

class _LockedField extends StatelessWidget {
  final String value;
  const _LockedField({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        border: Border.all(color: _UX.cardBorder),
        borderRadius: BorderRadius.circular(_UX.r12),
        color: _UX.surface,
      ),
      child: Row(
        children: [
          const Icon(Icons.lock, color: _UX.primaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoChip(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_UX.r999),
        color: _UX.primarySurface,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _UX.primaryDark),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(color: _UX.textMuted)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ActiveVisitBanner extends StatelessWidget {
  final String text;
  const _ActiveVisitBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber[100],
        borderRadius: BorderRadius.circular(_UX.r16),
        border: Border.all(color: Colors.amber),
      ),
      child: Row(
        children: const [
          Icon(Icons.lock_clock, color: Colors.black87),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sedang kunjungan…',
              style: TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  _SearchHeaderDelegate({
    required this.controller,
    required this.onChanged,
  });

  @override
  double get minExtent => 76; // tinggi konsisten
  @override
  double get maxExtent => 76;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Penting: expand supaya paintExtent >= layoutExtent
    return SizedBox.expand(
      child: Material(
        elevation: overlapsContent ? 2 : 0,
        color: _UX.bg,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: 'Cari pelanggan (nama/alamat/nocall)',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: _UX.roundedBorder(),
              enabledBorder: _UX.roundedBorder(),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: _UX.primaryDark, width: 1.4),
              ),
              isDense: true,
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SearchHeaderDelegate oldDelegate) => false;
}

class _SegmentedFilterBar extends StatelessWidget {
  final _StatusFilter current;
  final ValueChanged<_StatusFilter> onChanged;

  const _SegmentedFilterBar({
    required this.current,
    required this.onChanged,
  });

  Widget _seg({
    required bool selected,
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_UX.r999),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: selected ? _UX.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(_UX.r999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18, color: selected ? Colors.white : _UX.primaryDark),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : _UX.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: _UX.primarySurface,
        borderRadius: BorderRadius.circular(_UX.r999),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          _seg(
            selected: current == _StatusFilter.all,
            icon: Icons.list,
            text: 'Semua',
            onTap: () => onChanged(_StatusFilter.all),
          ),
          _seg(
            selected: current == _StatusFilter.belum,
            icon: Icons.badge,
            text: 'Belum',
            onTap: () => onChanged(_StatusFilter.belum),
          ),
          _seg(
            selected: current == _StatusFilter.selesai,
            icon: Icons.check_circle,
            text: 'Selesai',
            onTap: () => onChanged(_StatusFilter.selesai),
          ),
        ],
      ),
    );
  }
}

// ===== Kartu Pelanggan dengan status & lock =====
class _PelangganCard extends StatelessWidget {
  final int index;
  final Pelanggan pelanggan;
  final bool isSelesai;
  final bool isDisabled;
  final bool isActiveVisit;
  final VoidCallback? onTap;

  const _PelangganCard({
    required this.index,
    required this.pelanggan,
    required this.isSelesai,
    required this.isDisabled,
    required this.isActiveVisit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = "${pelanggan.nama}  - ${pelanggan.nocall}";
    final alamat = pelanggan.alamat;

    final Color cardBg = isDisabled ? _UX.disabledBg : Colors.white;
    final Color borderColor = isDisabled
        ? const Color(0xFFE4E4EA)
        : (isSelesai ? const Color(0xFFD9F2E3) : _UX.cardBorder);
    final TextStyle titleStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 14.5,
      color: isDisabled ? _UX.disabledText : Colors.black,
    );
    final TextStyle subStyle = TextStyle(
      color: isDisabled ? _UX.disabledText : _UX.textMuted,
    );

    return Semantics(
      enabled: !isDisabled,
      label: pelanggan.nama,
      hint:
          isDisabled ? 'Terkunci karena ada kunjungan aktif' : 'Buka checklist',
      child: Tooltip(
        message: isDisabled
            ? 'Terkunci karena ada kunjungan aktif: hanya pelanggan yang aktif yang bisa dibuka'
            : (isActiveVisit ? 'Sedang dikunjungi' : ''),
        triggerMode: TooltipTriggerMode.tap,
        child: Stack(
          children: [
            Material(
              color: Colors.transparent,
              child: Ink(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(_UX.r16),
                  border: Border.all(color: borderColor),
                  boxShadow: isDisabled
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(_UX.r16),
                  onTap: onTap,
                  splashColor: isDisabled ? Colors.transparent : null,
                  highlightColor: isDisabled ? Colors.transparent : null,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Row(
                      children: [
                        // Index bubble
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: isDisabled
                              ? const Color(0xFFEDEDF1)
                              : _UX.primarySurface,
                          child: Text(
                            '$index',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDisabled
                                  ? _UX.disabledText
                                  : _UX.primaryDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Texts
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: titleStyle,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                alamat,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: subStyle,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Right pills
                        if (isDisabled)
                          const _LockPill()
                        else if (isActiveVisit)
                          const _ActivePill()
                        else
                          _StatusPill(isSelesai: isSelesai),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isSelesai;
  const _StatusPill({required this.isSelesai});

  @override
  Widget build(BuildContext context) {
    if (isSelesai) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE7F5EC),
          borderRadius: BorderRadius.circular(_UX.r999),
          border: Border.all(color: const Color(0xFFBDE5CE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check, size: 18, color: Color(0xFF2EAD54)),
            SizedBox(width: 6),
            Text('Selesai',
                style: TextStyle(
                    color: Color(0xFF2EAD54), fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _UX.primarySurface,
        borderRadius: BorderRadius.circular(_UX.r999),
        border: Border.all(color: _UX.primary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.play_arrow_rounded, size: 18, color: _UX.primaryDark),
          SizedBox(width: 6),
          Text('Mulai',
              style: TextStyle(
                  color: _UX.primaryDark, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// Pill untuk item terkunci (non-aktif)
class _LockPill extends StatelessWidget {
  const _LockPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDF1),
        borderRadius: BorderRadius.circular(_UX.r999),
        border: Border.all(color: const Color(0xFFD9D9E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.lock, size: 18, color: _UX.disabledText),
          SizedBox(width: 6),
          Text('Terkunci',
              style: TextStyle(
                  color: _UX.disabledText, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// Pill untuk item yang sedang aktif dikunjungi
class _ActivePill extends StatelessWidget {
  const _ActivePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(_UX.r999),
        border: Border.all(color: Color(0xFFFFEEA9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.lock_clock, size: 18, color: Color(0xFF8A6D3B)),
          SizedBox(width: 6),
          Text('Sedang dikunjungi',
              style: TextStyle(
                  color: Color(0xFF8A6D3B), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
