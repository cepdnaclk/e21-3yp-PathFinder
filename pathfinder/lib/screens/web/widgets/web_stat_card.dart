import 'package:flutter/material.dart';

class WebStatCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  final bool isBattery;
  final int batteryLevel;

  const WebStatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.onTap,
    this.isBattery = false,
    this.batteryLevel = 0,
  });

  @override
  State<WebStatCard> createState() => _WebStatCardState();
}

class _WebStatCardState extends State<WebStatCard>
    with SingleTickerProviderStateMixin {
  bool _hovering = false;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _batteryColor {
    if (widget.batteryLevel <= 20) return Colors.red;
    if (widget.batteryLevel <= 50) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final hoverColor = widget.isBattery ? _batteryColor : widget.color;

    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: _hovering ? 1.03 : 1.0,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(26),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 150,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _hovering ? const Color(0xFF111827) : Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: _hovering
                      ? hoverColor.withOpacity(0.28)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: _hovering ? 30 : 18,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                widget.isBattery
                    ? _BatteryLiquidIcon(
                        level: widget.batteryLevel,
                        color: _batteryColor,
                        animate: _hovering,
                        controller: _controller,
                      )
                    : CircleAvatar(
                        radius: 31,
                        backgroundColor: widget.color.withOpacity(0.15),
                        child: Icon(widget.icon, color: widget.color, size: 32),
                      ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: _hovering ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.value,
                        style: TextStyle(
                          color: _hovering ? Colors.white : Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.onTap != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Click to view',
                          style: TextStyle(
                            color: _hovering ? Colors.white54 : Colors.black38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
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

class _BatteryLiquidIcon extends StatelessWidget {
  final int level;
  final Color color;
  final bool animate;
  final AnimationController controller;

  const _BatteryLiquidIcon({
    required this.level,
    required this.color,
    required this.animate,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final clampedLevel = level.clamp(0, 100);
    final fill = clampedLevel / 100;

    return CircleAvatar(
      radius: 34,
      backgroundColor: color.withOpacity(0.15),
      child: SizedBox(
        width: 34,
        height: 54,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 26,
              height: 44,
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 3),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            Positioned(
              top: 2,
              child: Container(
                width: 12,
                height: 5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Positioned(
              bottom: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: SizedBox(
                  width: 20,
                  height: 34,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) {
                        final waveOffset =
                            animate ? (controller.value - 0.5) * 6 : 0.0;

                        return Transform.translate(
                          offset: Offset(waveOffset, 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 32,
                            height: 34 * fill,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}