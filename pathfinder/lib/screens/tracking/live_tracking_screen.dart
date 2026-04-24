import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
  bool _showInfo = false;

  double _currentLat = 0;
  double _currentLng = 0;
  String _userName = 'Unknown';
  bool _online = false;
  int _batteryLevel = 0;
  bool _sosActive = false;

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
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
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
          _mapController.move(
            LatLng(_currentLat, _currentLng),
            _mapController.camera.zoom,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Live Tracking'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
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
          final locationText = 'Lat: $_currentLat\nLng: $_currentLng';

          return Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Live Overview'),
                    Row(
                      children: [
                        _miniStatusCard(
                          icon: Icons.sensors,
                          label: 'Device',
                          value: _online ? 'Online' : 'Offline',
                          iconColor: _online ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 12),
                        _miniStatusCard(
                          icon: Icons.warning,
                          label: 'SOS Status',
                          value: _sosActive ? 'Active' : 'Inactive',
                          iconColor: _sosActive ? Colors.red : Colors.grey,
                          backgroundColor:
                              _sosActive ? Colors.red.shade50 : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _miniStatusCard(
                          icon: Icons.battery_full,
                          label: 'Battery',
                          value: '$_batteryLevel%',
                          iconColor: Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        _miniStatusCard(
                          icon: Icons.person_pin_circle,
                          label: 'Tracked User',
                          value: _userName,
                          iconColor: Colors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                          const Icon(
                            Icons.location_on,
                            color: Colors.blue,
                            size: 30,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Current Coordinates',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  locationText,
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
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openInMaps,
                        icon: const Icon(Icons.navigation),
                        label: const Text('Open in Maps'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}