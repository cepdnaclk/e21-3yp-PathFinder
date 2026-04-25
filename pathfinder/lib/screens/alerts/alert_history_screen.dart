import 'package:flutter/material.dart';
import '../../models/alert_model.dart';
import '../../services/firestore_service.dart';

class AlertHistoryScreen extends StatelessWidget {
  final String deviceId;

  const AlertHistoryScreen({
    super.key,
    required this.deviceId,
  });

  Future<void> _clearHistory(BuildContext context) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Clear History"),
        content: const Text(
          "Are you sure you want to delete ALL alert history?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      );
    },
  );

  if (confirm != true) return;

  try {
    await FirestoreService().deleteAllAlerts(deviceId);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Alert history cleared")),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Failed: $e")),
    );
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

  IconData _typeIcon(String type) {
    switch (type) {
      case 'low_battery':
        return Icons.battery_alert;
      case 'safe_zone_exit':
        return Icons.location_off;
      case 'sos':
      default:
        return Icons.warning_amber_rounded;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'low_battery':
        return 'Low Battery';
      case 'safe_zone_exit':
        return 'Safe Zone Exit';
      case 'sos':
        return 'SOS Alert';
      default:
        return type.toUpperCase();
    }
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

  Widget _emptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.green.withOpacity(0.10),
                child: const Icon(
                  Icons.check_circle,
                  size: 50,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Alerts Found',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This device has no recorded alerts yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _alertCard(AlertModel alert) {
    final statusColor = _statusColor(alert.status);
    final typeIcon = _typeIcon(alert.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: statusColor.withOpacity(0.10),
                child: Icon(typeIcon, color: statusColor, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _typeLabel(alert.type),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.userName,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(
                  alert.status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
                backgroundColor: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1EC),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                _detailRow(
                  icon: Icons.devices,
                  label: 'Device',
                  value: alert.deviceId,
                ),
                const SizedBox(height: 10),
                _detailRow(
                  icon: Icons.battery_full,
                  label: 'Battery',
                  value: '${alert.batteryLevel}%',
                ),
                const SizedBox(height: 10),
                _detailRow(
                  icon: Icons.location_on,
                  label: 'Location',
                  value:
                      '${alert.lat.toStringAsFixed(6)}, ${alert.lng.toStringAsFixed(6)}',
                ),
                const SizedBox(height: 10),
                _detailRow(
                  icon: Icons.access_time,
                  label: 'Created',
                  value: alert.createdAt != null
                      ? alert.createdAt!.toDate().toString()
                      : 'Unavailable',
                ),
                if (alert.acknowledgedAt != null) ...[
                  const SizedBox(height: 10),
                  _detailRow(
                    icon: Icons.check_circle_outline,
                    label: 'Acknowledged',
                    value: alert.acknowledgedAt!.toDate().toString(),
                  ),
                ],
                if (alert.resolvedAt != null) ...[
                  const SizedBox(height: 10),
                  _detailRow(
                    icon: Icons.done_all,
                    label: 'Resolved',
                    value: alert.resolvedAt!.toDate().toString(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: Colors.blueGrey),
        const SizedBox(width: 10),
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

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
                    'Alert History',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),

                  // 🔥 NEW DELETE BUTTON
                  _topButton(
                    icon: Icons.delete_outline,
                    onTap: () => _clearHistory(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<AlertModel>>(
                stream: firestoreService.getAlertHistoryStream(deviceId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Error: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final alerts = snapshot.data!;

                  if (alerts.isEmpty) {
                    return _emptyView();
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.orange.withOpacity(0.10),
                              child: const Icon(
                                Icons.notifications_active,
                                color: Colors.orange,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${alerts.length} Alerts Recorded',
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Device: $deviceId',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      ...alerts.map(_alertCard),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}