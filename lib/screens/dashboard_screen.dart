import 'package:flutter/material.dart';
import '../models/feature_model.dart';
import '../services/feature_service.dart';
import 'detail_feature_screen.dart'; // Pastikan file ini dibuat

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<FeatureItem>> _futureFeatures;

  @override
  void initState() {
    super.initState();
    _futureFeatures = FeatureService().fetchFeatures();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: FutureBuilder<List<FeatureItem>>(
        future: _futureFeatures,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Tidak ada menu fitur"));
          }

          final features = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: features.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 3 / 2,
            ),
            itemBuilder: (context, index) {
              final feature = features[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailFeatureScreen(
                        featureId: feature.id, // sekarang berupa String (UUID)
                        title: feature.nama,
                      ),
                    ),
                  );
                },
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(getIconData(feature.icon), size: 40),
                        const SizedBox(height: 10),
                        Text(
                          feature.nama,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
