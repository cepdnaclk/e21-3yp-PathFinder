import 'dart:math';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../alerts/alert_history_screen.dart';
import '../auth/link_device_screen.dart';
import '../auth/login_screen.dart';
import '../tracking/camera_feed_screen.dart';
import '../tracking/live_tracking_screen.dart';
import 'home_screen.dart';

class _SettingsColors {
  static const background = Color(0xFF2B3749);
  static const surface = Color(0xFF101925);
  static const blue = Color(0xFF2563EB);
  static const lightBlue = Color(0xFF60A5FA);
  static const green = Color(0xFF22C55E);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFF43F5E);
  static const purple = Color(0xFF7C3AED);
  static const cyan = Color(0xFF22D3EE);
  static const text = Color(0xFFF8FAFC);
  static const muted = Color(0xFF94A3B8);
}

class SettingsScreen extends StatefulWidget {
  final String deviceId;

  const SettingsScreen({super.key, required this.deviceId});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _loading = false;
  Map<String, dynamic>? _caretakerData;
  Map<String, dynamic>? _deviceData;
  String? _error;

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
      if (user == null) throw Exception('No logged in user');

      final caretakerData = await _firestoreService.getCaretakerData(user.uid);
      final deviceData = await _firestoreService.getDeviceData(widget.deviceId);
      if (!mounted) return;

