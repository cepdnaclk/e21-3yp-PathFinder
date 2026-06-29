import 'package:flutter/material.dart';
import '../web_home_page.dart';
import '../web_login_page.dart';
import 'web_page_route.dart';

class WebAuthLayout extends StatelessWidget {
  final Widget child;
  final bool showHeroText;

  const WebAuthLayout({
    super.key,
    required this.child,
    this.showHeroText = true,
  });

  void _goLogin(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WebLoginPage()),
    );
  }

  void _goHome(BuildContext context) {
    Navigator.pushReplacement(
      context,
      webFadeRoute(WebHomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 850;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/pathfinder_device.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.96),
                    Colors.black.withOpacity(0.76),
                    const Color(0xFF111827).withOpacity(0.70),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 22 : 56,
                vertical: 26,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.navigation, color: Colors.white, size: 30),
                      const SizedBox(width: 12),
                      const Text(
                        'PathFinder',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (!isMobile) ...[
                        _navText('HOME', () => _goHome(context)),
                        _navText('ABOUT', () {}),
                        _navText('SERVICE', () {}),
                        _navText('CONTACT', () {}),
                        const SizedBox(width: 16),
                      ],
                      OutlinedButton(
                        onPressed: () => _goLogin(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withOpacity(0.35)),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                        ),
                        child: const Text('LOGIN'),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 42 : 90),
                  isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showHeroText) _heroText(isMobile),
                            if (showHeroText) const SizedBox(height: 30),
                            child,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (showHeroText)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _heroText(isMobile),
                                    const SizedBox(height: 28),
                                    /*
                                    Container(
                                      height: 260,
                                      width: 430,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(28),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF7C3AED).withOpacity(0.35),
                                            blurRadius: 36,
                                            offset: const Offset(0, 18),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(28),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.asset(
                                              'assets/images/pathfinder_device.jpg',
                                              fit: BoxFit.cover,
                                            ),
                                            Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.black.withOpacity(0.35),
                                                  ],
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ), 
                                    */
                                  ],
                                ),
                              ),
                            if (showHeroText) const SizedBox(width: 70),
                            Expanded(child: child),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navText(String text, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _heroText(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Smart navigation\nassistance for visually\nimpaired users.',
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 34 : 48,
            height: 1.12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'PathFinder helps caretakers monitor live location,\nSOS alerts, device status, battery level, and safety\nupdates from one web dashboard.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.72),
            fontSize: isMobile ? 15 : 17,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class AuthGlassCard extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const AuthGlassCard({
    super.key,
    required this.child,
    this.maxWidth = 460,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.all(34),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF111827).withOpacity(0.92),
              const Color(0xFF1E3A8A).withOpacity(0.84),
              const Color(0xFF4C1D95).withOpacity(0.88),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.42),
              blurRadius: 40,
              offset: const Offset(0, 22),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}