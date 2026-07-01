import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class _PickerColors {
  static const background = Color(0xFF050A12);
  static const surface = Color(0xFF101925);
  static const blue = Color(0xFF2563EB);
  static const lightBlue = Color(0xFF60A5FA);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFF43F5E);
  static const text = Color(0xFFF8FAFC);
  static const muted = Color(0xFF94A3B8);
}

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
  late final LatLng _currentUserLocation;

  final TextEditingController _nameController = TextEditingController(
    text: 'Safe Zone',
  );

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
    final enteredName = _nameController.text.trim();
    Navigator.pop(context, {
      'name': enteredName.isEmpty ? 'Safe Zone' : enteredName,
      'lat': _selectedCenter.latitude,
      'lng': _selectedCenter.longitude,
      'radius': _radius,
    });
  }

  void _goToCurrentLocation() {
    _mapController.move(_currentUserLocation, 16);
    setState(() => _selectedCenter = _currentUserLocation);
  }

  @override
  Widget build(BuildContext context) {
    final radiusLabel = _radius.toStringAsFixed(0);

    return Scaffold(
      backgroundColor: _PickerColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _PickerLayeredBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 14),
                Expanded(child: _buildMap()),
                const SizedBox(height: 14),
                _buildControls(radiusLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Row(
        children: [
          _SquareButton(
            icon: Icons.arrow_back_rounded,
            color: const Color(0xFF334155),
            onTap: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Column(
              children: [
                Text(
                  'SAFE ZONE',
                  style: TextStyle(
                    color: _PickerColors.lightBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Choose Location',
                  style: TextStyle(
                    color: _PickerColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          _SquareButton(
            icon: Icons.check_rounded,
            color: _PickerColors.blue,
            onTap: _saveZone,
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _selectedCenter,
                  initialZoom: 16,
                  onTap: (_, point) {
                    setState(() => _selectedCenter = point);
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
                        color: _PickerColors.blue.withValues(alpha: .2),
                        borderColor: _PickerColors.lightBlue,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedCenter,
                        width: 62,
                        height: 62,
                        child: const Icon(
                          Icons.location_pin,
                          size: 52,
                          color: _PickerColors.red,
                        ),
                      ),
                      Marker(
                        point: _currentUserLocation,
                        width: 42,
                        height: 42,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _PickerColors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(
                            Icons.my_location_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: _PickerGlassCard(
                borderRadius: 18,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const _StaticSquareIcon(
                      icon: Icons.home_rounded,
                      color: _PickerColors.amber,
                      size: 42,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ZONE NAME',
                            style: TextStyle(
                              color: _PickerColors.muted,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          TextField(
                            controller: _nameController,
                            cursorColor: _PickerColors.lightBlue,
                            style: const TextStyle(
                              color: _PickerColors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Safe Zone Name',
                              hintStyle: TextStyle(color: _PickerColors.muted),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.only(top: 3),
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
              right: 14,
              bottom: 14,
              child: _SquareButton(
                icon: Icons.my_location_rounded,
                color: _PickerColors.blue,
                onTap: _goToCurrentLocation,
              ),
            ),
            const Positioned(left: 14, bottom: 14, child: _MapHint()),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(String radiusLabel) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        14 + MediaQuery.paddingOf(context).bottom,
      ),
      child: _PickerGlassCard(
        borderRadius: 24,
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _StaticSquareIcon(
                  icon: Icons.radio_button_checked_rounded,
                  color: _PickerColors.amber,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Zone Radius',
                        style: TextStyle(
                          color: _PickerColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$radiusLabel meters',
                        style: const TextStyle(
                          color: _PickerColors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(_radius / 1000).toStringAsFixed(2)} km',
                  style: const TextStyle(
                    color: _PickerColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _PickerColors.blue,
                inactiveTrackColor: Colors.white.withValues(alpha: .12),
                thumbColor: _PickerColors.lightBlue,
                overlayColor: _PickerColors.blue.withValues(alpha: .15),
                trackHeight: 5,
              ),
              child: Slider(
                value: _radius,
                min: 50,
                max: 500,
                divisions: 18,
                label: '$radiusLabel m',
                onChanged: (value) => setState(() => _radius = value),
              ),
            ),
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: _PickerColors.red,
                  size: 18,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '${_selectedCenter.latitude.toStringAsFixed(5)}, '
                    '${_selectedCenter.longitude.toStringAsFixed(5)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _PickerColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _saveZone,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Save'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _PickerColors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerGlassCard extends StatelessWidget {
  const _PickerGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFD7E0EB).withValues(alpha: .17),
                const Color(0xFF7088AD).withValues(alpha: .14),
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
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _StaticSquareIcon extends StatelessWidget {
  const _StaticSquareIcon({
    required this.icon,
    required this.color,
    this.size = 44,
  });

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

class _MapHint extends StatelessWidget {
  const _MapHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: _PickerColors.surface.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.touch_app_outlined,
            color: _PickerColors.lightBlue,
            size: 16,
          ),
          SizedBox(width: 6),
          Text(
            'Tap map to move',
            style: TextStyle(
              color: _PickerColors.text,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerLayeredBackground extends StatelessWidget {
  const _PickerLayeredBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: _PickerColors.background),
            Positioned(
              top: -210,
              left: -210,
              child: Transform.rotate(
                angle: -.28,
                child: Container(
                  width: 410,
                  height: 980,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(80),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF9AA8BA),
                        Color(0xFF425064),
                        Color(0xFF172131),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -150,
              right: -235,
              child: Transform.rotate(
                angle: .2,
                child: Container(
                  width: 430,
                  height: 1050,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(86),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.fromARGB(255, 164, 173, 186),
                        Color.fromARGB(255, 74, 84, 100),
                        Color.fromARGB(255, 32, 39, 50),
                      ],
                      stops: [0, .46, 1],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _PickerColors.background.withValues(alpha: .2),
                      _PickerColors.background.withValues(alpha: .58),
                      _PickerColors.background.withValues(alpha: .9),
                    ],
                    stops: const [0, .55, 1],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
