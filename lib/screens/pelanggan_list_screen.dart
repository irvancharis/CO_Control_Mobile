import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../models/pelanggan_model.dart';
import '../models/sales_model.dart';
import '../services/pelanggan_service.dart';
import '../services/sales_service.dart';
import 'detail_feature_checklist_screen.dart';

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
  bool isLoading = false;
  bool isSalesLocked = false;
  String? lastNocall;
  final searchPelangganController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadSales();
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
      Sales? sales;
      try {
        sales = salesList.firstWhere(
          (s) => s.id == savedSalesId && s.idCabang == savedSalesCabang,
          orElse: () => salesList[0],
        );
      } catch (_) {
        sales = null;
      }

      setState(() {
        selectedSales = sales;
        isSalesLocked = true;
        lastNocall = savedNocall;
      });
      pelangganList = await PelangganService().fetchAllPelangganLocal();
      filteredPelangganList = List.from(pelangganList);
      setState(() {});
    }
  }

  Future<void> loadSales() async {
    setState(() => isLoading = true);
    salesList = await SalesService().fetchSales();
    setState(() => isLoading = false);
    await restoreState();
  }

  String generateNocall(Sales sales) {
    final now = DateTime.now();
    final tanggal =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
    return "W${sales.idCabang}_${sales.id}_$tanggal";
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
      await PelangganService().downloadAndSavePelanggan(lastNocall!);
      pelangganList = await PelangganService().fetchAllPelangganLocal();
      filteredPelangganList = List.from(pelangganList);
      isSalesLocked = true;
      await saveState();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pelanggan berhasil di-download')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal download: $e')));
    }
    setState(() => isLoading = false);
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

  Future<void> resetPelangganDanSales() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text(
            'Mengubah sales akan menghapus seluruh data pelanggan yang sudah di-download. Lanjutkan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Ubah Sales'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      isLoading = true;
      isSalesLocked = false;
      pelangganList = [];
      filteredPelangganList = [];
      selectedSales = null;
      lastNocall = null;
      searchPelangganController.clear();
    });
    await PelangganService().clearLocalPelanggan();
    await clearSavedState();
    setState(() => isLoading = false);
  }

  Future<void> clearSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selectedSalesId');
    await prefs.remove('selectedSalesCabang');
    await prefs.remove('lastNocall');
    await prefs.remove('isSalesLocked');
  }

  void filterPelanggan(String query) {
    if (query.isEmpty) {
      setState(() => filteredPelangganList = List.from(pelangganList));
    } else {
      setState(() {
        filteredPelangganList = pelangganList.where((p) {
          final q = query.toLowerCase();
          return p.nama.toLowerCase().contains(q) ||
              p.nocall.toLowerCase().contains(q) ||
              p.alamat.toLowerCase().contains(q);
        }).toList();
      });
    }
  }

  @override
  void dispose() {
    searchPelangganController.dispose();
    super.dispose();
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
                  child: DropdownSearch<Sales>(
                    selectedItem: selectedSales,
                    items: salesList,
                    itemAsString: (sales) =>
                        "${sales.kodeSales} - ${sales.nama}",
                    enabled: !isSalesLocked,
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                          labelText: "Cari sales...",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      // Untuk pencarian sales
                      itemBuilder: (context, sales, isSelected) => ListTile(
                        title: Text("${sales.kodeSales}"),
                        subtitle: Text(sales.nama),
                      ),
                    ),
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        labelText: 'Pilih Sales',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    onChanged: isSalesLocked
                        ? null
                        : (sales) {
                            setState(() {
                              selectedSales = sales;
                              pelangganList = [];
                              filteredPelangganList = [];
                              lastNocall = null;
                              searchPelangganController.clear();
                            });
                          },
                    filterFn: (sales, filter) {
                      final q = filter.toLowerCase();
                      return sales.nama.toLowerCase().contains(q) ||
                          sales.kodeSales.toLowerCase().contains(q) ||
                          sales.idCabang.toLowerCase().contains(q);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                isSalesLocked
                    ? ElevatedButton.icon(
                        onPressed: isLoading ? null : resetPelangganDanSales,
                        icon: const Icon(Icons.lock_reset),
                        label: const Text('Ubah Sales'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: isLoading || selectedSales == null
                            ? null
                            : loadAndDownloadPelanggan,
                        icon: const Icon(Icons.download),
                        label: const Text('Download'),
                      ),
              ],
            ),
          ),
          if (isSalesLocked && lastNocall != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Jumlah Pelanggan: ${filteredPelangganList.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('NOCALL: $lastNocall',
                      style: const TextStyle(color: Colors.blueGrey)),
                ],
              ),
            ),
          if (isSalesLocked)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: TextField(
                controller: searchPelangganController,
                decoration: InputDecoration(
                  labelText: 'Cari pelanggan (nama, alamat)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                  suffixIcon: searchPelangganController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            searchPelangganController.clear();
                            filterPelanggan('');
                          },
                        )
                      : null,
                ),
                onChanged: filterPelanggan,
              ),
            ),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: filteredPelangganList.isEmpty
                  ? const Center(child: Text('Tidak ada pelanggan.'))
                  : ListView.builder(
                      itemCount: filteredPelangganList.length,
                      itemBuilder: (context, index) {
                        final pelanggan = filteredPelangganList[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: ListTile(
                            leading: const Icon(Icons.person,
                                color: Colors.blueAccent),
                            title: Text(
                              pelanggan.nama,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '• ${pelanggan.alamat}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      DetailFeatureChecklistScreen(
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
    );
  }
}
