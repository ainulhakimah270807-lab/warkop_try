import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/app_session.dart';
import '../theme/stitch_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    final success = AppSession.instance.login(
      _usernameController.text,
      _passwordController.text,
    );
    if (!success) {
      setState(() => _error = 'Username atau password tidak valid.');
    }
  }

  void _forgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hubungi Owner untuk mengatur ulang sandi.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchTheme.backgroundLight,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-.7, -.8),
                  radius: 1.4,
                  colors: [
                    StitchTheme.primaryGreen.withValues(alpha: .10),
                    StitchTheme.backgroundLight,
                    const Color(0xFFE9F0FA),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 410),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 4,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              StitchTheme.primaryGreen,
                              Color(0xFF77D8C0),
                              Color(0xFFBBD5FF),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: StitchTheme.sidebar,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.point_of_sale_rounded,
                                    color: StitchTheme.primaryGreen,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'POSHub',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      'ENTERPRISE',
                                      style: TextStyle(
                                        color: StitchTheme.primaryGreen,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                _StatusTag(
                                  label: ApiService.isSupabaseConfigured
                                      ? 'Cloud API'
                                      : 'Mode Lokal',
                                  active: ApiService.isSupabaseConfigured,
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                            const Center(
                              child: Icon(
                                Icons.point_of_sale_rounded,
                                color: StitchTheme.sidebar,
                                size: 44,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Center(
                              child: Text(
                                'Masuk ke Sistem POS',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                  color: StitchTheme.textDark,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Center(
                              child: Text(
                                'Sistem POS & Manajemen Karyawan Terpadu',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: StitchTheme.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 26),
                            TextField(
                              key: const ValueKey('login-username'),
                              controller: _usernameController,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => setState(() => _error = null),
                              decoration: const InputDecoration(
                                labelText: 'Email / ID Karyawan',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              key: const ValueKey('login-password'),
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              onChanged: (_) => setState(() => _error = null),
                              onSubmitted: (_) => _login(),
                              decoration: InputDecoration(
                                labelText: 'Kata Sandi',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Tampilkan sandi'
                                      : 'Sembunyikan sandi',
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _forgotPassword,
                                child: const Text('Lupa kata sandi?'),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: _login,
                                icon: const Icon(Icons.login_rounded, size: 18),
                                label: const Text('Masuk ke Terminal'),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Center(
                              child: Text(
                                'Demo: owner, raka, dimas, atau alisa · sandi 123456',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: StitchTheme.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.verified_user_outlined, size: 13),
                    SizedBox(width: 6),
                    Text(
                      'Enkripsi SSL/TLS 256-bit Terverifikasi',
                      style: TextStyle(fontSize: 10),
                    ),
                    Spacer(),
                    Text('POSHub Core v2.4', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: active ? const Color(0xFFE6F8F2) : const Color(0xFFF0F2F3),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 6,
            color: active ? StitchTheme.primaryGreen : StitchTheme.textMuted,
          ),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    ),
  );
}
