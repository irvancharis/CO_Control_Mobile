import 'package:flutter/material.dart';
import '../models/feature_detail_model.dart';
import '../services/feature_detail_service.dart';
import '../services/submit_service.dart'; // Buat file ini nanti

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
  List<FeatureDetail> _details = [];

  @override
  void initState() {
    super.initState();
    _futureDetails = FeatureDetailService().fetchDetails(widget.featureId);
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

  void _handleSubmit() async {
    final selected = _details
        .expand((detail) => detail.subDetails)
        .where((sub) => sub.isChecked)
        .toList();

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada subdetail yang dipilih')),
      );
      return;
    }

    try {
      await SubmitService.submitChecklist(selected);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data berhasil dikirim')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal submit: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
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

          _details = snapshot.data!;
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: _details.length,
                  itemBuilder: (context, index) {
                    final detail = _details[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: Icon(getIconData(detail.icon)),
                          title: Text(detail.nama,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ...detail.subDetails.map((sub) {
                          return CheckboxListTile(
                            title: Text(sub.nama),
                            value: sub.isChecked,
                            onChanged: (val) {
                              setState(() {
                                sub.isChecked = val ?? false;
                              });
                            },
                          );
                        }).toList(),
                        const Divider(),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _handleSubmit,
                  icon: const Icon(Icons.check),
                  label: const Text("Submit Checklist"),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}
