import 'dart:ui';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../home/home_screen.dart';
import 'link_device_screen.dart';

class _LoginColors {
  static const background = Color(0xFF2B3749);
  static const blue = Color(0xFF2563EB);
  static const lightBlue = Color(0xFF60A5FA);
  static const red = Color(0xFFF43F5E);
  static const text = Color(0xFFF8FAFC);
  static const muted = Color(0xFF94A3B8);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();

  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await _authService.signInWithGoogle();
      if (user == null || !mounted) return;

      final deviceId = await FirestoreService().getLinkedDeviceId(user.uid);
      if (!mounted) return;

      if (deviceId == null || deviceId.isEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(builder: (_) => const LinkDeviceScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) => HomeScreen(deviceId: deviceId),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Google sign-in failed: $error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LoginColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _LoginBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(22),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 44,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/logo.png',
                              height: 126,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, _, _) {
                                return const _LoginSquareIcon(
                                  icon: Icons.shield_rounded,
                                  color: _LoginColors.blue,
                                  size: 82,
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'PATHFINDER',
                              style: TextStyle(
                                color: _LoginColors.lightBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.6,
                              ),
                            ),
                            const SizedBox(height: 7),
                            const Text(
                              'Welcome Back',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _LoginColors.text,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Sign in to monitor and protect your loved one.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _LoginColors.muted,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 28),
                            _LoginGlassCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      _LoginSquareIcon(
                                        icon: Icons.security_rounded,
                                        color: _LoginColors.blue,
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Secure Caretaker Access',
                                              style: TextStyle(
                                                color: _LoginColors.text,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            SizedBox(height: 3),
                                            Text(
                                              'Continue using your Google account',
                                              style: TextStyle(
                                                color: _LoginColors.muted,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_error != null) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _LoginColors.red.withValues(
                                          alpha: .16,
                                        ),
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.error_outline_rounded,
                                            color: _LoginColors.red,
                                            size: 19,
                                          ),
                                          const SizedBox(width: 9),
                                          Expanded(
                                            child: Text(
                                              _error!,
                                              style: const TextStyle(
                                                color: _LoginColors.text,
                                                fontSize: 11,
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: _loading ? null : _signIn,
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size.fromHeight(56),
                                        backgroundColor: _LoginColors.blue,
                                        disabledBackgroundColor: _LoginColors
                                            .blue
                                            .withValues(alpha: .5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: _loading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                _GoogleMark(),
                                                SizedBox(width: 11),
                                                Text(
                                                  'Sign in with Google',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  color: _LoginColors.muted,
                                  size: 15,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Your account is protected by Google',
                                  style: TextStyle(
                                    color: _LoginColors.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _LoginGlassCard extends StatelessWidget {
  const _LoginGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFD7E0EB).withValues(alpha: .2),
                const Color(0xFF7088AD).withValues(alpha: .16),
                const Color(0xFF16243A).withValues(alpha: .8),
              ],
              stops: const [0, .42, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .32),
                blurRadius: 24,
                offset: const Offset(0, 11),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _LoginSquareIcon extends StatelessWidget {
  const _LoginSquareIcon({
    required this.icon,
    required this.color,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * .23),
      ),
      child: Icon(icon, color: Colors.white, size: size * .5),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromARGB(255, 24, 28, 33),
                  Color.fromARGB(255, 46, 56, 69),
                  Color(0xFF172131),
                ],
                stops: [0, .52, 1],
              ),
            ),
          ),
          ClipPath(
            clipper: _LoginBlueClipper(),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.fromARGB(255, 24, 28, 33),
                    Color.fromARGB(255, 48, 54, 65),
                    Color.fromARGB(255, 123, 131, 143),
                  ],
                  stops: [0, .5, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginBlueClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width * .62, 0)
      ..lineTo(size.width * .36, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
