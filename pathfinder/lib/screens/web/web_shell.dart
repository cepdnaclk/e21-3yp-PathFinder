import 'package:flutter/material.dart';
import 'web_account_page.dart';
import 'web_dashboard_page.dart';
import 'widgets/web_sidebar.dart';

class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    WebDashboardPage(),
    WebAccountPage(),
  ];

  @override
  Widget build(BuildContext context) {
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
              child: _pages[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }
}