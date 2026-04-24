import 'package:flutter/material.dart';
import 'package:map_launcher/map_launcher.dart';
import '../../models/alert_model.dart';

class AlertDetailScreen extends StatelessWidget {
  final AlertModel alert;

  const AlertDetailScreen({
    super.key,
    required this.alert,
  });

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
      coords: Coords(alert.lat, alert.lng),
      title: alert.userName,
      description: 'Alert location',
    );
  }

  String _formatTimestamp() {
    final dt = alert.timestamp?.toDate();
    if (dt == null) return 'No time available';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isSos = alert.type == 'sos';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              color: isSos ? Colors.red.shade50 : null,
              child: ListTile(
                leading: Icon(
                  isSos ? Icons.warning : Icons.notifications,
                  color: isSos ? Colors.red : Colors.black54,
                ),
                title: Text(alert.type.toUpperCase()),
                subtitle: Text('Status: ${alert.status}'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: const Text('User'),
                subtitle: Text(alert.userName),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Timestamp'),
                subtitle: Text(_formatTimestamp()),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('Location'),
                subtitle: Text('Lat: ${alert.lat}, Lng: ${alert.lng}'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.battery_full),
                title: const Text('Battery Level'),
                subtitle: Text('${alert.batteryLevel}%'),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () => _openInMaps(context),
                icon: const Icon(Icons.map),
                label: const Text('Open in Maps'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}