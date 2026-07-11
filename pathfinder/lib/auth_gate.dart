import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'screens/sign_in_page.dart';
import 'screens/link_device_page.dart';
import 'screens/dashboard_page.dart';
import 'services/firestore_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;

        if (user == null) {
          return const SignInPage();
        }

        return FutureBuilder<String?>(
          future: FirestoreService().getLinkedDeviceId(user.uid),
          builder: (context, deviceSnapshot) {
            if (deviceSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final deviceId = deviceSnapshot.data;

            if (deviceId == null || deviceId.isEmpty) {
              return const LinkDevicePage();
            }

            return DashboardPage(deviceId: deviceId);
          },
        );
      },
    );
  }
}