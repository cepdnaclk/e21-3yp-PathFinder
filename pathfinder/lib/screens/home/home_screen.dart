import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../models/device_model.dart';
import '../../services/firestore_service.dart';
import '../alerts/sos_alert_screen.dart';
import '../tracking/live_tracking_screen.dart';
import '../../services/notification_service.dart';
import '../alerts/alert_history_screen.dart';
import 'settings_screen.dart';
import 'safe_zone_picker_screen.dart';
import '../tracking/camera_feed_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _sosScreenOpen = false;
  bool _sosAlreadyHandled = false;
  String? _lastHandledSosDeviceId;

  bool _lowBatteryHandled = false;
  bool _safeZoneHandled = false;
  bool _resolvingCity = false;
  String? _resolvedCity;
  String? _lastResolvedCoordinateKey;

  double _distanceInMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371000;

    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  Future<void> _resolveCityName(double lat, double lng) async {
    if (lat == 0 && lng == 0) {
      if (!mounted) return;
      setState(() {
        _resolvedCity = 'Location unavailable';
        _lastResolvedCoordinateKey = null;
      });
      return;
    }

    final coordinateKey =
        '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
    if (_lastResolvedCoordinateKey == coordinateKey || _resolvingCity) return;

    _resolvingCity = true;
    if (mounted) {
      setState(() {
        _resolvedCity = null;
      });
    }

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': lat.toString(),
        'lon': lng.toString(),
        'zoom': '10',
        'addressdetails': '1',
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'PathFinder/1.0'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = (data['address'] as Map?)?.cast<String, dynamic>();
        final city = address?['city'] ??
            address?['town'] ??
            address?['village'] ??
            address?['municipality'] ??
            address?['state_district'] ??
            address?['state'];

        if (!mounted) return;
        setState(() {
          _resolvedCity = (city?.toString().isNotEmpty ?? false)
              ? city.toString()
              : 'City unavailable';
          _lastResolvedCoordinateKey = coordinateKey;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _resolvedCity = 'City unavailable';
          _lastResolvedCoordinateKey = coordinateKey;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resolvedCity = 'City unavailable';
        _lastResolvedCoordinateKey = coordinateKey;
      });
    } finally {
      _resolvingCity = false;
    }
  }

  void _checkAndOpenSos(DeviceModel device) {
    if (!mounted) return;

    if (!device.sosActive) {
      NotificationService.cancelSosNotification();
      _sosScreenOpen = false;
      _sosAlreadyHandled = false;
      _lastHandledSosDeviceId = null;
      return;
    }

    if (_sosAlreadyHandled && _lastHandledSosDeviceId == device.id) return;
    if (_sosScreenOpen) return;

    _sosScreenOpen = true;
    _sosAlreadyHandled = true;
    _lastHandledSosDeviceId = device.id;

    Future.microtask(() async {
      try {
        await FirestoreService().createSosAlert(
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
          builder: (context) {
            return AlertDialog(
              title: const Text('SOS Alert'),
              content: Text(
                '${device.userName} has triggered an emergency alert.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Later'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open'),
                ),
              ],
            );
          },
        );

        if (shouldOpen == true && mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
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
      } catch (e) {
        debugPrint('SOS handling error: $e');
      } finally {
        if (mounted) {
          _sosScreenOpen = false;
        }
      }
    });
  }

  void _checkLowBattery(DeviceModel device) {
    if (!mounted) return;

    if (device.batteryLevel >= 20) {
      _lowBatteryHandled = false;
      FirestoreService().resolveActiveAlertsByType(
        deviceId: device.id,
        type: 'low_battery',
      );
      return;
    }

    if (_lowBatteryHandled) return;
    _lowBatteryHandled = true;

    Future.microtask(() async {
      try {
        await FirestoreService().createLowBatteryAlert(
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
      } catch (e) {
        debugPrint('Low battery alert error: $e');
      }
    });
  }

  void _checkSafeZone(DeviceModel device) {
    if (!mounted) return;

    if (device.safeZones.isEmpty) {
      _safeZoneHandled = false;
      return;
    }

    bool insideAnyZone = false;

    for (final zone in device.safeZones) {
      final distance = _distanceInMeters(
        device.gpsLat,
        device.gpsLng,
        zone.lat,
        zone.lng,
      );

      if (distance <= zone.radius) {
        insideAnyZone = true;
        break;
      }
    }

    if (insideAnyZone) {
      _safeZoneHandled = false;
      FirestoreService().resolveActiveAlertsByType(
        deviceId: device.id,
        type: 'safe_zone_exit',
      );
      return;
    }

    if (_safeZoneHandled) return;
    _safeZoneHandled = true;

    Future.microtask(() async {
      try {
        await FirestoreService().createSafeZoneExitAlert(
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
      } catch (e) {
        debugPrint('Safe zone alert error: $e');
      }
    });
  }

  Future<String> _getMyDeviceId() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("No logged in user");
    }

    final deviceId = await FirestoreService().getLinkedDeviceId(user.uid);

    if (deviceId == null || deviceId.isEmpty) {
      throw Exception("No linked device found");
    }

    return deviceId;
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _miniStatusCard({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    Color? backgroundColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 30),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 34, color: color),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _combinedAlertsCard({
    required VoidCallback onSosTap,
    required VoidCallback onHistoryTap,
  }) {
    Widget miniAction({
      required IconData icon,
      required String title,
      required Color color,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Ink(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Alerts",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  miniAction(
                    icon: Icons.warning,
                    title: "SOS",
                    color: Colors.red,
                    onTap: onSosTap,
                  ),
                  const SizedBox(width: 8),
                  miniAction(
                    icon: Icons.history,
                    title: "History",
                    color: Colors.orange,
                    onTap: onHistoryTap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSafeZonePicker({
    required BuildContext context,
    required DeviceModel device,
    required String deviceId,
  }) async {
    if (device.safeZones.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 safe zones allowed')),
      );
      return;
    }

    if (device.gpsLat == 0 && device.gpsLng == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Current device location is not available yet'),
        ),
      );
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
      await FirestoreService().addSafeZone(
        deviceId: deviceId,
        name: result['name'] as String,
        lat: result['lat'] as double,
        lng: result['lng'] as double,
        radius: result['radius'] as double,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Safe zone saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save safe zone: $e')),
      );
    }
  }

  Widget _combinedTrackingCard({
    required VoidCallback onLiveTrackingTap,
    required VoidCallback onAddSafeZoneTap,
  }) {
    Widget miniAction({
      required IconData icon,
      required String title,
      required Color color,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Ink(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tracking',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  miniAction(
                    icon: Icons.location_on,
                    title: 'Live',
                    color: Colors.blue,
                    onTap: onLiveTrackingTap,
                  ),
                  const SizedBox(width: 8),
                  miniAction(
                    icon: Icons.add_location_alt,
                    title: 'add safe zone',
                    color: Colors.teal,
                    onTap: onAddSafeZoneTap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _batteryCard(int batteryLevel) {
    final level = batteryLevel.clamp(0, 100);
    final factor = level / 100;

    Color fillColor;
    if (level > 60) {
      fillColor = Colors.green.shade200;
    } else if (level > 30) {
      fillColor = Colors.orange.shade200;
    } else {
      fillColor = Colors.red.shade200;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: factor,
              child: Container(color: fillColor),
            ),
          ),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: const Icon(Icons.battery_full, color: Colors.orange),
            title: const Text(
              "Battery Level",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text("$level%"),
          ),
        ],
      ),
    );
  }

  void _showSafeZonesDialog(
    BuildContext context,
    DeviceModel device,
    String deviceId,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Safe Zones"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: device.safeZones.length,
              itemBuilder: (context, index) {
                final zone = device.safeZones[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final googleMapsUrl =
                          'https://www.google.com/maps/search/?api=1&query=${zone.lat},${zone.lng}';
                      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
                        await launchUrl(Uri.parse(googleMapsUrl),
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  zone.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Radius: ${zone.radius.toStringAsFixed(0)} m",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Lat: ${zone.lat.toStringAsFixed(4)}, Lng: ${zone.lng.toStringAsFixed(4)}",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Click to open in Google Maps",
                                  style: TextStyle(
                                    color: Colors.blue.shade600,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              Navigator.pop(context);
                              try {
                                await FirestoreService().removeSafeZoneAt(
                                  deviceId: deviceId,
                                  index: index,
                                );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Safe zone deleted'),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Failed to delete safe zone: $e'),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firestoreService = FirestoreService();

    return FutureBuilder<String>(
      future: _getMyDeviceId(),
      builder: (context, deviceIdSnapshot) {
        if (deviceIdSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (deviceIdSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("PathFinder Dashboard"),
            ),
            body: Center(
              child: Text('Error: ${deviceIdSnapshot.error}'),
            ),
          );
        }

        final deviceId = deviceIdSnapshot.data!;

        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            title: const Text("PathFinder"),
            centerTitle: true,
          ),
          body: StreamBuilder<DeviceModel>(
            stream: firestoreService.getDeviceStream(deviceId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final device = snapshot.data!;
              _checkAndOpenSos(device);
              _checkLowBattery(device);
              _checkSafeZone(device);
              _resolveCityName(device.gpsLat, device.gpsLng);

              final hasSafeZone = device.safeZones.isNotEmpty;
              final locationLine = _resolvedCity == null
                  ? (_resolvingCity
                      ? 'City: Resolving...'
                      : 'City: Unavailable')
                  : 'City: $_resolvedCity';

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundImage: user?.photoURL != null
                                ? NetworkImage(user!.photoURL!)
                                : null,
                            child: user?.photoURL == null
                                ? const Icon(Icons.person, size: 28)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.displayName ?? "Caretaker",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user?.email ?? "",
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    _sectionTitle("Overview"),

                    Row(
                      children: [
                        _miniStatusCard(
                          icon: Icons.sensors,
                          label: "Device",
                          value: device.online ? "Online" : "Offline",
                          iconColor:
                              device.online ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 12),
                        _miniStatusCard(
                          icon: Icons.person_pin_circle,
                          label: "Tracked User",
                          value: device.userName,
                          iconColor: Colors.blue,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        _miniStatusCard(
                          icon: Icons.warning,
                          label: "SOS Status",
                          value: device.sosActive ? "Active" : "Inactive",
                          iconColor:
                              device.sosActive ? Colors.red : Colors.grey,
                          backgroundColor:
                              device.sosActive ? Colors.red.shade50 : null,
                        ),
                        const SizedBox(width: 12),
                        _miniStatusCard(
                          icon: Icons.devices,
                          label: "Device ID",
                          value: deviceId,
                          iconColor: Colors.deepPurple,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Location card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on,
                              color: Colors.blue, size: 30),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Last Known Location",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  locationLine,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Lat: ${device.gpsLat}\nLng: ${device.gpsLng}",
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (hasSafeZone) ...[
                      const SizedBox(height: 16),
                      InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => _showSafeZonesDialog(context, device, deviceId),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(Icons.home,
                                  color: Colors.teal, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Safe Zones",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Click to open",
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios, 
                                  size: 16, 
                                  color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    _batteryCard(device.batteryLevel),

                    const SizedBox(height: 24),
                    _sectionTitle("Quick Actions"),

                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: [
                        _combinedTrackingCard(
                          onLiveTrackingTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    LiveTrackingScreen(deviceId: deviceId),
                              ),
                            );
                          },
                          onAddSafeZoneTap: () {
                            _openSafeZonePicker(
                              context: context,
                              device: device,
                              deviceId: deviceId,
                            );
                          },
                        ),
                        _actionCard(
                          icon: Icons.videocam,
                          title: "Live Camera",
                          color: Colors.purple,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CameraFeedScreen(deviceId: deviceId),
                              ),
                            );
                          },
                        ),
                        _combinedAlertsCard(
                          onSosTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
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
                          },
                          onHistoryTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AlertHistoryScreen(deviceId: deviceId),
                              ),
                            );
                          },
                        ),
                        _actionCard(
                          icon: Icons.settings,
                          title: "Settings",
                          color: Colors.grey,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    SettingsScreen(deviceId: deviceId),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
