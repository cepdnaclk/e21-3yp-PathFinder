import 'package:flutter/material.dart';

import 'web_account_page.dart';
import 'web_dashboard_page.dart';
import 'web_live_camera_page.dart';
import 'web_sos_history_page.dart';
import 'widgets/web_sidebar.dart';

class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  int _selectedIndex = 0;

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return const WebDashboardPage();
      case 1:
        return const WebLiveCameraPage();
      case 2:
        return const WebSosHistoryPage();
      case 3:
        return const WebAccountPage();
      default:
        return const WebDashboardPage();
    }
  }

  String _title() {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Live Camera';
      case 2:
        return 'SOS History';
      case 3:
        return 'Account Info';
      default:
        return 'PathFinder';
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final bool mobile = width < 1100;

    if (mobile) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_title()),
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
        ),
        drawer: Drawer(
          child: WebSidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              setState(() => _selectedIndex = index);
              Navigator.pop(context);
            },
            compact: false,
          ),
        ),
        body: Container(
          color: const Color(0xFFF3F4F6),
          child: _buildPage(),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          WebSidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              setState(() => _selectedIndex = index);
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
}