import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LiveTrackingScreen extends StatelessWidget {
  const LiveTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const String deviceId = 'pathfinder_001';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('devices')
            .doc(deviceId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final double lat = (data['gpsLat'] ?? 0).toDouble();
          final double lng = (data['gpsLng'] ?? 0).toDouble();
          final bool online = data['online'] ?? false;
          final int batteryLevel = (data['batteryLevel'] ?? 0).toInt();
          final bool sosActive = data['sosActive'] ?? false;
          final String userName = data['userName'] ?? 'Unknown';

          final currentLocation = LatLng(lat, lng);

          return Column(
            children: [
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: currentLocation,
                    initialZoom: 16,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.pathfinder',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: currentLocation,
                          width: 80,
                          height: 80,
                          child: const Icon(
                            Icons.location_pin,
                            size: 50,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(userName),
                          subtitle: const Text('Tracked User'),
                        ),
                        ListTile(
                          leading: Icon(
                            online ? Icons.check_circle : Icons.cancel,
                            color: online ? Colors.green : Colors.red,
                          ),
                          title: const Text('Device Status'),
                          subtitle: Text(online ? 'Online' : 'Offline'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.blue),
                          title: const Text('Coordinates'),
                          subtitle: Text('Lat: $lat, Lng: $lng'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.battery_full, color: Colors.orange),
                          title: const Text('Battery'),
                          subtitle: Text('$batteryLevel%'),
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.warning,
                            color: sosActive ? Colors.red : Colors.grey,
                          ),
                          title: const Text('SOS Status'),
                          subtitle: Text(
                            sosActive ? 'Emergency Active' : 'No active alerts',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}