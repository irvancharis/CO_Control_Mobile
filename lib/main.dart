import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/pelanggan_list_screen.dart';
import 'providers/sales_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SalesProvider()),
      ],
      child: ControlSalesApp(isLoggedIn: isLoggedIn),
    ),
  );
}

class ControlSalesApp extends StatelessWidget {
  final bool isLoggedIn;
  const ControlSalesApp({Key? key, required this.isLoggedIn}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control Sales App',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: isLoggedIn ? '/dashboard' : '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/pelanggan-list': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map?;
          return PelangganListScreen(
            featureId: args?['featureId'] ?? '',
            title: args?['title'] ?? '',
          );
        },
        // Untuk checklist screen, sebaiknya pakai push biasa (MaterialPageRoute) dari PelangganListScreen,
        // karena butuh passing object pelanggan, bukan sekedar string id.
      },
    );
  }
}
