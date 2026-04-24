import 'package:flutter/material.dart';
import '../../models/alert_model.dart';
import '../../services/firestore_service.dart';

class AlertHistoryScreen extends StatelessWidget {
  final String deviceId;

  const AlertHistoryScreen({
    super.key,
    required this.deviceId,
  });

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

  IconData _typeIcon(String type) {
    switch (type) {
      case 'low_battery':
        return Icons.battery_alert;
      case 'safe_zone_exit':
        return Icons.location_off;
      case 'sos':
      default:
        return Icons.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert History'),
      ),
      body: StreamBuilder<List<AlertModel>>(
        stream: firestoreService.getAlertHistoryStream(deviceId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final alerts = snapshot.data!;

          if (alerts.isEmpty) {
            return const Center(
              child: Text('No alerts found for this device'),
            );
          }

          return ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Icon(
                    _typeIcon(alert.type),
                    color: _statusColor(alert.status),
                  ),
                  title: Text('${alert.userName} • ${alert.type.toUpperCase()}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Device: ${alert.deviceId}'),
                      Text('Battery: ${alert.batteryLevel}%'),
                      Text('Lat: ${alert.lat}, Lng: ${alert.lng}'),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              alert.status.toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                            backgroundColor: _statusColor(alert.status),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert.createdAt != null
                            ? 'Created: ${alert.createdAt!.toDate()}'
                            : 'Created: unavailable',
                      ),
                      if (alert.acknowledgedAt != null)
                        Text('Acknowledged: ${alert.acknowledgedAt!.toDate()}'),
                      if (alert.resolvedAt != null)
                        Text('Resolved: ${alert.resolvedAt!.toDate()}'),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}