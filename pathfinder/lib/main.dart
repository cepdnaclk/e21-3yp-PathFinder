import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('MAIN 1: widgets initialized');

  try {
    debugPrint('MAIN 2: initializing firebase');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('MAIN 3: firebase initialized');

    runApp(const MyApp());
    debugPrint('MAIN 4: app started');

    unawaited(() async {
      debugPrint('MAIN 5: starting local notification service');
      await NotificationService.initialize();
      debugPrint('MAIN 6: local notification service finished');
    }());
  } catch (e, st) {
    debugPrint('MAIN ERROR: $e');
    debugPrintStack(stackTrace: st);
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Startup error: $e'),
          ),
        ),
      ),
    );
  }
}