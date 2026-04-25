import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_launcher/map_launcher.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String deviceId;

  const LiveTrackingScreen({
    super.key,
    required this.deviceId,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final MapController _mapController = MapController();

  bool _followUser = true;

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
    _currentLat = (data['gpsLat'] ?? 0).toDouble();
    _currentLng = (data['gpsLng'] ?? 0).toDouble();
    _userName = data['userName'] ?? 'Unknown';
    _online = data['online'] ?? false;
    _batteryLevel = (data['batteryLevel'] ?? 0).toInt();
    _sosActive = data['sosActive'] ?? false;

    if (_followUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(
            LatLng(_currentLat, _currentLng),
            _mapController.camera.zoom,
          );
        }
      });
    }
  }

  Widget _topStatusCard() {
    return Positioned(
      top: 24,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.blue.shade50,
              child: const Icon(Icons.person, color: Colors.blue, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$_userName's device",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: _online ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 6),
                      Text(_online ? 'Active' : 'Offline'),
                      const SizedBox(width: 12),
                      const Icon(Icons.battery_full,
                          size: 18, color: Colors.green),
                      const SizedBox(width: 4),
                      Text('$_batteryLevel%'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationCard() {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.blue.shade50,
              child: const Icon(Icons.location_on, color: Colors.blue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Location',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lat: ${_currentLat.toStringAsFixed(6)}, '
                    'Lng: ${_currentLng.toStringAsFixed(6)}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            Container(
              height: 46,
              width: 1,
              color: Colors.grey.shade300,
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: _openInMaps,
              borderRadius: BorderRadius.circular(14),
              child: Column(
                children: const [
                  Icon(Icons.navigation, color: Colors.blue),
                  SizedBox(height: 4),
                  Text(
                    'Directions',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activityPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Live Activity',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _activityBadge(
                  icon: Icons.sensors,
                  color: _online ? Colors.green : Colors.red,
                  label: _online ? 'Active' : 'Offline',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _activityBadge(
                  icon: Icons.battery_full,
                  color: _batteryLevel > 30 ? Colors.green : Colors.red,
                  label: '$_batteryLevel%',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _activityBadge(
                  icon: Icons.warning,
                  color: _sosActive ? Colors.red : Colors.grey,
                  label: _sosActive ? 'SOS' : 'Safe',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activityBadge({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.blueGrey,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4D9DD),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('devices')
              .doc(widget.deviceId)
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Live Tracking',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white,
                        child: IconButton(
                          icon: const Icon(Icons.my_location),
                          onPressed: () {
                            _mapController.move(currentLocation, 16);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Stack(
                        children: [
                          FlutterMap(
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
                                    width: 90,
                                    height: 90,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 70,
                                          height: 70,
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.18),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.blue,
                                              width: 3,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.person,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          _topStatusCard(),
                          _locationCard(),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: SizedBox(
                    height: 122,
                    child: _activityPanel(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}