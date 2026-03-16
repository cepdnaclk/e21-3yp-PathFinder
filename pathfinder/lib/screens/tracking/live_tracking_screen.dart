import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  static const String deviceId = 'pathfinder_001';

  final MapController _mapController = MapController();

  bool _followUser = true;
  bool _showInfo = false;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No map applications found')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableMaps.map((map) {
              return ListTile(
                leading: SvgPicture.asset(
                  map.icon,
                  width: 30,
                  height: 30,
                ),
                title: Text(map.mapName),
                onTap: () {
                  map.showMarker(
                    coords: Coords(_currentLat, _currentLng),
                    title: _userName,
                    description: "PathFinder live location",
                  );

                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _updateFromFirestore(Map<String, dynamic> data) {
    final newLat = (data['gpsLat'] ?? 0).toDouble();
    final newLng = (data['gpsLng'] ?? 0).toDouble();

    _userName = data['userName'] ?? 'Unknown';
    _online = data['online'] ?? false;
    _batteryLevel = (data['batteryLevel'] ?? 0).toInt();
    _sosActive = data['sosActive'] ?? false;
    _currentLat = newLat;
    _currentLng = newLng;

    if (_followUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(LatLng(_currentLat, _currentLng), _mapController.camera.zoom);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
        actions: [
          IconButton(
            icon: Icon(_followUser ? Icons.gps_fixed : Icons.gps_not_fixed),
            tooltip: _followUser ? 'Auto-follow ON' : 'Auto-follow OFF',
            onPressed: () {
              setState(() {
                _followUser = !_followUser;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Open in Maps',
            onPressed: _openInMaps,
          ),
        ],
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
          _updateFromFirestore(data);

          final currentLocation = LatLng(_currentLat, _currentLng);

          return Column(
            children: [
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: currentLocation,
                    initialZoom: 16,
                    onTap: (_, _) {
                      setState(() {
                        _showInfo = false;
                      });
                    },
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
                          width: 90,
                          height: 90,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showInfo = !_showInfo;
                              });
                            },
                            child: const Icon(
                              Icons.location_pin,
                              size: 52,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_showInfo)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: currentLocation,
                            width: 220,
                            height: 110,
                            alignment: Alignment.topCenter,
                            child: Transform.translate(
                              offset: const Offset(0, -70),
                              child: Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _userName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Lat: $_currentLat'),
                                      Text('Lng: $_currentLng'),
                                    ],
                                  ),
                                ),
                              ),
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
                          title: Text(_userName),
                          subtitle: const Text('Tracked User'),
                        ),
                        ListTile(
                          leading: Icon(
                            _online ? Icons.check_circle : Icons.cancel,
                            color: _online ? Colors.green : Colors.red,
                          ),
                          title: const Text('Device Status'),
                          subtitle: Text(_online ? 'Online' : 'Offline'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.blue),
                          title: const Text('Coordinates'),
                          subtitle: Text('Lat: $_currentLat, Lng: $_currentLng'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.battery_full, color: Colors.orange),
                          title: const Text('Battery'),
                          subtitle: Text('$_batteryLevel%'),
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.warning,
                            color: _sosActive ? Colors.red : Colors.grey,
                          ),
                          title: const Text('SOS Status'),
                          subtitle: Text(
                            _sosActive ? 'Emergency Active' : 'No active alerts',
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _openInMaps,
                            icon: const Icon(Icons.navigation),
                            label: const Text('Open in Maps'),
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