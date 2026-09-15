import 'dart:ui';

import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';
import '../home/home_screen.dart';

class _LinkColors {
  static const background = Color(0xFF2B3749);
  static const blue = Color(0xFF2563EB);
  static const lightBlue = Color(0xFF60A5FA);
  static const red = Color(0xFFF43F5E);
  static const text = Color(0xFFF8FAFC);
  static const muted = Color(0xFF94A3B8);
}

class LinkDeviceScreen extends StatefulWidget {
  const LinkDeviceScreen({super.key});

  @override
  State<LinkDeviceScreen> createState() => _LinkDeviceScreenState();
}

class _LinkDeviceScreenState extends State<LinkDeviceScreen> {
  final TextEditingController _deviceIdController = TextEditingController();

  bool _loading = false;
  String? _error;

  Future<void> _linkDevice() async {
    final deviceId = _deviceIdController.text.trim();
    if (deviceId.isEmpty) {
      setState(() => _error = 'Please enter a device ID');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirestoreService().linkCaretakerToDevice(deviceId);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(builder: (_) => HomeScreen(deviceId: deviceId)),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LinkColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _LinkBackground()),
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
                              'assets/images/pathfinder_device.png',
                              height: 180,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, _, _) {
                                return const _LinkSquareIcon(
                                  icon: Icons.watch_rounded,
                                  color: _LinkColors.blue,
                                  size: 82,
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'PATHFINDER',
                              style: TextStyle(
                                color: _LinkColors.lightBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.6,
                              ),
                            ),
                            const SizedBox(height: 7),
                            const Text(
                              'Link Your Device',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _LinkColors.text,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Connect a PathFinder device to begin live monitoring.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _LinkColors.muted,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 26),
                            _LinkGlassCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      _LinkSquareIcon(
                                        icon: Icons.add_link_rounded,
                                        color: _LinkColors.blue,
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Device Identification',
                                              style: TextStyle(
                                                color: _LinkColors.text,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            SizedBox(height: 3),
                                            Text(
                                              'Enter the ID shown on your device',
                                              style: TextStyle(
                                                color: _LinkColors.muted,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  TextField(
                                    controller: _deviceIdController,
                                    enabled: !_loading,
                                    textInputAction: TextInputAction.done,
                                    autocorrect: false,
                                    cursorColor: _LinkColors.lightBlue,
                                    style: const TextStyle(
                                      color: _LinkColors.text,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    onSubmitted: (_) {
                                      if (!_loading) _linkDevice();
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Device ID',
                                      hintText: 'e.g. pathfinder_001',
                                      labelStyle: const TextStyle(
                                        color: _LinkColors.muted,
                                      ),
                                      hintStyle: TextStyle(
                                        color: _LinkColors.muted.withValues(
                                          alpha: .6,
                                        ),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.qr_code_rounded,
                                        color: _LinkColors.lightBlue,
                                      ),
                                      filled: true,
                                      fillColor: Colors.black.withValues(
                                        alpha: .2,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: const BorderSide(
                                          color: _LinkColors.lightBlue,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_error != null) ...[
                                    const SizedBox(height: 13),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _LinkColors.red.withValues(
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
                                            color: _LinkColors.red,
                                            size: 19,
                                          ),
                                          const SizedBox(width: 9),
                                          Expanded(
                                            child: Text(
                                              _error!,
                                              style: const TextStyle(
                                                color: _LinkColors.text,
                                                fontSize: 11,
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: _loading ? null : _linkDevice,
                                      icon: _loading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.4,
                                              ),
                                            )
                                          : const Icon(Icons.link_rounded),
                                      label: Text(
                                        _loading
                                            ? 'Linking Device...'
                                            : 'Link Device',
                                      ),
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size.fromHeight(56),
                                        backgroundColor: _LinkColors.blue,
                                        disabledBackgroundColor: _LinkColors
                                            .blue
                                            .withValues(alpha: .55),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 17),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: _LinkColors.muted,
                                  size: 15,
                                ),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Device IDs are case-sensitive',
                                    style: TextStyle(
                                      color: _LinkColors.muted,
                                      fontSize: 10,
                                    ),
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

class _LinkGlassCard extends StatelessWidget {
  const _LinkGlassCard({
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

class _LinkSquareIcon extends StatelessWidget {
  const _LinkSquareIcon({
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

class _LinkBackground extends StatelessWidget {
  const _LinkBackground();

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
            clipper: _LinkBlueClipper(),
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

class _LinkBlueClipper extends CustomClipper<Path> {
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
