// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '공공 와이파이 레이더';

  @override
  String get infoTitle => '앱 정보';

  @override
  String get dataSource => '데이터 출처: 공공데이터포털 (data.go.kr)';

  @override
  String get appVersion => '버전';

  @override
  String get contact => '문의';

  @override
  String get close => '닫기';
}
