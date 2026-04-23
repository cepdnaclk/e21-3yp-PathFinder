import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../auth/login_screen.dart';
import '../auth/link_device_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String deviceId;

  const SettingsScreen({
    super.key,
    required this.deviceId,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = false;
  Map<String, dynamic>? _caretakerData;
  Map<String, dynamic>? _deviceData;
  String? _error;

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _loadSettingsData();
  }

  Future<void> _loadSettingsData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("No logged in user");
      }

      final caretakerData = await _firestoreService.getCaretakerData(user.uid);
      final deviceData = await _firestoreService.getDeviceData(widget.deviceId);

      if (!mounted) return;

      setState(() {
        _caretakerData = caretakerData;
        _deviceData = deviceData;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await AuthService().signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _unlinkDevice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Unlink Device"),
          content: const Text(
            "Are you sure you want to unlink this device from your caretaker account?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Unlink"),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _loading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("No logged in user");

      await _firestoreService.unlinkCaretakerFromDevice(
        uid: user.uid,
        deviceId: widget.deviceId,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LinkDeviceScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to unlink device: $e")),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _markSafeZone() async {
    final nameController = TextEditingController(
      text: _deviceData?['safeZone']?['name']?.toString() ?? 'Home',
    );
    final radiusController = TextEditingController(
      text: _deviceData?['safeZone']?['radius']?.toString() ?? '100',
    );

    final lat = (_deviceData?['gpsLat'] ?? 0).toDouble();
    final lng = (_deviceData?['gpsLng'] ?? 0).toDouble();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Mark Safe Zone"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "The current device location will be saved as the safe zone center.",
              ),
              const SizedBox(height: 12),
              Text("Current Lat: $lat"),
              Text("Current Lng: $lng"),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Safe Zone Name",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: radiusController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Radius (meters)",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final radius = double.tryParse(radiusController.text.trim()) ?? 100;

      await _firestoreService.saveSafeZone(
        deviceId: widget.deviceId,
        name: nameController.text.trim().isEmpty
            ? 'Home'
            : nameController.text.trim(),
        lat: lat,
        lng: lng,
        radius: radius,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Safe zone saved")),
      );

      await _loadSettingsData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save safe zone: $e")),
      );
    }
  }

  Future<void> _removeSafeZone() async {
    try {
      await _firestoreService.removeSafeZone(widget.deviceId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Safe zone removed")),
      );

      await _loadSettingsData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to remove safe zone: $e")),
      );
    }
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
    Color? iconColor,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final safeZone = _deviceData?['safeZone'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text("Error: $_error"))
              : RefreshIndicator(
                  onRefresh: _loadSettingsData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: user?.photoURL != null
                                ? NetworkImage(user!.photoURL!)
                                : null,
                            child: user?.photoURL == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(user?.displayName ?? "Caretaker"),
                          subtitle: Text(user?.email ?? ""),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Account",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _infoCard(
                        icon: Icons.person,
                        title: "Caretaker Name",
                        value: (_caretakerData?['name'] ??
                                user?.displayName ??
                                'Unknown')
                            .toString(),
                      ),
                      _infoCard(
                        icon: Icons.email,
                        title: "Email",
                        value: (_caretakerData?['email'] ??
                                user?.email ??
                                'Unknown')
                            .toString(),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Linked Device",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _infoCard(
                        icon: Icons.devices,
                        title: "Device ID",
                        value: widget.deviceId,
                        iconColor: Colors.blue,
                      ),
                      _infoCard(
                        icon: Icons.circle,
                        title: "Status",
                        value: (_deviceData?['online'] == true) ? 'Online' : 'Offline',
                        iconColor: (_deviceData?['online'] == true)
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Safe Zone",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (safeZone != null) ...[
                        _infoCard(
                          icon: Icons.home,
                          title: "Zone Name",
                          value: (safeZone['name'] ?? 'Unknown').toString(),
                        ),
                        _infoCard(
                          icon: Icons.radio_button_checked,
                          title: "Radius",
                          value: "${(safeZone['radius'] ?? 0).toString()} meters",
                        ),
                        _infoCard(
                          icon: Icons.location_on,
                          title: "Center",
                          value:
                              "Lat: ${safeZone['lat']}, Lng: ${safeZone['lng']}",
                        ),
                      ] else
                        const Card(
                          child: ListTile(
                            leading: Icon(Icons.location_off),
                            title: Text("No safe zone set"),
                          ),
                        ),
                      const SizedBox(height: 24),
                      const Text(
                        "Actions",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.my_location, color: Colors.blue),
                          title: const Text("Mark Safe Zone"),
                          subtitle: const Text(
                            "Use current device location as safe zone center",
                          ),
                          onTap: _markSafeZone,
                        ),
                      ),
                      if (safeZone != null)
                        Card(
                          child: ListTile(
                            leading:
                                const Icon(Icons.delete_outline, color: Colors.orange),
                            title: const Text("Remove Safe Zone"),
                            subtitle: const Text("Delete current safe zone"),
                            onTap: _removeSafeZone,
                          ),
                        ),
                      Card(
                        child: ListTile(
                          leading:
                              const Icon(Icons.sync_disabled, color: Colors.orange),
                          title: const Text("Unlink Device"),
                          subtitle: const Text(
                            "Remove this device from this caretaker account",
                          ),
                          onTap: _unlinkDevice,
                        ),
                      ),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text("Sign Out"),
                          subtitle: const Text("Log out from this app"),
                          onTap: _logout,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}