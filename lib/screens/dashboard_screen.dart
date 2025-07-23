import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'join_call_screen.dart';
import 'control_call_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<String?> _usernameFuture;

  @override
  void initState() {
    super.initState();
    _usernameFuture = _loadUsername();
  }

  Future<String?> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username') ?? 'User';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().logout();
              Navigator.of(context).pushReplacementNamed('/');
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _buildActionButton(
                    context,
                    label: 'JOIN CALL',
                    icon: Icons.video_call,
                    color: theme.primaryColor,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const JoinCallScreen()),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildActionButton(
                    context,
                    label: 'CONTROL CALL',
                    icon: Icons.control_camera,
                    color: Colors.green.shade600,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ControlCallScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      elevation: 8,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 30, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
