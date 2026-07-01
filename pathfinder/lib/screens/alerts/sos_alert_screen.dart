import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/alert_model.dart';
import '../../services/firestore_service.dart';

class _SosColors {
  static const background = Color(0xFF050A12);
  static const surface = Color(0xFF101925);
  static const blue = Color(0xFF2563EB);
  static const lightBlue = Color(0xFF60A5FA);
  static const green = Color(0xFF22C55E);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFF43F5E);
  static const text = Color(0xFFF8FAFC);
  static const muted = Color(0xFF94A3B8);
}

class SosAlertScreen extends StatefulWidget {
  final String deviceId;
  final String userName;
  final double lat;
  final double lng;
  final int batteryLevel;
  final bool sosActive;

  const SosAlertScreen({
    super.key,
    required this.deviceId,
    required this.userName,
    required this.lat,
    required this.lng,
    required this.batteryLevel,
    required this.sosActive,
  });

  @override
  State<SosAlertScreen> createState() => _SosAlertScreenState();
}

class _SosAlertScreenState extends State<SosAlertScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();

  late final Future<AlertModel?> _alertFuture;
  late final AnimationController _pulseController;

  bool _busy = false;
  String _userContactNumber = '';
  String _emergencyContactNumber = '';

  @override
  void initState() {
    super.initState();
    _alertFuture = _getCurrentAlert();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.sosActive) {
      _pulseController.repeat(reverse: true);
    }
    _loadContactNumbers();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadContactNumbers() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final caretakerData = await _firestoreService.getCaretakerData(user.uid);
      if (!mounted || caretakerData == null) return;

      setState(() {
        _userContactNumber = (caretakerData['userContactNumber'] ?? '')
            .toString()
            .trim();
        _emergencyContactNumber =
            (caretakerData['emergencyContactNumber'] ?? '').toString().trim();
      });
    } catch (_) {
      // Call actions show a useful fallback when contact data is unavailable.
    }
  }

  Future<AlertModel?> _getCurrentAlert() {
    return _firestoreService.getLatestActiveSosAlert(widget.deviceId);
  }

  Future<void> _openInMaps() async {
    final maps = await MapLauncher.installedMaps;
    if (maps.isEmpty) {
      if (mounted) _showMessage('No map apps found');
      return;
    }

    await maps.first.showMarker(
      coords: Coords(widget.lat, widget.lng),
      title: widget.userName,
      description: widget.sosActive
          ? 'Emergency location'
          : 'Last known location',
    );
  }

  Future<void> _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      _showMessage('Unable to open the phone app');
    }
  }

  Future<void> _callEmergencyContact() async {
    if (_emergencyContactNumber.isEmpty) {
      _showMessage('No emergency contact number set. Add it in Settings.');
      return;
    }
    await _callNumber(_emergencyContactNumber);
  }

  Future<void> _showCallOptions() async {
    if (_userContactNumber.isEmpty) {
      _showMessage('No user contact number set. Add it in Settings.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.paddingOf(sheetContext).bottom,
          ),
          decoration: const BoxDecoration(
            color: _SosColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: _SosColors.muted.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  _SosSquareIcon(
                    icon: Icons.phone_rounded,
                    color: _SosColors.blue,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Call Tracked User',
                    style: TextStyle(
                      color: _SosColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SosGlassCard(
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _callNumber(_userContactNumber);
                },
                child: Row(
                  children: [
                    const Icon(
                      Icons.phone_in_talk_rounded,
                      color: _SosColors.lightBlue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'User Contact',
                            style: TextStyle(
                              color: _SosColors.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _userContactNumber,
                            style: const TextStyle(color: _SosColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _SosColors.muted,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _turnOffSos() async {
    setState(() => _busy = true);
    try {
      await _firestoreService.clearSosState(widget.deviceId);
      if (!mounted) return;
      _showMessage('SOS deactivated');
      Navigator.pop(context);
    } catch (error) {
      if (mounted) _showMessage('Failed to deactivate SOS: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _SosColors.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'acknowledged':
        return _SosColors.amber;
      case 'resolved':
        return _SosColors.green;
      case 'active':
      default:
        return _SosColors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _SosColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _SosLayeredBackground()),
          SafeArea(
            child: FutureBuilder<AlertModel?>(
              future: _alertFuture,
              builder: (context, snapshot) {
                final alert = snapshot.data;
                final currentStatus =
                    alert?.status ?? (widget.sosActive ? 'active' : 'resolved');
                final statusColor = _statusColor(currentStatus);

                return Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          18,
                          16,
                          18,
                          18 + MediaQuery.paddingOf(context).bottom,
                        ),
                        child: Column(
                          children: [
                            _buildEmergencyHero(currentStatus, statusColor),
                            const SizedBox(height: 14),
                            _buildLocationCard(),
                            const SizedBox(height: 24),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Emergency Actions',
                                style: TextStyle(
                                  color: _SosColors.text,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildCallActions(),
                            const SizedBox(height: 14),
                            _buildPrimaryActions(),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: CircularProgressIndicator(color: _SosColors.lightBlue),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Row(
        children: [
          _SosSquareButton(
            icon: Icons.arrow_back_rounded,
            color: const Color(0xFF334155),
            onTap: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Column(
              children: [
                Text(
                  'PATHFINDER',
                  style: TextStyle(
                    color: _SosColors.lightBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'SOS Status',
                  style: TextStyle(
                    color: _SosColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          _SosSquareButton(
            icon: Icons.map_outlined,
            color: _SosColors.blue,
            onTap: _openInMaps,
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyHero(String status, Color statusColor) {
    final mainColor = widget.sosActive ? _SosColors.red : _SosColors.green;
    final heading = widget.sosActive ? 'Emergency Alert' : 'Emergency Inactive';

    Widget hero(double pulse) {
      return Opacity(
        opacity: widget.sosActive ? .84 + (pulse * .16) : 1,
        child: SizedBox(
          width: double.infinity,
          child: _SosGlassCard(
            tintColor: mainColor,
            glowColor: widget.sosActive ? mainColor : null,
            glowStrength: .14 + (pulse * .36),
            borderRadius: 26,
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                _SosSquareIcon(
                  icon: widget.sosActive
                      ? Icons.sos_rounded
                      : Icons.shield_rounded,
                  color: mainColor,
                  size: 58,
                ),
                const SizedBox(height: 14),
                Text(
                  heading,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: mainColor,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.sosActive
                      ? '${widget.userName} needs assistance.'
                      : 'No active emergency at the moment.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _SosColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!widget.sosActive) return hero(0);
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, _) => hero(_pulseController.value),
    );
  }

  Widget _buildLocationCard() {
    return _SosGlassCard(
      onTap: _busy ? null : _openInMaps,
      child: Row(
        children: [
          const _SosSquareIcon(
            icon: Icons.location_on_rounded,
            color: _SosColors.red,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.sosActive
                      ? 'Emergency Location'
                      : 'Last Known Location',
                  style: const TextStyle(
                    color: _SosColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${widget.lat.toStringAsFixed(5)}, '
                  '${widget.lng.toStringAsFixed(5)}',
                  style: const TextStyle(
                    color: _SosColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.navigation_rounded, color: _SosColors.lightBlue),
        ],
      ),
    );
  }

  Widget _buildCallActions() {
    return Row(
      children: [
        Expanded(
          child: _SosActionCard(
            icon: Icons.phone_in_talk_rounded,
            color: _SosColors.blue,
            title: 'Call User',
            subtitle: 'Saved contact',
            onTap: _busy ? null : _showCallOptions,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SosActionCard(
            icon: Icons.local_hospital_rounded,
            color: _SosColors.red,
            title: 'Emergency',
            subtitle: 'Emergency contact',
            onTap: _busy ? null : _callEmergencyContact,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ? null : _openInMaps,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Open Location in Maps'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: _SosColors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy || !widget.sosActive ? null : _turnOffSos,
            icon: const Icon(Icons.power_settings_new_rounded),
            label: const Text('Set SOS Inactive'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              foregroundColor: widget.sosActive ? _SosColors.red : Colors.white,
              disabledForegroundColor: Colors.white,
              side: BorderSide(
                color: widget.sosActive ? _SosColors.red : Colors.white,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _SosActionCard extends StatelessWidget {
  const _SosActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _SosGlassCard(
      onTap: onTap,
      tintColor: color,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SosSquareIcon(icon: icon, color: color),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: _SosColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _SosColors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _SosGlassCard extends StatelessWidget {
  const _SosGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.onTap,
    this.tintColor,
    this.glowColor,
    this.glowStrength = 0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? tintColor;
  final Color? glowColor;
  final double glowStrength;

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (tintColor ?? const Color(0xFFD7E0EB)).withValues(
                  alpha: tintColor == null ? .17 : .34,
                ),
                (tintColor ?? const Color(0xFF7088AD)).withValues(
                  alpha: tintColor == null ? .14 : .2,
                ),
                const Color(0xFF16243A).withValues(alpha: .72),
              ],
              stops: const [0, .42, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .35),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
              if (glowColor != null)
                BoxShadow(
                  color: glowColor!.withValues(alpha: glowStrength),
                  blurRadius: 20 + (glowStrength * 24),
                  spreadRadius: glowStrength * 5,
                ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(borderRadius),
      child: card,
    );
  }
}

class _SosSquareIcon extends StatelessWidget {
  const _SosSquareIcon({
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
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: Colors.white, size: size * .48),
    );
  }
}

class _SosSquareButton extends StatelessWidget {
  const _SosSquareButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _SosLayeredBackground extends StatelessWidget {
  const _SosLayeredBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: _SosColors.background),
            Positioned(
              top: -210,
              left: -210,
              child: Transform.rotate(
                angle: -.28,
                child: Container(
                  width: 410,
                  height: 980,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(80),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF9AA8BA),
                        Color(0xFF425064),
                        Color(0xFF172131),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -150,
              right: -235,
              child: Transform.rotate(
                angle: .2,
                child: Container(
                  width: 430,
                  height: 1050,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(86),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.fromARGB(255, 164, 173, 186),
                        Color.fromARGB(255, 74, 84, 100),
                        Color.fromARGB(255, 32, 39, 50),
                      ],
                      stops: [0, .46, 1],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _SosColors.background.withValues(alpha: .2),
                      _SosColors.background.withValues(alpha: .58),
                      _SosColors.background.withValues(alpha: .9),
                    ],
                    stops: const [0, .55, 1],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
