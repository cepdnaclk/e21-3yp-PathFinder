import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'web_login_page.dart';
import 'widgets/web_auth_layout.dart';
import 'widgets/web_page_route.dart';

class WebForgotPasswordPage extends StatefulWidget {
  const WebForgotPasswordPage({super.key});

  @override
  State<WebForgotPasswordPage> createState() => _WebForgotPasswordPageState();
}

class _WebForgotPasswordPageState extends State<WebForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();

  bool _loading = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _error = 'Please enter your email address.';
        _message = null;
      });
      return;
    }

    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');

    if (!emailRegex.hasMatch(email)) {
      setState(() {
        _error = 'Please enter a valid email address.';
        _message = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      setState(() {
        _message =
            'Password reset email sent. Please check your inbox and follow the instructions.';
      });
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to send password reset email.';

      if (e.code == 'user-not-found') {
        message = 'No account found with this email address.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      }

      setState(() {
        _error = message;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to send password reset email: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebAuthLayout(
      child: AuthGlassCard(
        maxWidth: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_reset,
              color: Colors.white,
              size: 68,
            ),
            const SizedBox(height: 24),
            const Text(
              'Reset Password',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Enter your account email. We will send you a link to reset your password.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.72),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),

            if (_error != null) ...[
              _statusBox(_error!, false),
              const SizedBox(height: 18),
            ],

            if (_message != null) ...[
              _statusBox(_message!, true),
              const SizedBox(height: 18),
            ],

            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: const TextStyle(color: Colors.white),
                suffixIcon: const Icon(
                  Icons.email_outlined,
                  color: Colors.white70,
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.white.withOpacity(0.45),
                  ),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Color(0xFFC4B5FD),
                    width: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _sendResetEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C6BFF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(_loading ? 'Sending...' : 'Send Reset Link'),
              ),
            ),

            const SizedBox(height: 20),

            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  webFadeRoute(const WebLoginPage()),
                );
              },
              child: const Text(
                'Back to Login',
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

  Widget _statusBox(String text, bool success) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: success
            ? Colors.green.withOpacity(0.16)
            : Colors.red.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: success
              ? Colors.green.withOpacity(0.28)
              : Colors.red.withOpacity(0.28),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}