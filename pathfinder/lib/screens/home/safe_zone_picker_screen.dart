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

  @override
  Widget build(BuildContext context) {
    final circleRadiusLabel = _radius.toStringAsFixed(0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Safe Zone'),
        actions: [
          TextButton(
            onPressed: _saveZone,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedCenter,
                    initialZoom: 16,
                    onTap: (tapPosition, point) {
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
                          color: Colors.blue.withOpacity(0.2),
                          borderColor: Colors.blue,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        // Selected safe zone center
                        Marker(
                          point: _selectedCenter,
                          width: 80,
                          height: 80,
                          child: const Icon(
                            Icons.location_pin,
                            size: 48,
                            color: Colors.red,
                          ),
                        ),

                        // Current user/device location
                        Marker(
                          point: _currentUserLocation,
                          width: 70,
                          height: 70,
                          child: const Icon(
                            Icons.my_location,
                            size: 28,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Recenter button
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'current_location_btn',
                    onPressed: _goToCurrentLocation,
                    child: const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Safe Zone Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.radio_button_checked),
                        const SizedBox(width: 8),
                        Text('Radius: $circleRadiusLabel m'),
                      ],
                    ),
                    Slider(
                      value: _radius,
                      min: 50,
                      max: 500,
                      divisions: 18,
                      label: circleRadiusLabel,
                      onChanged: (value) {
                        setState(() {
                          _radius = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Selected Center: '
                      '${_selectedCenter.latitude.toStringAsFixed(6)}, '
                      '${_selectedCenter.longitude.toStringAsFixed(6)}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Current User Location: '
                      '${_currentUserLocation.latitude.toStringAsFixed(6)}, '
                      '${_currentUserLocation.longitude.toStringAsFixed(6)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveZone,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Safe Zone'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}