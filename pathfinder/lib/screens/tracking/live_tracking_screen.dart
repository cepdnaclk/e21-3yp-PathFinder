import 'dart:math';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_launcher/map_launcher.dart';

import '../alerts/alert_history_screen.dart';
import '../home/home_screen.dart';
import '../home/settings_screen.dart';
import 'camera_feed_screen.dart';

class _TrackingColors {
  static const background = Color(0xFF2B3749);
  static const surface = Color(0xFF101925);
  static const blue = Color(0xFF2563EB);
  static const lightBlue = Color(0xFF60A5FA);
  static const green = Color(0xFF22C55E);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFF43F5E);
  static const text = Color(0xFFF8FAFC);
  static const muted = Color(0xFF94A3B8);
}

class LiveTrackingScreen extends StatefulWidget {
  final String deviceId;

  const LiveTrackingScreen({super.key, required this.deviceId});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final MapController _mapController = MapController();
  final bool _followUser = true;

  double _currentLat = 0;
  double _currentLng = 0;
  String _userName = 'Unknown';
  bool _online = false;
  int _batteryLevel = 0;
  bool _sosActive = false;

  Future<void> _openInMaps() async {
    final availableMaps = await MapLauncher.installedMaps;
    if (!mounted) return;

    if (availableMaps.isEmpty) {
      _showMessage('No map applications found');
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
            color: _TrackingColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: _TrackingColors.muted.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 18),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Open Directions With',
                  style: TextStyle(
                    color: _TrackingColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...availableMaps.map((map) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TrackingGlassCard(
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await map.showMarker(
                        coords: Coords(_currentLat, _currentLng),
                        title: _userName,
                        description: 'PathFinder live location',
                      );
                    },
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: SvgPicture.asset(map.icon),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            map.mapName,
                            style: const TextStyle(
                              color: _TrackingColors.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: _TrackingColors.muted,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _TrackingColors.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _updateFromFirestore(Map<String, dynamic> data) {
    _currentLat = (data['gpsLat'] ?? 0).toDouble();
    _currentLng = (data['gpsLng'] ?? 0).toDouble();
    _userName = (data['userName'] ?? 'Unknown').toString();
    _online = data['online'] ?? false;
    _batteryLevel = (data['batteryLevel'] ?? 0).toInt();
    _sosActive = data['sosActive'] ?? false;

    if (_followUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(
          LatLng(_currentLat, _currentLng),
          _mapController.camera.zoom,
        );
      });
    }
  }

  void _openScreen(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => screen,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _selectBottomTab(int index) {
    switch (index) {
      case 0:
        _openScreen(HomeScreen(deviceId: widget.deviceId));
      case 2:
        _openScreen(CameraFeedScreen(deviceId: widget.deviceId));
      case 3:
        _openScreen(AlertHistoryScreen(deviceId: widget.deviceId));
      case 4:
        _openScreen(SettingsScreen(deviceId: widget.deviceId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('devices')
          .doc(widget.deviceId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _TrackingError(message: '${snapshot.error}');
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _TrackingLoading(onSelected: _selectBottomTab);
        }

        _updateFromFirestore(snapshot.data!.data()!);
        final currentLocation = LatLng(_currentLat, _currentLng);

        return Scaffold(
          backgroundColor: _TrackingColors.background,
          extendBody: true,
          body: Stack(
            children: [
              const Positioned.fill(child: _TrackingBackground()),
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _buildHeader(currentLocation),
                    const SizedBox(height: 14),
                    Expanded(child: _buildMap(currentLocation)),
                    const SizedBox(height: 12),
                    _buildActivityPanel(),
                    const SizedBox(height: 102),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: _TrackingBottomBar(
            currentIndex: 1,
            onSelected: _selectBottomTab,
          ),
        );
      },
    );
  }

  Widget _buildHeader(LatLng currentLocation) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Row(
        children: [
          _TrackingSquareButton(
            icon: Icons.arrow_back_rounded,
            color: const Color(0xFF475569),
            onTap: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Column(
              children: [
                Text(
                  'PATHFINDER',
                  style: TextStyle(
                    color: _TrackingColors.lightBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Live Tracking',
                  style: TextStyle(
                    color: _TrackingColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          _TrackingSquareButton(
            icon: Icons.my_location_rounded,
            color: _TrackingColors.blue,
            onTap: () => _mapController.move(currentLocation, 16),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(LatLng currentLocation) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: currentLocation,
                  initialZoom: 16,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.pathfinder',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: currentLocation,
                        width: 82,
                        height: 82,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: _TrackingColors.blue.withValues(
                                  alpha: .2,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: _TrackingColors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: _buildLocationOverlay(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationOverlay() {
    return _TrackingGlassCard(
      onTap: _openInMaps,
      padding: const EdgeInsets.all(12),
      borderRadius: 18,
      dark: true,
      child: Row(
        children: [
          const _TrackingSquareIcon(
            icon: Icons.location_on_rounded,
            color: _TrackingColors.blue,
            size: 42,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live Location',
                  style: TextStyle(
                    color: _TrackingColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_currentLat.toStringAsFixed(5)}, '
                  '${_currentLng.toStringAsFixed(5)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _TrackingColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.navigation_rounded,
            color: _TrackingColors.lightBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityPanel() {
    final batteryColor = _batteryLevel <= 20
        ? _TrackingColors.red
        : _batteryLevel <= 50
        ? _TrackingColors.amber
        : _TrackingColors.green;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: _TrackingGlassCard(
        borderRadius: 22,
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Expanded(
              child: _TrackingMetric(
                icon: Icons.sensors_rounded,
                color: _online ? _TrackingColors.green : _TrackingColors.red,
                label: 'Device',
                value: _online ? 'Active' : 'Offline',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TrackingMetric(
                icon: Icons.battery_5_bar_rounded,
                color: batteryColor,
                label: 'Battery',
                value: '${_batteryLevel.clamp(0, 100)}%',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TrackingMetric(
                icon: _sosActive ? Icons.sos_rounded : Icons.shield_rounded,
                color: _sosActive ? _TrackingColors.red : _TrackingColors.green,
                label: 'SOS',
                value: _sosActive ? 'Active' : 'Safe',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingMetric extends StatelessWidget {
  const _TrackingMetric({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TrackingSquareIcon(icon: icon, color: color, size: 36),
        const SizedBox(height: 7),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _TrackingColors.text,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: _TrackingColors.muted, fontSize: 8),
        ),
      ],
    );
  }
}

class _TrackingGlassCard extends StatelessWidget {
  const _TrackingGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.onTap,
    this.dark = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [
                      const Color(0xFF1E293B).withValues(alpha: .94),
                      const Color(0xFF111C2B).withValues(alpha: .96),
                      const Color(0xFF08111E).withValues(alpha: .98),
                    ]
                  : [
                      const Color(0xFFD7E0EB).withValues(alpha: .18),
                      const Color(0xFF7088AD).withValues(alpha: .15),
                      const Color(0xFF16243A).withValues(alpha: .76),
                    ],
              stops: const [0, .42, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .3),
                blurRadius: 20,
                offset: const Offset(0, 9),
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

class _TrackingSquareIcon extends StatelessWidget {
  const _TrackingSquareIcon({
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
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.white, size: size * .48),
    );
  }
}

class _TrackingSquareButton extends StatelessWidget {
  const _TrackingSquareButton({
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

class _TrackingBottomBar extends StatelessWidget {
  const _TrackingBottomBar({
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const _items = <(IconData, String)>[
    (Icons.home_outlined, 'Home'),
    (Icons.location_on_outlined, 'Tracking'),
    (Icons.videocam_outlined, 'Live Feed'),
    (Icons.notifications_none_rounded, 'Alerts'),
    (Icons.settings_outlined, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            8,
            9,
            8,
            max(10, MediaQuery.paddingOf(context).bottom),
          ),
          decoration: BoxDecoration(
            color: const Color(0xED0A111C),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: .09)),
            ),
          ),
          child: Row(
            children: List.generate(_items.length, (index) {
              final selected = index == currentIndex;
              final item = _items[index];
              return Expanded(
                child: InkWell(
                  onTap: () => onSelected(index),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 4,
                    ),
                    child: SizedBox(
                      height: 56,
                      child: Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            top: 6,
                            child: Container(
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.transparent
                                    : const Color(0xFF050A12),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: selected
                                    ? null
                                    : const [
                                        BoxShadow(
                                          color: Colors.black,
                                          blurRadius: 7,
                                          offset: Offset(0, -2),
                                        ),
                                      ],
                              ),
                            ),
                          ),
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            left: selected ? 2 : 5,
                            right: selected ? 2 : 5,
                            top: selected ? -3 : 8,
                            bottom: selected ? 8 : 3,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              decoration: BoxDecoration(
                                gradient: selected
                                    ? const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF60A5FA),
                                          Color(0xFF2563EB),
                                        ],
                                      )
                                    : const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF101A29),
                                          Color(0xFF080F1A),
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(13),
                                boxShadow: null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    item.$1,
                                    size: 20,
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFF66758A),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.$2,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFF66758A),
                                      fontSize: 8,
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TrackingBackground extends StatelessWidget {
  const _TrackingBackground();

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
            clipper: _TrackingBlueClipper(),
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

class _TrackingBlueClipper extends CustomClipper<ui.Path> {
  @override
  ui.Path getClip(Size size) {
    return ui.Path()
      ..moveTo(size.width * .62, 0)
      ..lineTo(size.width * .36, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<ui.Path> oldClipper) => false;
}

class _TrackingLoading extends StatelessWidget {
  const _TrackingLoading({required this.onSelected});

  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _TrackingColors.background,
      extendBody: true,
      body: const Stack(
        children: [
          Positioned.fill(child: _TrackingBackground()),
          Center(
            child: CircularProgressIndicator(color: _TrackingColors.lightBlue),
          ),
        ],
      ),
      bottomNavigationBar: _TrackingBottomBar(
        currentIndex: 1,
        onSelected: onSelected,
      ),
    );
  }
}

class _TrackingError extends StatelessWidget {
  const _TrackingError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _TrackingColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Unable to load tracking\n$message',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _TrackingColors.text),
          ),
        ),
      ),
    );
  }
}
