import 'package:flutter/material.dart';
import 'web_login_page.dart';

class WebHomePage extends StatelessWidget {
  const WebHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 24),
              child: Row(
                children: [
                  const Icon(Icons.navigation, color: Colors.white, size: 34),
                  const SizedBox(width: 12),
                  const Text(
                    'PathFinder',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WebLoginPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'Login',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WebLoginPage(),
                        ),
                      );
                    },
                    child: const Text('Get Started'),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 80),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Smart navigation assistance for visually impaired users.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 64,
                            height: 1.05,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'PathFinder helps caretakers monitor live location, SOS alerts, device status, battery level, and safety updates from one web dashboard.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 20,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 36),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const WebLoginPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.login),
                          label: const Text('Login as Caretaker'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 60),
                  Expanded(
                    child: Container(
                      height: 420,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF111827),
                            Color(0xFF2563EB),
                            Color(0xFF9333EA),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.shield,
                          color: Colors.white,
                          size: 160,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
              child: Row(
                children: const [
                  _FeatureCard(
                    icon: Icons.location_on,
                    title: 'Live Tracking',
                    description: 'Monitor the user location from Firebase in real time.',
                  ),
                  SizedBox(width: 20),
                  _FeatureCard(
                    icon: Icons.warning,
                    title: 'SOS Alerts',
                    description: 'View emergency alerts triggered from the wearable device.',
                  ),
                  SizedBox(width: 20),
                  _FeatureCard(
                    icon: Icons.battery_full,
                    title: 'Device Status',
                    description: 'Track battery level, online status, and linked device data.',
                  ),
                ],
              ),
            ),
          ],
        ),
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
    return Expanded(
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
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
              style: const TextStyle(color: Colors.white60, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}