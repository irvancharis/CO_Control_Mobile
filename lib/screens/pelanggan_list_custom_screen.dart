// Full updated script with required UI logic

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

class PelangganListCustomScreen extends StatefulWidget {
  final String featureId;
  final String title;

  const PelangganListCustomScreen({
    Key? key,
    required this.featureId,
    required this.title,
  }) : super(key: key);

  @override
  State<PelangganListCustomScreen> createState() =>
      _PelangganListCustomScreenState();
}

class _PelangganListCustomScreenState extends State<PelangganListCustomScreen> {
  List<Sales> salesList = [];
  Sales? selectedSales;
  List<Pelanggan> pelangganList = [];
  List<Pelanggan> filteredPelangganList = [];
  Map<String, bool> visitStatusMap = {};
  bool isLoading = false;
  bool isSalesLocked = false;
  String? lastNocall;
  DateTime selectedDate = DateTime.now();
  final searchPelangganController = TextEditingController();
  final dateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    dateController.text =
        "${selectedDate.day}-${selectedDate.month}-${selectedDate.year}";
    loadSales();
  }

  Future<void> pilihTanggal(BuildContext context) async {
    final now = DateTime.now();
    final twoWeeksAgo = now.subtract(const Duration(days: 14));

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
    salesList = await DatabaseHelper.instance.getAllSales();
    setState(() => isLoading = false);
    await restoreState();
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

      setState(() {
        selectedSales = sales;
        isSalesLocked = true;
        lastNocall = savedNocall;
        pelangganList = pelanggan;
        filteredPelangganList = List.from(pelanggan);
      });
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

  Future<void> loadVisitStatus(List<Pelanggan> pelangganList) async {
    visitStatusMap.clear();
    for (var pelanggan in pelangganList) {
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

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PelangganListCustomScreen(
                featureId: widget.featureId,
                title: 'Pelanggan',
              ),
            ),
          );
        }
        return;
      }

      setState(() {
        pelangganList = downloaded;
        filteredPelangganList = List.from(downloaded);
        isSalesLocked = true;
        isLoading = false;
      });

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

          detailMap[idDetail]!.subDetails.add(FeatureSubDetail(
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
              ));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: isSalesLocked
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 18),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${selectedSales?.kodeSales ?? ''} - ${selectedSales?.nama ?? ''}",
                            style: const TextStyle(fontSize: 16),
                          ),
                        )
                      : DropdownSearch<Sales>(
                          selectedItem: selectedSales,
                          items: salesList,
                          itemAsString: (s) => "${s.kodeSales} - ${s.nama}",
                          onChanged: (s) {
                            setState(() {
                              selectedSales = s;
                              lastNocall = null;
                              searchPelangganController.clear();
                            });
                          },
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration: const InputDecoration(
                              labelText: 'Pilih Sales',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          if (isSalesLocked || selectedSales != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: dateController,
                      readOnly: true,
                      onTap: isSalesLocked ? null : () => pilihTanggal(context),
                      decoration: const InputDecoration(
                        labelText: 'Pilih Tanggal',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!isSalesLocked &&
                      !isLoading &&
                      selectedSales != null &&
                      dateController.text.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          lastNocall = generateNocall(selectedSales!,
                              tanggal: selectedDate);
                        });
                        loadAndDownloadPelanggan();
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Download'),
                    ),
                ],
              ),
            ),
          if (isSalesLocked && lastNocall != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("JUMLAH: ${filteredPelangganList.length}",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("NOCALL: $lastNocall",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          if (isSalesLocked)
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: searchPelangganController,
                onChanged: (q) {
                  final keyword = q.toLowerCase();
                  setState(() {
                    filteredPelangganList = pelangganList.where((p) {
                      return p.nama.toLowerCase().contains(keyword) ||
                          p.alamat.toLowerCase().contains(keyword) ||
                          p.nocall.toLowerCase().contains(keyword);
                    }).toList();
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Cari pelanggan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: filteredPelangganList.isEmpty
                  ? const Center(child: Text("Tidak ada pelanggan"))
                  : ListView.builder(
                      itemCount: filteredPelangganList.length,
                      itemBuilder: (context, index) {
                        final pelanggan = filteredPelangganList[index];
                        final isSelesai = visitStatusMap[pelanggan.id] ?? false;

                        return Card(
                          color: isSelesai ? Colors.green[100] : null,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          child: ListTile(
                            title: Text(pelanggan.nama,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black,
                                    overflow: TextOverflow.ellipsis)),
                            subtitle: Text(pelanggan.alamat),
                            trailing: isSelesai
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : const Icon(Icons.chevron_right),
                            onTap: () async {
                              final lanjut = isSelesai
                                  ? await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text("Kunjungan Selesai"),
                                        content: const Text(
                                            "Pelanggan ini sudah selesai kunjungan. Apakah Anda ingin membuka kembali checklist-nya?"),
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
                                    )
                                  : true;

                              if (lanjut != true) return;

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DetailFeatureChecklistScreen(
                                    featureId: widget.featureId,
                                    title: 'Checklist',
                                    pelanggan: pelanggan,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
        ],
      ),
      bottomNavigationBar: isSalesLocked
          ? SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : submitSemuaData,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Selesai & Upload Semua'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
