import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/device_model.dart';
import '../../services/firestore_service.dart';
import '../alerts/sos_alert_screen.dart';
import '../tracking/live_tracking_screen.dart';
import '../../services/notification_service.dart';
import '../alerts/alert_history_screen.dart';
import 'settings_screen.dart';
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

  void _checkAndOpenSos(DeviceModel device) {
    if (!mounted) return;

    if (!device.sosActive) {
      NotificationService.cancelSosNotification();
      _sosScreenOpen = false;
      _sosAlreadyHandled = false;
      _lastHandledSosDeviceId = null;
      return;
    }

    if (_sosAlreadyHandled && _lastHandledSosDeviceId == device.id) {
      return;
    }

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

    if (device.safeZoneLat == null ||
        device.safeZoneLng == null ||
        device.safeZoneRadius == null) {
      _safeZoneHandled = false;
      return;
    }

    final distance = _distanceInMeters(
      device.gpsLat,
      device.gpsLng,
      device.safeZoneLat!,
      device.safeZoneLng!,
    );

    final isOutside = distance > device.safeZoneRadius!;

    if (!isOutside) {
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
          body:
              '${device.userName} has exited the safe zone "${device.safeZoneName ?? 'Safe Zone'}".',
        );
      } catch (e) {
        debugPrint('Safe zone alert error: $e');
      }
    });
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 10),
            Text(title),
          ],
        ),
      ),
    );
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
          appBar: AppBar(
            title: const Text("PathFinder"),
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

              final hasSafeZone = device.safeZoneLat != null &&
                  device.safeZoneLng != null &&
                  device.safeZoneRadius != null;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user?.photoURL != null
                              ? NetworkImage(user!.photoURL!)
                              : null,
                          child: user?.photoURL == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(user?.displayName ?? "Caretaker"),
                        subtitle: Text(user?.email ?? ""),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Device Status",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.sensors,
                          color: device.online ? Colors.green : Colors.red,
                        ),
                        title: Text(device.userName),
                        subtitle: Text(device.online ? "Online" : "Offline"),
                        trailing: Icon(
                          device.online ? Icons.check_circle : Icons.cancel,
                          color: device.online ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading:
                            const Icon(Icons.location_on, color: Colors.blue),
                        title: const Text("Last Known Location"),
                        subtitle:
                            Text("Lat: ${device.gpsLat}, Lng: ${device.gpsLng}"),
                      ),
                    ),
                    if (hasSafeZone) ...[
                      const SizedBox(height: 12),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.home, color: Colors.teal),
                          title: Text(
                            'Safe Zone: ${device.safeZoneName ?? 'Safe Zone'}',
                          ),
                          subtitle: Text(
                            'Radius: ${device.safeZoneRadius!.toStringAsFixed(0)} m',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor:
                                  (device.batteryLevel.clamp(0, 100) / 100),
                              child: Container(
                                color: device.batteryLevel > 60
                                    ? Colors.green.shade100
                                    : device.batteryLevel > 30
                                        ? Colors.orange.shade100
                                        : Colors.red.shade100,
                              ),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.battery_full,
                                color: Colors.orange),
                            title: const Text("Battery Level"),
                            subtitle: Text("${device.batteryLevel}%"),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: device.sosActive ? Colors.red.shade50 : null,
                      child: ListTile(
                        leading: Icon(
                          Icons.warning,
                          color: device.sosActive ? Colors.red : Colors.grey,
                        ),
                        title: const Text("SOS Status"),
                        subtitle: Text(
                          device.sosActive
                              ? "Emergency Active"
                              : "No active alerts",
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Quick Actions",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      children: [
                        _actionCard(
                          icon: Icons.location_on,
                          title: "Live Tracking",
                          color: Colors.blue,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    LiveTrackingScreen(deviceId: deviceId),
                              ),
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
                        _actionCard(
                          icon: Icons.warning,
                          title: "SOS Alerts",
                          color: Colors.red,
                          onTap: () {
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
                        ),
                        _actionCard(
                          icon: Icons.history,
                          title: "Alert History",
                          color: Colors.orange,
                          onTap: () {
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