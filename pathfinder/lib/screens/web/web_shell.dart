import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'web_account_page.dart';
import 'web_dashboard_page.dart';
import 'web_sos_history_page.dart';
import 'widgets/web_sidebar.dart';

class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No user signed in')),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          WebSidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),
          Expanded(
            child: Container(
              color: const Color(0xFFF3F4F6),
              child: _buildPage(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return const WebDashboardPage();
      case 1:
        return const WebSosHistoryPage();
      case 2:
        return const WebAccountPage();
      default:
        return const WebDashboardPage();
    }
  }
}