// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Public WiFi Radar';

  @override
  String get infoTitle => 'App Info';

  @override
  String get dataSource => 'Data Source: Public Data Portal (data.go.kr)';

  @override
  String get appVersion => 'Version';

  @override
  String get contact => 'Contact';

  @override
  String get close => 'Close';
}
