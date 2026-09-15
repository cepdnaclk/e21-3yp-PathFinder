import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'widgets/web_page_route.dart';

import 'web_shell.dart';

class WebLinkDevicePage extends StatefulWidget {
  final String? initialDeviceId;

  const WebLinkDevicePage({
    super.key,
    this.initialDeviceId,
  });

  @override
  State<WebLinkDevicePage> createState() => _WebLinkDevicePageState();
}

class _WebLinkDevicePageState extends State<WebLinkDevicePage> {
  final TextEditingController _deviceController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    if (widget.initialDeviceId != null) {
      _deviceController.text = widget.initialDeviceId!;
    }
  }

  @override
  void dispose() {
    _deviceController.dispose();
    super.dispose();
  }

  Future<void> _linkDevice() async {
    final user = FirebaseAuth.instance.currentUser;
    final deviceId = _deviceController.text.trim();

    if (user == null) return;

    if (deviceId.isEmpty) {
      setState(() => _error = 'Please enter your device ID.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final deviceRef =
          FirebaseFirestore.instance.collection('devices').doc(deviceId);

      final deviceDoc = await deviceRef.get();

      if (!deviceDoc.exists) {
        setState(() {
          _error = 'Device not found. Please check the device ID.';
        });
        return;
      }

      await FirebaseFirestore.instance
          .collection('caretakers')
          .doc(user.uid)
          .set({
        'name': user.displayName ?? 'Unknown User',
        'email': user.email ?? '',
        'photoUrl': user.photoURL,
        'deviceId': deviceId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await deviceRef.set({
        'ownerId': user.uid,
        'linkedCaretakerUid': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        webFadeRoute(const WebShell()),
      );
    } catch (e) {
      setState(() => _error = 'Failed to link device: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 24 : 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: EdgeInsets.all(isMobile ? 26 : 38),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.devices,
                      size: 76,
                      color: Color(0xFF111827),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'Enter your PathFinder device ID',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isMobile ? 24 : 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Example: pathfinder_001',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: _deviceController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _loading ? null : _linkDevice(),
                      decoration: InputDecoration(
                        labelText: 'Device ID',
                        hintText: 'pathfinder_001',
                        prefixIcon: const Icon(Icons.memory),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: isMobile ? double.infinity : 220,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _linkDevice,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: Text(_loading ? 'Linking...' : 'Link Device'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: _loading ? null : _logout,
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}