import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  late final AnimationController _gradCtrl;

  bool _loading = false;
  bool _obscure = true;

  // Palet
  static const Color _bgTop = Color(0xFF4B2E83);
  static const Color _bgBottom = Color(0xFF2C1C4A);

  @override
  void initState() {
    super.initState();
    _gradCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(); // muter terus buat animasi gradient
  }

  @override
  void dispose() {
    _gradCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // BG gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_bgTop, _bgBottom],
              ),
            ),
          ),
          // Blob dekoratif
          const Positioned(
            top: -120,
            left: -70,
            child: _Blob(width: 280, height: 280, opacity: .08),
          ),
          const Positioned(
            top: 40,
            right: -90,
            child: _Blob(width: 240, height: 240, opacity: .05),
          ),
          // Konten
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 226),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            _PillField(
                              controller: _usernameCtrl,
                              hint: 'Username',
                              icon: Icons.alternate_email_rounded,
                              obscure: false,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Masukkan Username'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            _PillField(
                              controller: _passwordCtrl,
                              hint: 'Password',
                              icon: Icons.lock_rounded,
                              obscure: _obscure,
                              onToggleObscure: () =>
                                  setState(() => _obscure = !_obscure),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Masukkan password'
                                  : null,
                            ),
                            const SizedBox(height: 22),

                            // Tombol dengan animasi gradient
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _submit,
                                style: ButtonStyle(
                                  elevation: const MaterialStatePropertyAll(0),
                                  shape: MaterialStatePropertyAll(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  padding: const MaterialStatePropertyAll(
                                      EdgeInsets.zero),
                                  backgroundColor:
                                      const MaterialStatePropertyAll(
                                          Colors.transparent),
                                ),
                                child: AnimatedBuilder(
                                  animation: _gradCtrl,
                                  builder: (context, _) {
                                    return Ink(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: const [
                                            Color(0xFF7C4DFF), // ungu
                                            Color(0xFF895BFF),
                                            Color(0xFF7C4DFF),
                                          ],
                                          // Rotasi pelan supaya terlihat hidup
                                          transform: GradientRotation(
                                            _gradCtrl.value * 2 * math.pi,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Center(
                                        child: _loading
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2.2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(Colors.white),
                                                ),
                                              )
                                            : const Text(
                                                'Log in',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                              ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final success = await AuthService()
        .login(_usernameCtrl.text.trim(), _passwordCtrl.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);

    if (success) {
      final prefs = await SharedPreferences.getInstance();
      // ignore: avoid_print
      print("✅ Login sukses. ID SPV: ${prefs.getString('user_id')}");

      // Transisi Fade + Slide ke Dashboard
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => const DashboardScreen(),
          transitionsBuilder: (_, anim, __, child) {
            final offsetTween =
                Tween<Offset>(begin: const Offset(0, .08), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.easeOutCubic));
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: anim,
                curve: Curves.easeOutCubic,
              ),
              child: SlideTransition(
                  position: anim.drive(offsetTween), child: child),
            );
          },
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login gagal, periksa kembali')),
      );
    }
  }
}

/// ========= Widgets Kecil =========

class _PillField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final String? Function(String?)? validator;
  final VoidCallback? onToggleObscure;

  const _PillField({
    Key? key,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.obscure,
    this.validator,
    this.onToggleObscure,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const pillFill = Color(0xFF1E1336);
    const pillBorder = Color(0x331A0F33);

    return Container(
      decoration: BoxDecoration(
        color: pillFill,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: pillBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        validator: validator,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(icon, color: Colors.white54),
          suffixIcon: onToggleObscure == null
              ? null
              : IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: Colors.white54,
                  ),
                  onPressed: onToggleObscure,
                ),
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double width;
  final double height;
  final double opacity;

  const _Blob({
    Key? key,
    required this.width,
    required this.height,
    required this.opacity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.4,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(opacity),
          borderRadius: BorderRadius.circular(width * 0.45),
        ),
      ),
    );
  }
}
