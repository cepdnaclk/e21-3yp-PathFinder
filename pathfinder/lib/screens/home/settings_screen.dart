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
      if (user == null) throw Exception("No logged in user");

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
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _editSosContactNumbers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userContactController = TextEditingController(
      text: (_caretakerData?['userContactNumber'] ?? '').toString(),
    );
    final emergencyContactController = TextEditingController(
      text: (_caretakerData?['emergencyContactNumber'] ?? '').toString(),
    );

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('SOS Contact Numbers'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userContactController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'User contact number',
                  hintText: 'e.g. 0712345678',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emergencyContactController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Emergency contact number',
                  hintText: 'e.g. 0771234567',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      userContactController.dispose();
      emergencyContactController.dispose();
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await _firestoreService.saveSosContactNumbers(
        uid: user.uid,
        userContactNumber: userContactController.text.trim(),
        emergencyContactNumber: emergencyContactController.text.trim(),
      );

      await _loadSettingsData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SOS contact numbers saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save contact numbers: $e')),
      );
    } finally {
      userContactController.dispose();
      emergencyContactController.dispose();
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EC),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.white,
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: color.withValues(alpha: 0.10),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Text(
            "Error: $_error",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final online = _deviceData?['online'] == true;

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
                    "Settings",
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  _topButton(
                    icon: Icons.refresh,
                    onTap: _loadSettingsData,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _errorView()
                      : RefreshIndicator(
                          onRefresh: _loadSettingsData,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 42,
                                      backgroundImage: user?.photoURL != null
                                          ? NetworkImage(user!.photoURL!)
                                          : null,
                                      child: user?.photoURL == null
                                          ? const Icon(Icons.person, size: 42)
                                          : null,
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      user?.displayName ?? "Caretaker",
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      user?.email ?? "",
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                "Account",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _infoTile(
                                icon: Icons.person,
                                title: "Caretaker Name",
                                value: (_caretakerData?['name'] ??
                                        user?.displayName ??
                                        'Unknown')
                                    .toString(),
                                color: Colors.blue,
                              ),
                              _infoTile(
                                icon: Icons.email,
                                title: "Email",
                                value: (_caretakerData?['email'] ??
                                        user?.email ??
                                        'Unknown')
                                    .toString(),
                                color: Colors.deepPurple,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "SOS Contacts",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _infoTile(
                                icon: Icons.phone,
                                title: "User Contact Number",
                                value: ((_caretakerData?['userContactNumber'] ?? '')
                                        .toString()
                                        .trim()
                                        .isEmpty)
                                    ? 'Not set'
                                    : (_caretakerData?['userContactNumber'] as String),
                                color: Colors.blue,
                              ),
                              _infoTile(
                                icon: Icons.contact_phone,
                                title: "Emergency Contact Number",
                                value: ((_caretakerData?['emergencyContactNumber'] ?? '')
                                        .toString()
                                        .trim()
                                        .isEmpty)
                                    ? 'Not set'
                                    : (_caretakerData?['emergencyContactNumber'] as String),
                                color: Colors.red,
                              ),
                              _actionTile(
                                icon: Icons.edit,
                                title: "Edit SOS Contact Numbers",
                                subtitle:
                                    "Set user and emergency numbers for SOS calls",
                                color: Colors.purple,
                                onTap: _editSosContactNumbers,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "Linked Device",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _infoTile(
                                icon: Icons.devices,
                                title: "Device ID",
                                value: widget.deviceId,
                                color: Colors.teal,
                              ),
                              _infoTile(
                                icon: Icons.circle,
                                title: "Device Status",
                                value: online ? 'Online' : 'Offline',
                                color: online ? Colors.green : Colors.red,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "Actions",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _actionTile(
                                icon: Icons.sync_disabled,
                                title: "Unlink Device",
                                subtitle:
                                    "Remove this device from this caretaker account",
                                color: Colors.orange,
                                onTap: _unlinkDevice,
                              ),
                              const SizedBox(height: 12),
                              _actionTile(
                                icon: Icons.logout,
                                title: "Sign Out",
                                subtitle: "Log out from this app",
                                color: Colors.red,
                                onTap: _logout,
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
