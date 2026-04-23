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

  Future<void> _acknowledgeAlert() async {
    setState(() => _busy = true);

    try {
      final alert = await _getCurrentAlert();
      if (alert == null) {
        throw Exception("No active SOS alert found");
      }

      await _firestoreService.acknowledgeAlert(alert.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert acknowledged')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to acknowledge alert: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolveAlert() async {
    setState(() => _busy = true);

    try {
      final alert = await _getCurrentAlert();
      if (alert == null) {
        throw Exception("No active SOS alert found");
      }

      await _firestoreService.resolveAlert(alert.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert marked as resolved')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resolve alert: $e')),
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

  @override
  Widget build(BuildContext context) {
    final Color mainColor = widget.sosActive ? Colors.red : Colors.green;
    final Color lightColor =
        widget.sosActive ? Colors.red.shade100 : Colors.green.shade100;
    final String heading =
        widget.sosActive ? 'EMERGENCY ALERT IS ACTIVE' : 'EMERGENCY ALERT IS INACTIVE';

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Status'),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<AlertModel?>(
        future: _getCurrentAlert(),
        builder: (context, snapshot) {
          final alert = snapshot.data;
          final currentStatus = alert?.status ?? (widget.sosActive ? 'active' : 'resolved');
          final statusColor = _statusColor(currentStatus);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: lightColor,
                    borderRadius: BorderRadius.circular(16),
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
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(widget.userName),
                    subtitle: const Text('Tracked user'),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.location_on, color: mainColor),
                    title: const Text('Location'),
                    subtitle: Text('Lat: ${widget.lat}, Lng: ${widget.lng}'),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.battery_full, color: Colors.orange),
                    title: const Text('Device Battery'),
                    subtitle: Text('${widget.batteryLevel}%'),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.phone, color: Colors.blue),
                        title: const Text('Call User'),
                        subtitle: const Text('Dial the tracked user'),
                        onTap: _busy ? null : () => _callNumber('0712345678'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.local_hospital, color: Colors.red),
                        title: const Text('Call Emergency Services'),
                        subtitle: const Text('Dial emergency services'),
                        onTap: _busy ? null : () => _callNumber('119'),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _busy ? null : () => _openInMaps(context),
                    icon: const Icon(Icons.map),
                    label: const Text('Open in Maps'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy || currentStatus != 'active'
                            ? null
                            : _acknowledgeAlert,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Acknowledge'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _busy ||
                                (currentStatus != 'active' &&
                                    currentStatus != 'acknowledged')
                            ? null
                            : _resolveAlert,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.done_all),
                        label: const Text('Resolved'),
                      ),
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