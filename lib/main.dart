import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

// --- Import screen baru dan config ---
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/pelanggan_list_screen.dart';
import 'screens/ip_setup_screen.dart';
import 'providers/sales_provider.dart';
import 'utils/api_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await initializeDateFormatting('id_ID', null);

  // 1. Ambil Data dari Memory
  final savedIp = prefs.getString('server_ip');
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  // 2. Tentukan Route Awal
  String initialRoute;

  if (savedIp == null || savedIp.isEmpty) {
    // Jika IP belum ada, paksa ke Setup IP
    initialRoute = '/ip-setup';
  } else {
    // Jika IP ada, simpan ke ApiConfig agar siap dipakai
    ApiConfig.baseUrl = savedIp;

    // Baru cek status login
    initialRoute = isLoggedIn ? '/dashboard' : '/login';
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SalesProvider()),
      ],
      child: ControlSalesApp(initialRoute: initialRoute),
    ),
  );
}

class ControlSalesApp extends StatelessWidget {
  final String initialRoute; // Ubah dari bool isLoggedIn menjadi String route

  const ControlSalesApp({Key? key, required this.initialRoute})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control Sales App',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: initialRoute, // Gunakan route hasil logika di main()
      routes: {
        '/ip-setup': (context) => const IpSetupScreen(), // Route baru
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/pelanggan-list': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map?;
          return PelangganListScreen(
            featureId: args?['featureId'] ?? '',
            title: args?['title'] ?? '',
            featureType: args?['featureType'] ?? '',
          );
        },
      },
    );
  }
}
