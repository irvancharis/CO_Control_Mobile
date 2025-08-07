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
import 'dart:convert';

class PelangganListScreen extends StatefulWidget {
  final String featureId;
  final String title;

  const PelangganListScreen({
    Key? key,
    required this.featureId,
    required this.title,
  }) : super(key: key);

  @override
  State<PelangganListScreen> createState() => _PelangganListScreenState();
}

class _PelangganListScreenState extends State<PelangganListScreen> {
  List<Sales> salesList = [];
  Sales? selectedSales;
  List<Pelanggan> pelangganList = [];
  List<Pelanggan> filteredPelangganList = [];
  Map<String, bool> visitStatusMap = {};
  bool isLoading = false;
  bool isSalesLocked = false;
  String? lastNocall;
  final searchPelangganController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadSales();
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

  Future<void> saveState() async {
    final prefs = await SharedPreferences.getInstance();
    if (selectedSales != null) {
      await prefs.setString('selectedSalesId', selectedSales!.id);
      await prefs.setString('selectedSalesCabang', selectedSales!.idCabang);
    }
    await prefs.setString('lastNocall', lastNocall ?? '');
    await prefs.setBool('isSalesLocked', isSalesLocked);
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

      // Bersihkan database dan shared preferences
      await DatabaseHelper.instance.clearAllTables();

      final prefs = await SharedPreferences.getInstance();
      await prefs
          .remove('isSalesLocked'); // atau prefs.clear() jika ingin hapus semua
      await prefs.remove('selectedSales');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Semua data berhasil dikirim')),
        );

        // Navigasi kembali ke Dashboard dan hapus semua stack halaman sebelumnya
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

  Future<void> loadAndDownloadPelanggan() async {
    if (selectedSales == null) return;

    setState(() {
      isLoading = true;
      pelangganList = [];
      filteredPelangganList = [];
      lastNocall = generateNocall(selectedSales!);
    });

    try {
      // 1. Download pelanggan dari server
      await PelangganService().downloadAndSavePelanggan(
        lastNocall!,
        widget.featureId,
      );

      // 2. Ambil dari lokal
      final downloaded = await PelangganService()
          .fetchAllPelangganLocal(fitur: widget.featureId);

      await loadVisitStatus(downloaded);

      // 3. Kalau kosong → refresh halaman penuh
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

          // ✅ Ganti "NamaHalaman" dengan nama class halaman ini
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PelangganListScreen(
                featureId: widget.featureId,
                title: 'Pelanggan',
              ),
            ),
          );
        }
        return; // ⛔ Jangan lanjut karena halaman sudah di-replace
      }

      // 4. Jika ada pelanggan, update state
      setState(() {
        pelangganList = downloaded;
        filteredPelangganList = List.from(downloaded);
        isSalesLocked = true;
        isLoading = false;
      });

      // 5. Simpan state
      await saveState();

      // 6. Tampilkan notifikasi
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

  String generateNocall(Sales sales) {
    final now = DateTime.now();
    final tanggal =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
    return "W${sales.idCabang}_${sales.id}_$tanggal";
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
                // Bagian Sales: label jika terkunci, dropdown jika belum
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
                              pelangganList = [];
                              filteredPelangganList = [];
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

                // Tombol hanya muncul jika belum terkunci
                if (!isSalesLocked && !isLoading && selectedSales != null)
                  ElevatedButton.icon(
                    onPressed: () async {
                      await loadAndDownloadPelanggan(); // Panggil fungsi download
                      setState(() {
                        isSalesLocked = true; // Kunci tampilan setelah download
                      });
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
                              final isSelesai =
                                  visitStatusMap[pelanggan.id] ?? false;

                              if (isSelesai) {
                                final lanjut = await showDialog<bool>(
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
                                );

                                if (lanjut != true) return;
                              }

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