      setState(() {
        _caretakerData = caretakerData;
        _deviceData = deviceData;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _unlinkDevice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _SettingsColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              _SettingsSquareIcon(
                icon: Icons.link_off_rounded,
                color: _SettingsColors.amber,
              ),
              SizedBox(width: 12),
              Text(
                'Unlink Device',
                style: TextStyle(color: _SettingsColors.text),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to unlink this device from your caretaker account?',
            style: TextStyle(color: _SettingsColors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: _SettingsColors.amber,
              ),
              child: const Text('Unlink'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No logged in user');

      await _firestoreService.unlinkCaretakerFromDevice(
        uid: user.uid,
        deviceId: widget.deviceId,
      );
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<void>(builder: (_) => const LinkDeviceScreen()),
        (_) => false,
      );
    } catch (error) {
      if (mounted) _showMessage('Failed to unlink device: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
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
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _SettingsColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'SOS Contact Numbers',
            style: TextStyle(color: _SettingsColors.text),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _contactField(
                controller: userContactController,
                label: 'User contact number',
                hint: 'e.g. 0712345678',
              ),
              const SizedBox(height: 12),
              _contactField(
                controller: emergencyContactController,
                label: 'Emergency contact number',
                hint: 'e.g. 0771234567',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: _SettingsColors.blue,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave == true) {
      setState(() => _loading = true);
      try {
        await _firestoreService.saveSosContactNumbers(
          uid: user.uid,
          userContactNumber: userContactController.text.trim(),
          emergencyContactNumber: emergencyContactController.text.trim(),
        );
        await _loadSettingsData();
        if (mounted) _showMessage('SOS contact numbers saved');
      } catch (error) {
        if (mounted) {
          _showMessage('Failed to save contact numbers: $error');
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }

    userContactController.dispose();
    emergencyContactController.dispose();
  }

  Widget _contactField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      cursorColor: _SettingsColors.lightBlue,
      style: const TextStyle(color: _SettingsColors.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: _SettingsColors.muted),
        hintStyle: TextStyle(
          color: _SettingsColors.muted.withValues(alpha: .65),
        ),
        filled: true,
        fillColor: Colors.black.withValues(alpha: .18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _SettingsColors.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openScreen(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => screen,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _selectBottomTab(int index) {
    switch (index) {
      case 0:
        _openScreen(HomeScreen(deviceId: widget.deviceId));
      case 1:
        _openScreen(LiveTrackingScreen(deviceId: widget.deviceId));
      case 2:
        _openScreen(CameraFeedScreen(deviceId: widget.deviceId));
      case 3:
        _openScreen(AlertHistoryScreen(deviceId: widget.deviceId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _SettingsColors.background,
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(child: _SettingsBackground()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 14),
                Expanded(child: _buildContent()),
                const SizedBox(height: 102),
              ],
            ),
          ),
          if (_loading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x44000000),
                child: Center(
                  child: CircularProgressIndicator(
                    color: _SettingsColors.lightBlue,
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _SettingsBottomBar(
        currentIndex: 4,
        onSelected: _selectBottomTab,
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Row(
        children: [
          _SettingsSquareButton(
            icon: Icons.arrow_back_rounded,
            color: const Color(0xFF475569),
            onTap: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Column(
              children: [
                Text(
                  'PATHFINDER',
                  style: TextStyle(
                    color: _SettingsColors.lightBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Settings',
                  style: TextStyle(
                    color: _SettingsColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          _SettingsSquareButton(
            icon: Icons.refresh_rounded,
            color: _SettingsColors.blue,
            onTap: _loadSettingsData,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null && _caretakerData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Unable to load settings\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _SettingsColors.text),
          ),
        ),
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    final online = _deviceData?['online'] == true;
    final userPhone = (_caretakerData?['userContactNumber'] ?? '')
        .toString()
        .trim();
    final emergencyPhone = (_caretakerData?['emergencyContactNumber'] ?? '')
        .toString()
        .trim();

    return RefreshIndicator(
      onRefresh: _loadSettingsData,
      color: _SettingsColors.blue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        children: [
          _buildProfileCard(user),
          const SizedBox(height: 22),
          const _SettingsSectionTitle(title: 'Account'),
          const SizedBox(height: 10),
          _SettingsGlassCard(
            child: Column(
              children: [
                _SettingsInfoTile(
                  icon: Icons.person_rounded,
                  title: 'Caretaker Name',
                  value:
                      (_caretakerData?['name'] ??
                              user?.displayName ??
                              'Unknown')
                          .toString(),
                  color: _SettingsColors.blue,
                ),
                const _SettingsDivider(),
                _SettingsInfoTile(
                  icon: Icons.email_rounded,
                  title: 'Email',
                  value: (_caretakerData?['email'] ?? user?.email ?? 'Unknown')
                      .toString(),
                  color: _SettingsColors.purple,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SettingsSectionTitle(title: 'SOS Contacts'),
          const SizedBox(height: 10),
          _SettingsGlassCard(
            child: Column(
              children: [
                _SettingsInfoTile(
                  icon: Icons.phone_rounded,
                  title: 'User Contact',
                  value: userPhone.isEmpty ? 'Not set' : userPhone,
                  color: _SettingsColors.blue,
                ),
                const _SettingsDivider(),
                _SettingsInfoTile(
                  icon: Icons.contact_phone_rounded,
                  title: 'Emergency Contact',
                  value: emergencyPhone.isEmpty ? 'Not set' : emergencyPhone,
                  color: _SettingsColors.red,
                ),
                const _SettingsDivider(),
                _SettingsActionTile(
                  icon: Icons.edit_rounded,
                  title: 'Edit SOS Contacts',
                  subtitle: 'Update saved call numbers',
                  color: _SettingsColors.purple,
                  onTap: _editSosContactNumbers,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SettingsSectionTitle(title: 'Linked Device'),
          const SizedBox(height: 10),
          _SettingsGlassCard(
            child: Column(
              children: [
                _SettingsInfoTile(
                  icon: Icons.watch_rounded,
                  title: 'Device ID',
                  value: widget.deviceId,
                  color: _SettingsColors.cyan,
                ),
                const _SettingsDivider(),
                _SettingsInfoTile(
                  icon: Icons.sensors_rounded,
                  title: 'Device Status',
                  value: online ? 'Online' : 'Offline',
                  color: online ? _SettingsColors.green : _SettingsColors.red,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SettingsSectionTitle(title: 'Actions'),
          const SizedBox(height: 10),
          _SettingsGlassCard(
            child: Column(
              children: [
                _SettingsActionTile(
                  icon: Icons.link_off_rounded,
                  title: 'Unlink Device',
                  subtitle: 'Remove this linked device',
                  color: _SettingsColors.amber,
                  onTap: _unlinkDevice,
                ),
                const _SettingsDivider(),
                _SettingsActionTile(
                  icon: Icons.logout_rounded,
                  title: 'Sign Out',
                  subtitle: 'Log out from PathFinder',
                  color: _SettingsColors.red,
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(User? user) {
    return _SettingsGlassCard(
      tintColor: _SettingsColors.blue,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _SettingsColors.blue,
              borderRadius: BorderRadius.circular(17),
              image: user?.photoURL == null
                  ? null
                  : DecorationImage(
                      image: NetworkImage(user!.photoURL!),
                      fit: BoxFit.cover,
                    ),
            ),
            child: user?.photoURL == null
                ? const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 34,
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'Caretaker',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _SettingsColors.text,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  user?.email ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _SettingsColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsInfoTile extends StatelessWidget {
  const _SettingsInfoTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          _SettingsSquareIcon(icon: icon, color: color, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _SettingsColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _SettingsColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            _SettingsSquareIcon(icon: icon, color: color, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _SettingsColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _SettingsColors.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: _SettingsColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGlassCard extends StatelessWidget {
  const _SettingsGlassCard({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
    this.tintColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (tintColor ?? const Color(0xFFD7E0EB)).withValues(
                  alpha: tintColor == null ? .18 : .3,
                ),
                (tintColor ?? const Color(0xFF7088AD)).withValues(
                  alpha: tintColor == null ? .15 : .18,
                ),
                const Color(0xFF16243A).withValues(alpha: .78),
              ],
              stops: const [0, .42, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .3),
                blurRadius: 20,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SettingsSquareIcon extends StatelessWidget {
  const _SettingsSquareIcon({
    required this.icon,
    required this.color,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.white, size: size * .48),
    );
  }
}

class _SettingsSquareButton extends StatelessWidget {
  const _SettingsSquareButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: Colors.white.withValues(alpha: .08));
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: _SettingsColors.text,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SettingsBottomBar extends StatelessWidget {
  const _SettingsBottomBar({
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const _items = <(IconData, String)>[
    (Icons.home_outlined, 'Home'),
    (Icons.location_on_outlined, 'Tracking'),
    (Icons.videocam_outlined, 'Live Feed'),
    (Icons.notifications_none_rounded, 'Alerts'),
    (Icons.settings_outlined, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            8,
            9,
            8,
            max(10, MediaQuery.paddingOf(context).bottom),
          ),
          decoration: BoxDecoration(
            color: const Color(0xED0A111C),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: .09)),
            ),
          ),
          child: Row(
            children: List.generate(_items.length, (index) {
              final selected = index == currentIndex;
              final item = _items[index];
              return Expanded(
                child: InkWell(
                  onTap: () => onSelected(index),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 4,
                    ),
                    child: SizedBox(
                      height: 56,
                      child: Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            top: 6,
                            child: Container(
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.transparent
                                    : const Color(0xFF050A12),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: selected
                                    ? null
                                    : const [
                                        BoxShadow(
                                          color: Colors.black,
                                          blurRadius: 7,
                                          offset: Offset(0, -2),
                                        ),
                                      ],
                              ),
                            ),
                          ),
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            left: selected ? 2 : 5,
                            right: selected ? 2 : 5,
                            top: selected ? -3 : 8,
                            bottom: selected ? 8 : 3,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              decoration: BoxDecoration(
                                gradient: selected
                                    ? const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF60A5FA),
                                          Color(0xFF2563EB),
                                        ],
                                      )
                                    : const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF101A29),
                                          Color(0xFF080F1A),
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    item.$1,
                                    size: 20,
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFF66758A),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.$2,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFF66758A),
                                      fontSize: 8,
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _SettingsBackground extends StatelessWidget {
  const _SettingsBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromARGB(255, 24, 28, 33),
                  Color.fromARGB(255, 46, 56, 69),
                  Color(0xFF172131),
                ],
                stops: [0, .52, 1],
              ),
            ),
          ),
          ClipPath(
            clipper: _SettingsBlueClipper(),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.fromARGB(255, 24, 28, 33),
                    Color.fromARGB(255, 48, 54, 65),
                    Color.fromARGB(255, 123, 131, 143),
                  ],
                  stops: [0, .5, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsBlueClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width * .62, 0)
      ..lineTo(size.width * .36, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
