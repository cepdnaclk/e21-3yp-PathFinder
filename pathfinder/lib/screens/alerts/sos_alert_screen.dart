import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  String _userContactNumber = '';
  String _emergencyContactNumber = '';

  @override
  void initState() {
    super.initState();
    _loadContactNumbers();
  }

  Future<void> _loadContactNumbers() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final caretakerData = await _firestoreService.getCaretakerData(user.uid);
      if (!mounted || caretakerData == null) return;

      setState(() {
        _userContactNumber =
            (caretakerData['userContactNumber'] ?? '').toString().trim();
        _emergencyContactNumber =
            (caretakerData['emergencyContactNumber'] ?? '').toString().trim();
      });
    } catch (_) {
      // Ignore contact load failures; call actions will show a fallback message.
    }
  }

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

  Future<void> _callEmergencyContact() async {
    if (_emergencyContactNumber.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No emergency contact number set. Add it in Settings.'),
        ),
      );
      return;
    }

    await _callNumber(_emergencyContactNumber);
  }

  Future<void> _showCallOptions() async {
    if (_userContactNumber.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No user contact number set. Add it in Settings.'),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              const Text(
                'Call User',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('User Contact'),
                subtitle: Text(_userContactNumber),
                onTap: () async {
                  Navigator.pop(context);
                  await _callNumber(_userContactNumber);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
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

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: color.withOpacity(0.10),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _callCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: color.withOpacity(0.10),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 5),
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

  Widget _locationCard(Color mainColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: mainColor.withOpacity(0.10),
            child: Icon(Icons.location_on, color: mainColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Emergency Location',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Lat: ${widget.lat.toStringAsFixed(6)}\nLng: ${widget.lng.toStringAsFixed(6)}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 48,
            width: 1,
            color: Colors.grey.shade300,
          ),
          const SizedBox(width: 12),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _busy ? null : () => _openInMaps(context),
            child: Column(
              children: const [
                Icon(Icons.navigation, color: Colors.blue),
                SizedBox(height: 4),
                Text('Open', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomPanel({
    required Color mainColor,
    required String currentStatus,
    required Color statusColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Emergency Actions',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Chip(
                label: Text(
                  currentStatus.toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _callCard(
                icon: Icons.phone,
                color: Colors.blue,
                title: 'Call User',
                subtitle: 'Choose saved contact',
                onTap: _busy ? null : _showCallOptions,
              ),
              const SizedBox(width: 12),
              _callCard(
                icon: Icons.local_hospital,
                color: Colors.red,
                title: 'Emergency',
                subtitle: 'Call emergency contact',
                onTap: _busy ? null : _callEmergencyContact,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: mainColor,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: _busy ? null : () => _openInMaps(context),
              icon: const Icon(Icons.map),
              label: const Text('Open Location in Maps'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy || !widget.sosActive ? null : _turnOffSos,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide(color: mainColor),
                foregroundColor: mainColor,
              ),
              icon: const Icon(Icons.power_settings_new),
              label: const Text('Set SOS Inactive'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color mainColor = widget.sosActive ? Colors.red : Colors.green;
    final Color softBackground =
        widget.sosActive ? const Color(0xFFF4D9DD) : const Color(0xFFE4F4EA);
    final String heading =
        widget.sosActive ? 'Emergency Alert' : 'Emergency Inactive';

    return Scaffold(
      backgroundColor: softBackground,
      body: SafeArea(
        child: FutureBuilder<AlertModel?>(
          future: _getCurrentAlert(),
          builder: (context, snapshot) {
            final alert = snapshot.data;
            final currentStatus =
                alert?.status ?? (widget.sosActive ? 'active' : 'resolved');
            final statusColor = _statusColor(currentStatus);

            return Column(
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
                        'SOS Status',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      _topButton(
                        icon: Icons.map,
                        onTap: () => _openInMaps(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
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
                            children: [
                              CircleAvatar(
                                radius: 42,
                                backgroundColor: mainColor.withOpacity(0.10),
                                child: Icon(
                                  widget.sosActive
                                      ? Icons.warning_amber_rounded
                                      : Icons.check_circle,
                                  size: 54,
                                  color: mainColor,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                heading,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: mainColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.sosActive
                                    ? '${widget.userName} needs assistance.'
                                    : 'No active emergency at the moment.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
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
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _infoCard(
                              icon: Icons.person,
                              label: 'Tracked User',
                              value: widget.userName,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 12),
                            _infoCard(
                              icon: Icons.battery_full,
                              label: 'Battery',
                              value: '${widget.batteryLevel}%',
                              color: widget.batteryLevel > 30
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _locationCard(mainColor),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                _bottomPanel(
                  mainColor: mainColor,
                  currentStatus: currentStatus,
                  statusColor: statusColor,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}