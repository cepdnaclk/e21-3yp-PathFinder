import 'package:flutter/material.dart';

import 'web_link_device_page.dart';
import 'web_login_page.dart';
import 'widgets/web_auth_layout.dart';
import 'widgets/web_page_route.dart';
import 'web_shell.dart';
import 'web_qr_scanner_page.dart';

class WebSignupIntroPage extends StatelessWidget {
  const WebSignupIntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return WebAuthLayout(
      child: AuthGlassCard(
        maxWidth: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.qr_code_scanner,
              color: Colors.white,
              size: 74,
            ),
            const SizedBox(height: 26),
            const Text(
              'Register Your PathFinder Device',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Scan the QR code on your PathFinder device. After scanning, the registration form will open automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.72),
                fontSize: 16,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.14)),
              ),
              child: Column(
                children: const [
                  _StepRow(
                    number: '01',
                    title: 'Scan device QR',
                    subtitle: 'Use the QR code printed on your device label.',
                  ),
                  SizedBox(height: 18),
                  _StepRow(
                    number: '02',
                    title: 'Sign in with Google',
                    subtitle: 'Use the caretaker Google account.',
                  ),
                  SizedBox(height: 18),
                  _StepRow(
                    number: '03',
                    title: 'Link device',
                    subtitle: 'After a successful scan, complete the registration form.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    webFadeRoute(const WebQrScannerPage()),
                  );
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Open QR Scanner'), 
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C6BFF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  webFadeRoute(const WebLoginPage()),
                );
              },
              child: const Text(
                'Already have an account? Login',
                style: TextStyle(
                  color: Color(0xFFC4B5FD),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;

  const _StepRow({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF7C6BFF).withOpacity(0.22),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}