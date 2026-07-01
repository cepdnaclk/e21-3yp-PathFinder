import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../models/alert_model.dart';
import '../../services/firestore_service.dart';
import '../home/home_screen.dart';
import '../home/settings_screen.dart';
import '../tracking/camera_feed_screen.dart';
import '../tracking/live_tracking_screen.dart';

class _AlertColors {
  static const background = Color(0xFF2B3749);
  static const surface = Color(0xFF101925);
  static const lightBlue = Color(0xFF60A5FA);
  static const green = Color(0xFF22C55E);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFF43F5E);
  static const text = Color(0xFFF8FAFC);
  static const muted = Color(0xFF94A3B8);
}

class AlertHistoryScreen extends StatelessWidget {
  final String deviceId;

  const AlertHistoryScreen({super.key, required this.deviceId});

  Future<void> _clearHistory(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _AlertColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              _AlertSquareIcon(
                icon: Icons.delete_outline_rounded,
                color: _AlertColors.red,
              ),
              SizedBox(width: 12),
              Text('Clear History', style: TextStyle(color: _AlertColors.text)),
            ],
          ),
          content: const Text(
            'Are you sure you want to delete all alert history?',
            style: TextStyle(color: _AlertColors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: _AlertColors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await FirestoreService().deleteAllAlerts(deviceId);
      if (!context.mounted) return;
      _showMessage(context, 'Alert history cleared');
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, 'Failed: $error');
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _AlertColors.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'acknowledged':
        return _AlertColors.amber;
      case 'resolved':
        return _AlertColors.green;
      case 'active':
      default:
        return _AlertColors.red;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'low_battery':
        return _AlertColors.amber;
      case 'safe_zone_exit':
        return _AlertColors.green;
      case 'sos':
      default:
        return _AlertColors.red;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'low_battery':
        return Icons.battery_alert_rounded;
      case 'safe_zone_exit':
        return Icons.location_off_rounded;
      case 'sos':
      default:
        return Icons.sos_rounded;
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

  void _openScreen(BuildContext context, Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => screen,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _selectBottomTab(BuildContext context, int index) {
    switch (index) {
      case 0:
        _openScreen(context, HomeScreen(deviceId: deviceId));
      case 1:
        _openScreen(context, LiveTrackingScreen(deviceId: deviceId));
      case 2:
        _openScreen(context, CameraFeedScreen(deviceId: deviceId));
      case 4:
        _openScreen(context, SettingsScreen(deviceId: deviceId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: _AlertColors.background,
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(child: _AlertBackground()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(context),
                const SizedBox(height: 14),
                Expanded(
                  child: StreamBuilder<List<AlertModel>>(
                    stream: firestoreService.getAlertHistoryStream(deviceId),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _errorView('${snapshot.error}');
                      }
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: _AlertColors.lightBlue,
                          ),
                        );
                      }

                      final alerts = snapshot.data!;
                      if (alerts.isEmpty) return _emptyView();
                      return _alertsList(alerts);
                    },
                  ),
                ),
                const SizedBox(height: 102),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _AlertBottomBar(
        currentIndex: 3,
        onSelected: (index) => _selectBottomTab(context, index),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Row(
        children: [
          _AlertSquareButton(
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
                    color: _AlertColors.lightBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Alert History',
                  style: TextStyle(
                    color: _AlertColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          _AlertSquareButton(
            icon: Icons.delete_outline_rounded,
            color: _AlertColors.red,
            onTap: () => _clearHistory(context),
          ),
        ],
      ),
    );
  }

  Widget _alertsList(List<AlertModel> alerts) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      children: [
        _AlertGlassCard(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              const _AlertSquareIcon(
                icon: Icons.notifications_active_rounded,
                color: _AlertColors.amber,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${alerts.length} Alerts Recorded',
                      style: const TextStyle(
                        color: _AlertColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Device: $deviceId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AlertColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...alerts.map(_alertCard),
      ],
    );
  }

  Widget _alertCard(AlertModel alert) {
    final statusColor = _statusColor(alert.status);
    final typeColor = _typeColor(alert.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _AlertGlassCard(
        tintColor: typeColor,
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              children: [
                _AlertSquareIcon(
                  icon: _typeIcon(alert.type),
                  color: typeColor,
                  size: 46,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _typeLabel(alert.type),
                        style: const TextStyle(
                          color: _AlertColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _AlertColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    alert.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFF101925).withValues(alpha: .72),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _detailRow(
                    icon: Icons.devices_rounded,
                    label: 'Device',
                    value: alert.deviceId,
                  ),
                  const SizedBox(height: 9),
                  _detailRow(
                    icon: Icons.battery_5_bar_rounded,
                    label: 'Battery',
                    value: '${alert.batteryLevel}%',
                  ),
                  const SizedBox(height: 9),
                  _detailRow(
                    icon: Icons.location_on_rounded,
                    label: 'Location',
                    value:
                        '${alert.lat.toStringAsFixed(5)}, '
                        '${alert.lng.toStringAsFixed(5)}',
                  ),
                  const SizedBox(height: 9),
                  _detailRow(
                    icon: Icons.access_time_rounded,
                    label: 'Created',
                    value: alert.createdAt != null
                        ? alert.createdAt!.toDate().toString()
                        : 'Unavailable',
                  ),
                  if (alert.acknowledgedAt != null) ...[
                    const SizedBox(height: 9),
                    _detailRow(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Acknowledged',
                      value: alert.acknowledgedAt!.toDate().toString(),
                    ),
                  ],
                  if (alert.resolvedAt != null) ...[
                    const SizedBox(height: 9),
                    _detailRow(
                      icon: Icons.done_all_rounded,
                      label: 'Resolved',
                      value: alert.resolvedAt!.toDate().toString(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
        Icon(icon, size: 17, color: _AlertColors.lightBlue),
        const SizedBox(width: 8),
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: const TextStyle(
              color: _AlertColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: _AlertColors.text,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: double.infinity,
          child: _AlertGlassCard(
            tintColor: _AlertColors.green,
            padding: const EdgeInsets.all(26),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AlertSquareIcon(
                  icon: Icons.check_rounded,
                  color: _AlertColors.green,
                  size: 58,
                ),
                SizedBox(height: 16),
                Text(
                  'No Alerts Found',
                  style: TextStyle(
                    color: _AlertColors.text,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'This device has no recorded alerts yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _AlertColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Unable to load alerts\n$error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _AlertColors.text),
        ),
      ),
    );
  }
}

class _AlertGlassCard extends StatelessWidget {
  const _AlertGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
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

class _AlertSquareIcon extends StatelessWidget {
  const _AlertSquareIcon({
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

class _AlertSquareButton extends StatelessWidget {
  const _AlertSquareButton({
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

class _AlertBottomBar extends StatelessWidget {
  const _AlertBottomBar({required this.currentIndex, required this.onSelected});

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

class _AlertBackground extends StatelessWidget {
  const _AlertBackground();

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
            clipper: _AlertBlueClipper(),
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

class _AlertBlueClipper extends CustomClipper<Path> {
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
