import 'dart:math';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/device_model.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../alerts/alert_history_screen.dart';
import '../alerts/sos_alert_screen.dart';
import '../tracking/camera_feed_screen.dart';
import '../tracking/live_tracking_screen.dart';
import 'safe_zone_picker_screen.dart';
import 'settings_screen.dart';
import '../../utils/safe_zone_utils.dart';

class _HomeColors {
  static const background = Color(0xFF2B3749);
  static const surface = Color(0xFF101925);
  static const surfaceLight = Color(0xFF182333);
  static const blue = Color(0xFF2563EB);
  static const lightBlue = Color(0xFF60A5FA);
  static const cyan = Color(0xFF22D3EE);
  static const green = Color(0xFF22C55E);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFF43F5E);
  static const text = Color(0xFFF8FAFC);
  static const muted = Color(0xFF94A3B8);
  static const border = Color(0xFF263449);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.deviceId});

  final String? deviceId;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();

  Future<String>? _deviceIdFuture;
  late final AnimationController _sosPulseController;

  bool _sosScreenOpen = false;
  bool _sosAlreadyHandled = false;
  String? _lastHandledSosDeviceId;
  bool _lowBatteryHandled = false;
  bool _safeZoneHandled = false;

  @override
  void initState() {
    super.initState();
    if (widget.deviceId == null) {
      _deviceIdFuture = _getMyDeviceId();
    }
    _sosPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sosPulseController.dispose();
    super.dispose();
  }

  Future<String> _getMyDeviceId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No logged in user');

    final deviceId = await _firestoreService.getLinkedDeviceId(user.uid);
    if (deviceId == null || deviceId.isEmpty) {
      throw Exception('No linked device found');
    }
    return deviceId;
  }

  double _distanceInMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  void _runDeviceChecks(DeviceModel device) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkAndOpenSos(device);
      _checkLowBattery(device);
      _checkSafeZone(device);
    });
  }

  void _checkAndOpenSos(DeviceModel device) {
    if (!device.sosActive) {
      NotificationService.cancelSosNotification();
      _sosScreenOpen = false;
      _sosAlreadyHandled = false;
      _lastHandledSosDeviceId = null;
      return;
    }

    if (_sosScreenOpen ||
        (_sosAlreadyHandled && _lastHandledSosDeviceId == device.id)) {
      return;
    }

    _sosScreenOpen = true;
    _sosAlreadyHandled = true;
    _lastHandledSosDeviceId = device.id;

    Future<void>(() async {
      try {
        await _firestoreService.createSosAlert(
          deviceId: device.id,
          userName: device.userName,
          lat: device.gpsLat,
          lng: device.gpsLng,
          batteryLevel: device.batteryLevel,
        );
        await NotificationService.showSosNotification(
          title: 'SOS Alert',
          body: '${device.userName} has triggered an emergency alert.',
        );
        if (!mounted) return;

        final shouldOpen = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: _HomeColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: _HomeColors.red),
            ),
            title: const Row(
              children: [
                Icon(Icons.sos_rounded, color: _HomeColors.red),
                SizedBox(width: 10),
                Text('SOS Alert', style: TextStyle(color: _HomeColors.text)),
              ],
            ),
            content: Text(
              '${device.userName} has triggered an emergency alert.',
              style: const TextStyle(color: _HomeColors.muted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(backgroundColor: _HomeColors.red),
                child: const Text('Open'),
              ),
            ],
          ),
        );

        if (shouldOpen == true && mounted) {
          await _openSos(device);
        }
      } catch (error) {
        debugPrint('SOS handling error: $error');
      } finally {
        _sosScreenOpen = false;
      }
    });
  }

  void _checkLowBattery(DeviceModel device) {
    if (device.batteryLevel >= 20) {
      _lowBatteryHandled = false;
      _firestoreService.resolveActiveAlertsByType(
        deviceId: device.id,
        type: 'low_battery',
      );
      return;
    }
    if (_lowBatteryHandled) return;
    _lowBatteryHandled = true;

    Future<void>(() async {
      try {
        await _firestoreService.createLowBatteryAlert(
          deviceId: device.id,
          userName: device.userName,
          lat: device.gpsLat,
          lng: device.gpsLng,
          batteryLevel: device.batteryLevel,
        );
        await NotificationService.showSosNotification(
          title: 'Low Battery Alert',
          body:
              '${device.userName} device battery is low (${device.batteryLevel}%).',
        );
      } catch (error) {
        debugPrint('Low battery alert error: $error');
      }
    });
  }

  void _checkSafeZone(DeviceModel device) {
    if (device.safeZones.isEmpty) {
      _safeZoneHandled = false;
      return;
    }

    final insideAnyZone = device.safeZones.any((zone) {
      return _distanceInMeters(
            device.gpsLat,
            device.gpsLng,
            zone.lat,
            zone.lng,
          ) <=
          zone.radius;
    });

    if (insideAnyZone) {
      _safeZoneHandled = false;
      _firestoreService.resolveActiveAlertsByType(
        deviceId: device.id,
        type: 'safe_zone_exit',
      );
      return;
    }
    if (_safeZoneHandled) return;
    _safeZoneHandled = true;

    Future<void>(() async {
      try {
        await _firestoreService.createSafeZoneExitAlert(
          deviceId: device.id,
          userName: device.userName,
          lat: device.gpsLat,
          lng: device.gpsLng,
          batteryLevel: device.batteryLevel,
        );
        await NotificationService.showSosNotification(
          title: 'Safe Zone Alert',
          body: '${device.userName} has exited all safe zones.',
        );
      } catch (error) {
        debugPrint('Safe zone alert error: $error');
      }
    });
  }

  Future<void> _openSos(DeviceModel device) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SosAlertScreen(
          deviceId: device.id,
          userName: device.userName,
          lat: device.gpsLat,
          lng: device.gpsLng,
          batteryLevel: device.batteryLevel,
          sosActive: device.sosActive,
        ),
      ),
    );
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

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open the map')));
    }
  }

  Future<void> _openSafeZonePicker({
    required DeviceModel device,
    required String deviceId,
  }) async {
    if (device.safeZones.length >= 3) {
      _showMessage('Maximum 3 safe zones allowed');
      return;
    }
    if (device.gpsLat == 0 && device.gpsLng == 0) {
      _showMessage('Current device location is not available yet');
      return;
    }

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SafeZonePickerScreen(
          initialLat: device.gpsLat,
          initialLng: device.gpsLng,
        ),
      ),
    );
    if (result == null) return;

    try {
      await _firestoreService.addSafeZone(
        deviceId: deviceId,
        name: result['name'] as String,
        lat: result['lat'] as double,
        lng: result['lng'] as double,
        radius: result['radius'] as double,
      );
      if (mounted) _showMessage('Safe zone saved');
    } catch (error) {
      if (mounted) _showMessage('Failed to save safe zone: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _HomeColors.surfaceLight,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSafeZonesDialog(DeviceModel device, String deviceId) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.paddingOf(sheetContext).bottom,
          ),
          decoration: const BoxDecoration(
            color: _HomeColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: _HomeColors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: _HomeColors.muted.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Icon(Icons.shield_outlined, color: _HomeColors.green),
                  SizedBox(width: 10),
                  Text(
                    'Safe Zones',
                    style: TextStyle(
                      color: _HomeColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (device.safeZones.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 26),
                  child: Text(
                    'No safe zones added yet.',
                    style: TextStyle(color: _HomeColors.muted),
                  ),
                )
              else
                ...device.safeZones.asMap().entries.map((entry) {
                  final index = entry.key;
                  final zone = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _GlassCard(
                      blur: 0,
                      padding: const EdgeInsets.all(14),
                      onTap: () => _openMap(zone.lat, zone.lng),
                      child: Row(
                        children: [
                          const _RoundIcon(
                            icon: Icons.location_on_outlined,
                            color: _HomeColors.green,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  zone.name,
                                  style: const TextStyle(
                                    color: _HomeColors.text,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${zone.radius.toStringAsFixed(0)} m radius',
                                  style: const TextStyle(
                                    color: _HomeColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              Navigator.pop(sheetContext);
                              try {
                                await _firestoreService.removeSafeZoneAt(
                                  deviceId: deviceId,
                                  index: index,
                                );
                                if (mounted) _showMessage('Safe zone deleted');
                              } catch (error) {
                                if (mounted) {
                                  _showMessage(
                                    'Failed to delete safe zone: $error',
                                  );
                                }
                              }
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              color: _HomeColors.red,
                            ),
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

  @override
  Widget build(BuildContext context) {
    if (widget.deviceId != null) {
      return _buildDeviceStream(widget.deviceId!);
    }

    return FutureBuilder<String>(
      future: _deviceIdFuture!,
      builder: (context, deviceIdSnapshot) {
        if (deviceIdSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScaffold();
        }
        if (deviceIdSnapshot.hasError) {
          return _ErrorScaffold(message: '${deviceIdSnapshot.error}');
        }

        final deviceId = deviceIdSnapshot.data!;
        return _buildDeviceStream(deviceId);
      },
    );
  }

  Widget _buildDeviceStream(String deviceId) {
    return StreamBuilder<DeviceModel>(
      stream: _firestoreService.getDeviceStream(deviceId),
      builder: (context, deviceSnapshot) {
        if (deviceSnapshot.hasError) {
          return _ErrorScaffold(message: '${deviceSnapshot.error}');
        }
        if (!deviceSnapshot.hasData) {
          return _HomeTabLoading(
            onSelected: (index) => _selectBottomTab(index, deviceId),
          );
        }

        final device = deviceSnapshot.data!;
        _runDeviceChecks(device);
        return _buildDashboard(device, deviceId);
      },
    );
  }

  void _selectBottomTab(int index, String deviceId) {
    switch (index) {
      case 1:
        _openScreen(LiveTrackingScreen(deviceId: deviceId));
      case 2:
        _openScreen(CameraFeedScreen(deviceId: deviceId));
      case 3:
        _openScreen(AlertHistoryScreen(deviceId: deviceId));
      case 4:
        _openScreen(SettingsScreen(deviceId: deviceId));
    }
  }

  Widget _buildDashboard(DeviceModel device, String deviceId) {
    final user = FirebaseAuth.instance.currentUser;
    final firstName = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim().split(' ').first
        : 'Caretaker';

    return Scaffold(
      backgroundColor: _HomeColors.background,
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(child: _LayeredBackground()),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 118),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildHeader(firstName, user?.photoURL),
                      const SizedBox(height: 24),
                      _buildDeviceHero(device),
                      const SizedBox(height: 14),
                      _buildStatusRow(device),
                      const SizedBox(height: 26),
                      const _SectionHeader(title: 'Quick Actions'),
                      const SizedBox(height: 12),
                      _buildQuickActions(device, deviceId),
                      const SizedBox(height: 26),
                      const _SectionHeader(title: 'Current Location'),
                      const SizedBox(height: 12),
                      _buildLocationCard(device),
                      const SizedBox(height: 26),
                      _buildSafeZoneCard(device, deviceId),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _HomeBottomBar(
        currentIndex: 0,
        onSelected: (index) => _selectBottomTab(index, deviceId),
      ),
    );
  }

  Widget _buildHeader(String firstName, String? photoUrl) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PATHFINDER',
                style: TextStyle(
                  color: _HomeColors.lightBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Hello, $firstName',
                style: const TextStyle(
                  color: _HomeColors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        _GlassCard(
          padding: const EdgeInsets.all(3),
          borderRadius: 18,
          child: CircleAvatar(
            radius: 22,
            backgroundColor: _HomeColors.blue.withValues(alpha: .25),
            backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl),
            child: photoUrl == null
                ? const Icon(Icons.person_outline, color: _HomeColors.lightBlue)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceHero(DeviceModel device) {
    final statusColor = device.online ? _HomeColors.green : _HomeColors.red;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 190,
          child: Image.asset(
            'assets/images/pathfinder_device.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'pathfinder_001',
          style: TextStyle(
            color: _HomeColors.text,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: .2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              device.online ? 'Connected' : 'Offline',
              style: TextStyle(
                color: statusColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusRow(DeviceModel device) {
    final isCharging = device.powerState.toLowerCase() == 'charging';
    final batteryColor = isCharging
        ? _HomeColors.cyan
        : device.batteryLevel <= 20
        ? _HomeColors.red
        : device.batteryLevel <= 50
        ? _HomeColors.amber
        : _HomeColors.green;

    return _BatteryStatusCard(
      level: device.batteryLevel.clamp(0, 100),
      isCharging: isCharging,
      color: batteryColor,
    );
  }

  Widget _buildQuickActions(DeviceModel device, String deviceId) {
    return GridView.count(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.05,
      crossAxisSpacing: 10,
      children: [
        _ActionTile(
          icon: Icons.sos_rounded,
          title: 'SOS',
          subtitle: device.sosActive ? 'Emergency active' : 'All clear',
          color: device.sosActive ? _HomeColors.red : _HomeColors.green,
          glow: device.sosActive,
          pulse: device.sosActive ? _sosPulseController : null,
          onTap: () => _openSos(device),
        ),
        _ActionTile(
          icon: Icons.add_location_alt_outlined,
          title: 'Safe zone',
          subtitle: 'Add a location',
          color: _HomeColors.amber,
          onTap: () => _openSafeZonePicker(device: device, deviceId: deviceId),
        ),
      ],
    );
  }

  Widget _buildLocationCard(DeviceModel device) {
    final unavailable = device.gpsLat == 0 && device.gpsLng == 0;
    return _GlassCard(
      onTap: unavailable ? null : () => _openMap(device.gpsLat, device.gpsLng),
      child: Row(
        children: [
          const _RoundIcon(
            icon: Icons.navigation_rounded,
            color: _HomeColors.blue,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unavailable ? 'Waiting for location' : 'Live location',
                  style: const TextStyle(
                    color: _HomeColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  unavailable
                      ? 'The device has not reported GPS data.'
                      : '${device.gpsLat.toStringAsFixed(5)}, '
                            '${device.gpsLng.toStringAsFixed(5)}',
                  style: const TextStyle(
                    color: _HomeColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!unavailable)
            const Icon(Icons.chevron_right_rounded, color: _HomeColors.muted),
        ],
      ),
    );
  }

  Widget _buildSafeZoneCard(DeviceModel device, String deviceId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Safe Zones'),
        const SizedBox(height: 12),
        _GlassCard(
          onTap: () => _showSafeZonesDialog(device, deviceId),
          child: Row(
            children: [
              const _RoundIcon(
                icon: Icons.shield_outlined,
                color: _HomeColors.green,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.safeZones.isEmpty
                          ? 'No safe zones'
                          : '${device.safeZones.length} active '
                                '${device.safeZones.length == 1 ? 'zone' : 'zones'}',
                      style: const TextStyle(
                        color: _HomeColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap to view and manage',
                      style: TextStyle(color: _HomeColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _HomeColors.muted),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.blur = 6,
    this.onTap,
    this.tintColor,
    this.glowColor,
    this.glowStrength = .48,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;
  final VoidCallback? onTap;
  final Color? tintColor;
  final Color? glowColor;
  final double glowStrength;

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (tintColor ?? const Color(0xFFD7E0EB)).withValues(
                  alpha: tintColor == null ? .17 : .42,
                ),
                (tintColor ?? const Color(0xFF7088AD)).withValues(
                  alpha: tintColor == null ? .14 : .25,
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
              BoxShadow(
                color: _HomeColors.blue.withValues(alpha: .07),
                blurRadius: 18,
                offset: const Offset(-5, -5),
              ),
              if (glowColor != null)
                BoxShadow(
                  color: glowColor!.withValues(alpha: glowStrength),
                  blurRadius: 22 + (glowStrength * 20),
                  spreadRadius: glowStrength * 5,
                ),
            ],
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(borderRadius),
      child: content,
    );
  }
}

class _BatteryStatusCard extends StatelessWidget {
  const _BatteryStatusCard({
    required this.level,
    required this.isCharging,
    required this.color,
  });

  final int level;
  final bool isCharging;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      blur: 4,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCharging ? Icons.bolt_rounded : Icons.battery_5_bar_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'Battery Status',
                  style: TextStyle(
                    color: _HomeColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCharging) ...[
                    Icon(Icons.bolt_rounded, color: color, size: 18),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    isCharging ? 'Charging' : _batteryLabel,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: SizedBox(
              height: 28,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: Colors.black.withValues(alpha: .28)),
                  FractionallySizedBox(
                    widthFactor: level / 100,
                    alignment: Alignment.centerLeft,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withValues(alpha: .72), color],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: .45),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCharging) ...[
                          const Icon(
                            Icons.bolt_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 2),
                        ],
                        Text(
                          '$level%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 4),
                            ],
                          ),
                        ),
                      ],
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

  String get _batteryLabel {
    if (level <= 20) return 'Low';
    if (level <= 50) return 'Moderate';
    return 'Good';
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.glow = false,
    this.pulse,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool glow;
  final Animation<double>? pulse;

  @override
  Widget build(BuildContext context) {
    Widget buildTile(double pulseValue) {
      return Opacity(
        opacity: glow ? .78 + (pulseValue * .22) : 1,
        child: _GlassCard(
          blur: 5,
          borderRadius: 18,
          padding: const EdgeInsets.all(18),
          onTap: onTap,
          tintColor: color,
          glowColor: glow ? color : null,
          glowStrength: glow ? .2 + (pulseValue * .52) : 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RoundIcon(icon: icon, color: color, size: 48),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _HomeColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (pulse == null) return buildTile(0);

    return AnimatedBuilder(
      animation: pulse!,
      builder: (context, child) {
        return buildTile(pulse!.value);
      },
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.color, this.size = 46});

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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: _HomeColors.text,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _HomeBottomBar extends StatelessWidget {
  const _HomeBottomBar({required this.currentIndex, required this.onSelected});

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
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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

class _LayeredBackground extends StatelessWidget {
  const _LayeredBackground();

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
            clipper: _BlueBackgroundClipper(),
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

class _BlueBackgroundClipper extends CustomClipper<Path> {
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

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _HomeColors.background,
      body: Center(
        child: CircularProgressIndicator(color: _HomeColors.lightBlue),
      ),
    );
  }
}

class _HomeTabLoading extends StatelessWidget {
  const _HomeTabLoading({required this.onSelected});

  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _HomeColors.background,
      extendBody: true,
      body: const Stack(
        children: [
          Positioned.fill(child: _LayeredBackground()),
          Center(
            child: CircularProgressIndicator(color: _HomeColors.lightBlue),
          ),
        ],
      ),
      bottomNavigationBar: _HomeBottomBar(
        currentIndex: 0,
        onSelected: onSelected,
      ),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _HomeColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  color: _HomeColors.red,
                  size: 42,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Unable to load dashboard',
                  style: TextStyle(
                    color: _HomeColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _HomeColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
