import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WebSosHistoryPage extends StatelessWidget {
  const WebSosHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('No user signed in'));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('caretakers')
          .doc(user.uid)
          .snapshots(),
      builder: (context, caretakerSnapshot) {
        if (caretakerSnapshot.hasError) {
          return Center(
            child: Text(
              'Failed to load caretaker data: ${caretakerSnapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!caretakerSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final caretakerData = caretakerSnapshot.data?.data();
        final deviceId = caretakerData?['deviceId']?.toString();

        if (deviceId == null || deviceId.isEmpty) {
          return const Center(child: Text('No linked device found.'));
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('alerts')
              .where('deviceId', isEqualTo: deviceId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Failed to load SOS history: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final alerts = snapshot.data!.docs;

            alerts.sort((a, b) {
              final aTime = _getTime(a.data());
              final bTime = _getTime(b.data());
              return bTime.compareTo(aTime);
            });

            return Container(
              color: const Color(0xFFF3F4F6),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SOS History',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Recorded SOS alerts for device $deviceId.',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 30),

                    if (alerts.isEmpty)
                      _emptyView()
                    else
                      Column(
                        children: [
                          _summaryCard(alerts.length),
                          const SizedBox(height: 22),
                          ...alerts.map(
                            (doc) => _alertCard(context, doc.data()),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _summaryCard(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.orange.withOpacity(0.12),
            child: const Icon(
              Icons.notifications_active,
              color: Colors.orange,
              size: 32,
            ),
          ),
          const SizedBox(width: 18),
          Text(
            '$count SOS Alerts Recorded',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: Colors.green.withOpacity(0.12),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 52,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No SOS Alerts Found',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This device has no recorded SOS alerts yet.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _alertCard(BuildContext context, Map<String, dynamic> alert) {
    final type = alert['type']?.toString() ?? 'sos';
    final userName = alert['userName']?.toString() ?? 'Unknown user';
    final batteryLevel = alert['batteryLevel']?.toString() ?? '-';
    final lat = _toDouble(alert['lat']);
    final lng = _toDouble(alert['lng']);
    final createdAt = alert['createdAt'] ?? alert['timestamp'];

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.red.withOpacity(0.12),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 36,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _typeLabel(type),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 22,
                  runSpacing: 10,
                  children: [
                    _miniDetail(Icons.battery_full, 'Battery', '$batteryLevel%'),
                    _miniDetail(Icons.location_on, 'Lat', lat.toString()),
                    _miniDetail(Icons.location_on, 'Lng', lng.toString()),
                    _miniDetail(
                      Icons.access_time,
                      'Time',
                      createdAt is Timestamp
                          ? createdAt.toDate().toString()
                          : 'Unavailable',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          ElevatedButton.icon(
            onPressed: lat != 0 && lng != 0
                ? () => _openGoogleMaps(lat, lng)
                : null,
            icon: const Icon(Icons.map),
            label: const Text('Open Map'),
          ),
        ],
      ),
    );
  }

  Widget _miniDetail(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'sos':
        return 'SOS Alert';
      case 'low_battery':
        return 'Low Battery';
      case 'safe_zone_exit':
        return 'Safe Zone Exit';
      default:
        return type.toUpperCase();
    }
  }

  static DateTime _getTime(Map<String, dynamic> data) {
    final createdAt = data['createdAt'] ?? data['timestamp'];

    if (createdAt is Timestamp) {
      return createdAt.toDate();
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }
}