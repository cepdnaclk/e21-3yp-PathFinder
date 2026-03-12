import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService().signOut();

    if (!context.mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PathFinder'),
        actions: [
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${user?.displayName ?? "Caretaker"}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(user?.email ?? ''),
            const SizedBox(height: 24),
            const Card(
              child: ListTile(
                leading: Icon(Icons.location_on),
                title: Text('Live Tracking'),
                subtitle: Text('View real-time user location'),
              ),
            ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.warning),
                title: Text('SOS Alerts'),
                subtitle: Text('View emergency alerts'),
              ),
            ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.history),
                title: Text('Alert History'),
                subtitle: Text('View past incidents'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
