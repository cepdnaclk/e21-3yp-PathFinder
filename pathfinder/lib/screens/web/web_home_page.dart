import 'package:flutter/material.dart';
import 'web_login_page.dart';
import 'web_signup_intro_page.dart';
import 'widgets/web_page_route.dart';

class WebHomePage extends StatelessWidget {
  WebHomePage({super.key});

  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _aboutKey = GlobalKey();
  final GlobalKey _serviceKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return;

    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  void _goLogin(BuildContext context) {
    Navigator.push(
      context,
      webFadeRoute(const WebLoginPage()),
    );
  }

  void _goSignup(BuildContext context) {
    Navigator.push(
      context,
      webFadeRoute(const WebSignupIntroPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 800;

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
                    Colors.black.withOpacity(0.86),
                    const Color(0xFF111827).withOpacity(0.78),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _navBar(context, isMobile),
                  SizedBox(height: isMobile ? 60 : 120),

                  Container(
                    key: _homeKey,
                    child: isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _heroText(context, isMobile),
                              const SizedBox(height: 36),
                              _heroVisual(isMobile),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: _heroText(context, isMobile)),
                              const SizedBox(width: 70),
                              Expanded(child: _heroVisual(isMobile)),
                            ],
                          ),
                  ),

                  const SizedBox(height: 90),
                  Container(
                    key: _aboutKey,
                    child: _aboutSection(isMobile),
                  ),
                  const SizedBox(height: 70),
                  Container(
                    key: _serviceKey,
                    child: _serviceSection(isMobile),
                  ),
                  const SizedBox(height: 70),
                  Container(
                    key: _contactKey,
                    child: _contactSection(isMobile),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navBar(BuildContext context, bool isMobile) {
    return Row(
      children: [
        const Icon(Icons.navigation, color: Colors.white, size: 32),
        const SizedBox(width: 12),
        const Text(
          'PathFinder',
          style: TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (!isMobile) ...[
          _navText('HOME', _homeKey),
          _navText('ABOUT', _aboutKey),
          _navText('SERVICE', _serviceKey),
          _navText('CONTACT', _contactKey),
          const SizedBox(width: 18),
        ],
        OutlinedButton(
          onPressed: () => _goLogin(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withOpacity(0.35)),
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: const Text('LOGIN'),
        ),
        if (!isMobile) ...[
          const SizedBox(width: 14),
          ElevatedButton(
            onPressed: () => _goSignup(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF7F0FF),
              foregroundColor: const Color(0xFF6D5494),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text('Get Started'),
          ),
        ],
      ],
    );
  }

  Widget _navText(String text, GlobalKey key) {
    return TextButton(
      onPressed: () => _scrollTo(key),
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

  Widget _heroText(BuildContext context, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Smart navigation\nassistance for visually\nimpaired users.',
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 38 : 58,
            height: 1.08,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'PathFinder helps caretakers monitor live location, SOS alerts, device status, battery level, and safety updates from one web dashboard.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.74),
            fontSize: isMobile ? 16 : 19,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 34),
        ElevatedButton.icon(
          onPressed: () => _goLogin(context),
          icon: const Icon(Icons.login),
          label: const Text('Login as Caretaker'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF7F0FF),
            foregroundColor: const Color(0xFF6D5494),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroVisual(bool isMobile) {
    return Container(
      height: isMobile ? 260 : 430,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF172554),
            Color(0xFF2563EB),
            Color(0xFF9333EA),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.35),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.shield, color: Colors.white, size: 150),
      ),
    );
  }

  Widget _aboutSection(bool isMobile) {
    return _sectionCard(
      title: 'About PathFinder',
      child: Text(
        'PathFinder is a smart assistive navigation device designed for visually impaired users. '
        'The wearable device combines GPS tracking, SOS alerts, battery monitoring, safe-zone awareness, '
        'road and pedestrian assistance, and live camera streaming. Caretakers can monitor the user through '
        'a secure web dashboard and mobile app, helping them respond quickly during emergencies.',
        style: TextStyle(
          color: Colors.white.withOpacity(0.75),
          fontSize: 17,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _serviceSection(bool isMobile) {
    return _sectionCard(
      title: 'Service',
      child: Wrap(
        spacing: 18,
        runSpacing: 18,
        children: const [
          _FeatureCard(
            icon: Icons.location_on,
            title: 'Live Tracking',
            description: 'View the user’s live GPS location from Firebase.',
          ),
          _FeatureCard(
            icon: Icons.warning_amber_rounded,
            title: 'SOS Alerts',
            description: 'Receive and manage emergency SOS alerts.',
          ),
          _FeatureCard(
            icon: Icons.videocam,
            title: 'Live Camera',
            description: 'Request live WebRTC camera streaming from the device.',
          ),
        ],
      ),
    );
  }

  Widget _contactSection(bool isMobile) {
    return _sectionCard(
      title: 'Contact',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _ContactRow(
            icon: Icons.location_on,
            label: 'Location',
            value: 'Faculty of Engineering, University of Peradeniya',
          ),
          SizedBox(height: 18),
          _ContactRow(
            icon: Icons.email,
            label: 'Email',
            value: 'pathfinderkollo@gmail.com',
          ),
          SizedBox(height: 18),
          _ContactRow(
            icon: Icons.phone,
            label: 'Contact Number',
            value: '+94 71 034 5187',
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 310,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.68),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFF7C6BFF).withOpacity(0.18),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            '$label: $value',
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}