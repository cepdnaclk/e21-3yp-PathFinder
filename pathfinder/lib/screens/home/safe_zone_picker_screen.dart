import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SafeZonePickerScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const SafeZonePickerScreen({
    super.key,
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<SafeZonePickerScreen> createState() => _SafeZonePickerScreenState();
}

class _SafeZonePickerScreenState extends State<SafeZonePickerScreen> {
  late final MapController _mapController;
  late LatLng _selectedCenter;
  late LatLng _currentUserLocation;

  final TextEditingController _nameController =
      TextEditingController(text: 'Safe Zone');

  double _radius = 100;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedCenter = LatLng(widget.initialLat, widget.initialLng);
    _currentUserLocation = LatLng(widget.initialLat, widget.initialLng);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveZone() {
    final name = _nameController.text.trim().isEmpty
        ? 'Safe Zone'
        : _nameController.text.trim();

    Navigator.pop(context, {
      'name': name,
      'lat': _selectedCenter.latitude,
      'lng': _selectedCenter.longitude,
      'radius': _radius,
    });
  }

  void _goToCurrentLocation() {
    _mapController.move(_currentUserLocation, 16);
  }

  Widget _topButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return CircleAvatar(
      radius: 26,
      backgroundColor: Colors.white,
      child: IconButton(
        icon: Icon(icon, color: Colors.black87),
        onPressed: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radiusLabel = _radius.toStringAsFixed(0);

    return Scaffold(
      backgroundColor: const Color(0xFFF4D9DD),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Row(
                children: [
                  _topButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  const Text(
                    'Safe Zone',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  _topButton(
                    icon: Icons.check,
                    onTap: _saveZone,
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
                          initialCenter: _selectedCenter,
                          initialZoom: 16,
                          onTap: (_, point) {
                            setState(() {
                              _selectedCenter = point;
                            });
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.pathfinder',
                          ),
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: _selectedCenter,
                                radius: _radius,
                                useRadiusInMeter: true,
                                color: Colors.blue.withValues(alpha: 0.18),
                                borderColor: Colors.blue,
                                borderStrokeWidth: 2,
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _selectedCenter,
                                width: 90,
                                height: 90,
                                child: const Icon(
                                  Icons.location_pin,
                                  size: 54,
                                  color: Colors.red,
                                ),
                              ),
                              Marker(
                                point: _currentUserLocation,
                                width: 80,
                                height: 80,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.16),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.blue,
                                          width: 3,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.my_location,
                                        color: Colors.blue,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      Positioned(
                        top: 18,
                        left: 18,
                        right: 18,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.blue.shade50,
                                child: const Icon(
                                  Icons.home,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tap to rename',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextField(
                                      controller: _nameController,
                                      decoration: const InputDecoration(
                                        hintText: 'Safe Zone Name',
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Positioned(
                        right: 18,
                        bottom: 18,
                        child: FloatingActionButton.small(
                          heroTag: 'current_location_btn',
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue,
                          onPressed: _goToCurrentLocation,
                          child: const Icon(Icons.my_location),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Zone Radius',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1EC),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white,
                              child: const Icon(
                                Icons.radio_button_checked,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$radiusLabel meters',
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Drag slider to adjust safe zone size',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _radius,
                          min: 50,
                          max: 500,
                          divisions: 18,
                          label: radiusLabel,
                          onChanged: (value) {
                            setState(() {
                              _radius = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Selected: ${_selectedCenter.latitude.toStringAsFixed(6)}, '
                            '${_selectedCenter.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveZone,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Safe Zone'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}