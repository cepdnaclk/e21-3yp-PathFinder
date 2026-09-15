import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/web/web_home_page.dart';
import 'screens/web/web_login_page.dart';
import 'screens/web/web_shell.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PathFinder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => kIsWeb
            ? WebHomePage()
            : const SplashScreen(),

        '/login': (context) => kIsWeb
            ? const WebLoginPage()
            : const LoginScreen(),

        '/home': (context) => kIsWeb
            ? const WebShell()
            : const HomeScreen(),
      },
    );
  }
}