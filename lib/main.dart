import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:public_wifi_radar/l10n/app_localizations.dart';
import 'package:public_wifi_radar/screens/map_screen.dart';
import 'package:public_wifi_radar/services/log_service.dart';

void main() {
  // Catch all errors in async code and send to Crashlytics
  runZonedGuarded(
    () async {
      // Ensure Flutter bindings are initialized (must be in same zone as runApp)
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize logging first
      await LogService().init();

      // Log app startup
      debugPrint('[MAIN] App starting...');
      LogService().log('[MAIN] App starting...');

      // Initialize Firebase
      debugPrint('[MAIN] Initializing Firebase...');
      LogService().log('[MAIN] Initializing Firebase...');
      await Firebase.initializeApp();
      debugPrint('[MAIN] Firebase initialized successfully');
      LogService().log('[MAIN] Firebase initialized successfully');

      // Pass all uncaught "fatal" errors from the framework to Crashlytics
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint('[FLUTTER ERROR] ${details.exception}');
        debugPrint('[FLUTTER ERROR STACK] ${details.stack}');
        LogService().log('[FLUTTER ERROR] ${details.exception}');
        LogService().log('[FLUTTER ERROR STACK] ${details.stack}');

        // Send to Crashlytics
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };

      // Run the app
      debugPrint('[MAIN] Running app...');
      LogService().log('[MAIN] Running app...');
      runApp(const MyApp());
    },
    (error, stackTrace) {
      debugPrint('[UNCAUGHT ERROR] $error');
      debugPrint('[UNCAUGHT ERROR STACK] $stackTrace');
      LogService().log('[UNCAUGHT ERROR] $error');
      LogService().log('[UNCAUGHT ERROR STACK] $stackTrace');

      // Send to Crashlytics
      FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: true);
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Public WiFi Radar',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('ko'), // Korean
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}
