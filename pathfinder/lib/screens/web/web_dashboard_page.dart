import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'widgets/web_stat_card.dart';

class WebDashboardPage extends StatelessWidget {
  const WebDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 700;

    if (user == null) {
      return const Center(child: Text('No user signed in'));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('caretakers')
          .doc(user.uid)
          .snapshots(),
      builder: (context, caretakerSnapshot) {
        if (!caretakerSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final caretakerData = caretakerSnapshot.data!.data();
        final deviceId = caretakerData?['deviceId']?.toString();

        if (deviceId == null || deviceId.isEmpty) {
          return const Center(
            child: Text('No linked device found for this caretaker.'),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('devices')
              .doc(deviceId)
              .snapshots(),
          builder: (context, deviceSnapshot) {
            if (!deviceSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final deviceData = deviceSnapshot.data!.data();

            if (deviceData == null) {
              return Center(child: Text('Device not found: $deviceId'));
            }

            final bool online = deviceData['online'] == true;
            final int batteryLevel = _toInt(deviceData['batteryLevel']);
            final double gpsLat = _toDouble(deviceData['gpsLat']);
            final double gpsLng = _toDouble(deviceData['gpsLng']);
            final String cameraStreamUrl =
                deviceData['cameraStreamUrl']?.toString() ?? '';
            final Timestamp? lastUpdated = deviceData['lastUpdated'];

            final bool locationAvailable = gpsLat != 0 && gpsLng != 0;

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('alerts')
                  .where('deviceId', isEqualTo: deviceId)
                  .snapshots(),
              builder: (context, alertSnapshot) {
                final alerts = alertSnapshot.data?.docs ?? [];

                final sortedAlerts = [...alerts];
                sortedAlerts.sort((a, b) {
                  final aTime = _getAlertTime(a.data());
                  final bTime = _getAlertTime(b.data());
                  return bTime.compareTo(aTime);
                });

                final activeAlerts = sortedAlerts.where((doc) {
                  final data = doc.data();
                  final type = data['type']?.toString().toLowerCase();
                  final status = data['status']?.toString().toLowerCase();
                  final resolved = data['resolved'];

                  if (type == 'sos') return true;
                  if (resolved == false) return true;
                  if (status == 'active') return true;
                  if (status == 'pending') return true;

                  return false;
                }).toList();

                final bool sosActive = deviceData['sosActive'] == true;
                final latestAlert =
                    sortedAlerts.isNotEmpty ? sortedAlerts.first.data() : null;

                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFF8FAFC),
                        Color(0xFFF1F5F9),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(34),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dashboard',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Live monitoring overview for device $deviceId.',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 30),

                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: isSmallScreen ? 1 : 2,
                          childAspectRatio: isSmallScreen ? 2.0 : 2.4,
                          crossAxisSpacing: 22,
                          mainAxisSpacing: 22,
                          children: [
                            WebStatCard(
                              icon: Icons.sensors,
                              title: 'Device',
                              value: online ? 'Online' : 'Offline',
                              color: online ? Colors.green : Colors.red,
                            ),
                            WebStatCard(
                              icon: Icons.warning,
                              title: 'SOS Status',
                              value: (deviceData['sosActive'] == true) ? 'Active' : 'Inactive',
                              color: (deviceData['sosActive'] == true) ? Colors.red : Colors.green,
                              onTap: () {
                                if (!sosActive) {
                                    _showInfoDialog(
                                      context,
                                      title: 'SOS Status',
                                      content: 'SOS is currently inactive. No emergency action is required.',
                                    );
                                    return;
                                }
                                if (latestAlert == null) {
                                  _showInfoDialog(
                                    context,
                                    title: 'SOS Status',
                                    content: 'No SOS alerts found.',
                                  );
                                } else {
                                  _showAlertDialog(context, latestAlert,deviceId);
                                }
                              },
                            ),
                            WebStatCard(
                              icon: Icons.battery_full,
                              title: 'Battery',
                              value: '$batteryLevel%',
                              color: batteryLevel > 60
                                  ? Colors.green
                                  : batteryLevel > 30
                                      ? Colors.orange
                                      : Colors.red,
                              isBattery: true,
                              batteryLevel: batteryLevel,
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: isSmallScreen ? 1 : 2,
                          childAspectRatio: isSmallScreen ? 1.25 : 1.55,
                          crossAxisSpacing: 22,
                          mainAxisSpacing: 22,
                          children: [
                            _ActionCard(
                              icon: Icons.location_on,
                              title: 'Live Location',
                              subtitle: locationAvailable
                                  ? 'Lat: $gpsLat\nLng: $gpsLng'
                                  : 'Location unavailable',
                              color: Colors.purple,
                              buttonText: 'Open Google Maps',
                              onTap: locationAvailable
                                  ? () => _openGoogleMaps(gpsLat, gpsLng)
                                  : null,
                            ),
                            _ActionCard(
                              icon: Icons.videocam,
                              title: 'Live Camera',
                              subtitle: cameraStreamUrl.isNotEmpty
                                  ? 'Camera stream available'
                                  : 'No camera URL available',
                              color: Colors.indigo,
                              buttonText: 'Open Camera',
                              onTap: cameraStreamUrl.isNotEmpty
                                  ? () => _openUrl(cameraStreamUrl)
                                  : null,
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        Container(
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
                              const Icon(
                                Icons.update,
                                color: Colors.black45,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  lastUpdated == null
                                      ? 'Last updated: unavailable'
                                      : 'Last updated: ${lastUpdated.toDate()}',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
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

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

void _showAlertDialog(
  BuildContext context,
  Map<String, dynamic> alert,
  String deviceId,
) {
  final type = alert['type']?.toString().toUpperCase() ?? 'SOS';
  final userName = alert['userName']?.toString() ?? 'Unknown user';
  final batteryLevel = alert['batteryLevel']?.toString() ?? '-';
  final lat = _toDouble(alert['lat']);
  final lng = _toDouble(alert['lng']);
  final createdAt = alert['createdAt'] ?? alert['timestamp'];

  showDialog(
    context: context,
    builder: (_) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.red.withOpacity(0.12),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 14),
            Text(type),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogRow(Icons.person, 'User', userName),
              _dialogRow(Icons.devices, 'Device', deviceId),
              _dialogRow(Icons.battery_full, 'Battery', '$batteryLevel%'),
              _dialogRow(
                Icons.access_time,
                'Time',
                createdAt is Timestamp
                    ? createdAt.toDate().toString()
                    : 'Unavailable',
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: lat != 0 && lng != 0
                      ? () => _openGoogleMaps(lat, lng)
                      : null,
                  icon: const Icon(Icons.map),
                  label: const Text('Open Location in Google Maps'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('devices')
                        .doc(deviceId)
                        .update({'sosActive': false});

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('SOS marked as notified'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Notified - Set SOS Inactive'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

Widget _dialogRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blueGrey),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black54,
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
    ),
  );
}

  void _showInfoDialog(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(title),
          content: SelectableText(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  static DateTime _getAlertTime(Map<String, dynamic> data) {
    final createdAt = data['createdAt'] ?? data['timestamp'];

    if (createdAt is Timestamp) {
      return createdAt.toDate();
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final Color color;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 700;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering && enabled ? 1.03 : 1,
        duration: const Duration(milliseconds: 180),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(30),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _hovering && enabled
                  ? const Color(0xFF111827)
                  : Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: _hovering && enabled
                      ? widget.color.withOpacity(0.25)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: _hovering && enabled ? 30 : 20,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.color,
                  size: 22,
                ),
              ),
                const Spacer(),
                Text(
                  widget.title,
                  style: TextStyle(
                    color: _hovering && enabled ? Colors.white : Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    color:
                        _hovering && enabled ? Colors.white70 : Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  enabled ? widget.buttonText : 'Unavailable',
                  style: TextStyle(
                    color:
                        _hovering && enabled ? Colors.white : widget.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}