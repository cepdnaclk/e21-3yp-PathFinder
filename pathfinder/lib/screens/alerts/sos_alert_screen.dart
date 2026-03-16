import 'package:flutter/material.dart';
import 'package:map_launcher/map_launcher.dart';

class SosAlertScreen extends StatelessWidget {
  final String userName;
  final double lat;
  final double lng;
  final int batteryLevel;
  final bool sosActive;

  const SosAlertScreen({
    super.key,
    required this.userName,
    required this.lat,
    required this.lng,
    required this.batteryLevel,
    required this.sosActive,
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
      coords: Coords(lat, lng),
      title: userName,
      description: sosActive ? 'Emergency location' : 'Last known location',
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color mainColor = sosActive ? Colors.red : Colors.green;
    final Color lightColor = sosActive ? Colors.red.shade100 : Colors.green.shade100;
    final String heading =
        sosActive ? 'EMERGENCY ALERT IS ACTIVE' : 'EMERGENCY ALERT IS INACTIVE';

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Status'),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
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
                    sosActive ? Icons.warning_amber_rounded : Icons.check_circle,
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
                ],
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(userName),
                subtitle: const Text('Tracked user'),
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.location_on, color: mainColor),
                title: const Text('Location'),
                subtitle: Text('Lat: $lat, Lng: $lng'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.battery_full, color: Colors.orange),
                title: const Text('Device Battery'),
                subtitle: Text('$batteryLevel%'),
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