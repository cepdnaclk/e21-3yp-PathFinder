import 'package:flutter/material.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/alert_model.dart';
import '../../services/firestore_service.dart';

class SosAlertScreen extends StatefulWidget {
  final String deviceId;
  final String userName;
  final double lat;
  final double lng;
  final int batteryLevel;
  final bool sosActive;

  const SosAlertScreen({
    super.key,
    required this.deviceId,
    required this.userName,
    required this.lat,
    required this.lng,
    required this.batteryLevel,
    required this.sosActive,
  });

  @override
  State<SosAlertScreen> createState() => _SosAlertScreenState();
}

class _SosAlertScreenState extends State<SosAlertScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _busy = false;

  Future<void> _openInMaps(BuildContext context) async {
    final maps = await MapLauncher.installedMaps;

    if (maps.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No map apps found')),
      );
      return;
    }

    await maps.first.showMarker(
      coords: Coords(widget.lat, widget.lng),
      title: widget.userName,
      description:
          widget.sosActive ? 'Emergency location' : 'Last known location',
    );
  }

  Future<void> _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<AlertModel?> _getCurrentAlert() async {
    return _firestoreService.getLatestActiveSosAlert(widget.deviceId);
  }

  Future<void> _turnOffSos() async {
    setState(() => _busy = true);

    try {
      await _firestoreService.clearSosState(widget.deviceId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SOS deactivated')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to deactivate SOS: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'acknowledged':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'active':
      default:
        return Colors.red;
    }
  }

  Widget _infoMiniCard({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _callActionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color mainColor = widget.sosActive ? Colors.red : Colors.green;
    final Color lightColor =
        widget.sosActive ? Colors.red.shade100 : Colors.green.shade100;
    final String heading = widget.sosActive
        ? 'EMERGENCY ALERT IS ACTIVE'
        : 'EMERGENCY ALERT IS INACTIVE';

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Status'),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade100,
      body: FutureBuilder<AlertModel?>(
        future: _getCurrentAlert(),
        builder: (context, snapshot) {
          final alert = snapshot.data;
          final currentStatus =
              alert?.status ?? (widget.sosActive ? 'active' : 'resolved');
          final statusColor = _statusColor(currentStatus);

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: lightColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: mainColor, width: 2),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          widget.sosActive
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle,
                          size: 64,
                          color: mainColor,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          heading,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: mainColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Chip(
                          label: Text(
                            currentStatus.toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: statusColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      _infoMiniCard(
                        icon: Icons.person,
                        label: "Tracked User",
                        value: widget.userName,
                        iconColor: Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      _infoMiniCard(
                        icon: Icons.battery_full,
                        label: "Battery Level",
                        value: "${widget.batteryLevel}%",
                        iconColor: Colors.orange,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on, color: mainColor, size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Emergency Location",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Lat: ${widget.lat}\nLng: ${widget.lng}",
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

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      _callActionCard(
                        icon: Icons.phone,
                        color: Colors.blue,
                        title: "Call User",
                        subtitle: "Contact tracked person",
                        onTap: _busy ? null : () => _callNumber('0712345678'),
                      ),
                      const SizedBox(width: 12),
                      _callActionCard(
                        icon: Icons.local_hospital,
                        color: Colors.red,
                        title: "Emergency",
                        subtitle: "Call emergency services",
                        onTap: _busy ? null : () => _callNumber('119'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: _busy ? null : () => _openInMaps(context),
                      icon: const Icon(Icons.map),
                      label: const Text('Open in Maps'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy || !widget.sosActive ? null : _turnOffSos,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.power_settings_new),
                      label: const Text('Set SOS Inactive'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}