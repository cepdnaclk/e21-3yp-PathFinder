import 'package:flutter/material.dart';
import '../../models/alert_model.dart';
import '../../services/firestore_service.dart';
import 'alert_detail_screen.dart';

class AlertHistoryScreen extends StatelessWidget {
  const AlertHistoryScreen({super.key});

  String _formatTimestamp(AlertModel alert) {
    final dt = alert.timestamp?.toDate();
    if (dt == null) return 'No time available';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert History'),
      ),
      body: StreamBuilder<List<AlertModel>>(
        stream: firestoreService.getAlertHistoryStream(),
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
              child: Text('No alerts found'),
            );
          }

          return ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];

              final isSos = alert.type == 'sos';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSos ? Colors.red.shade100 : Colors.grey.shade300,
                    child: Icon(
                      isSos ? Icons.warning : Icons.notifications,
                      color: isSos ? Colors.red : Colors.black54,
                    ),
                  ),
                  title: Text('${alert.userName} - ${alert.type.toUpperCase()}'),
                  subtitle: Text(_formatTimestamp(alert)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AlertDetailScreen(alert: alert),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}