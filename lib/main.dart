import 'package:flutter/material.dart';
import 'dart:async';
import 'package:public_wifi_radar/screens/map_screen.dart';
import 'package:public_wifi_radar/services/log_service.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logging first
  await LogService().init();

  // Log app startup
  debugPrint('[MAIN] App starting...');
  LogService().log('[MAIN] App starting...');

  // Catch all errors in Flutter framework
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FLUTTER ERROR] ${details.exception}');
    debugPrint('[FLUTTER ERROR STACK] ${details.stack}');
    LogService().log('[FLUTTER ERROR] ${details.exception}');
    LogService().log('[FLUTTER ERROR STACK] ${details.stack}');
  };

  // Catch all errors in async code
  runZonedGuarded(
    () {
      debugPrint('[MAIN] Running app...');
      LogService().log('[MAIN] Running app...');
      runApp(const MyApp());
    },
    (error, stackTrace) {
      debugPrint('[UNCAUGHT ERROR] $error');
      debugPrint('[UNCAUGHT ERROR STACK] $stackTrace');
      LogService().log('[UNCAUGHT ERROR] $error');
      LogService().log('[UNCAUGHT ERROR STACK] $stackTrace');
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Public WiFi Radar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}
