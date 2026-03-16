import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/device_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../alerts/sos_alert_screen.dart';
import '../tracking/live_tracking_screen.dart';
import '../../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _sosScreenOpen = false;

  Future<void> _logout(BuildContext context) async {
    await AuthService().signOut();

    if (!context.mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  void _checkAndOpenSos(DeviceModel device) {
    if (!mounted) return;
    if (!device.sosActive) {
      _sosScreenOpen = false;
      return;
    }

    if (_sosScreenOpen) return;

    _sosScreenOpen = true;

    Future.microtask(() async {
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
              userName: device.userName,
              lat: device.gpsLat,
              lng: device.gpsLng,
              batteryLevel: device.batteryLevel,
              sosActive: device.sosActive,
            ),
          ),
        );
      }

      if (mounted) {
        _sosScreenOpen = false;
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firestoreService = FirestoreService();

    const String deviceId = 'pathfinder_001';

    return Scaffold(
      appBar: AppBar(
        title: const Text("PathFinder Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    leading: const Icon(Icons.location_on, color: Colors.blue),
                    title: const Text("Last Known Location"),
                    subtitle: Text("Lat: ${device.gpsLat}, Lng: ${device.gpsLng}"),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.battery_full, color: Colors.orange),
                    title: const Text("Battery Level"),
                    subtitle: Text("${device.batteryLevel}%"),
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
                      device.sosActive ? "Emergency Active" : "No active alerts",
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Quick Actions",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                            builder: (_) => const LiveTrackingScreen(),
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
                      onTap: () {},
                    ),
                    _actionCard(
                      icon: Icons.settings,
                      title: "Settings",
                      color: Colors.grey,
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}