import 'package:flutter/material.dart';
import '../../models/alert_model.dart';
import '../../services/firestore_service.dart';

class AlertHistoryScreen extends StatelessWidget {
  final String deviceId;

  const AlertHistoryScreen({
    super.key,
    required this.deviceId,
  });

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
                  leading: const Icon(Icons.warning, color: Colors.red),
                  title: Text(alert.userName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Device: ${alert.deviceId}'),
                      Text('Battery: ${alert.batteryLevel}%'),
                      Text('Lat: ${alert.lat}, Lng: ${alert.lng}'),
                      const Text('Timestamp unavailable'),
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