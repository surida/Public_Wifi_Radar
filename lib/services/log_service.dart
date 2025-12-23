import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  File? _logFile;

  Future<void> init() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }

      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String logFileName = 'log_$timestamp.txt';
      _logFile = File('${logsDir.path}/$logFileName');
      
      await _logFile!.writeAsString('--- Log Started at $timestamp ---\n');
      print('Log file created at: ${_logFile!.path}');
    } catch (e) {
      print('Failed to initialize LogService: $e');
    }
  }

  void log(String message) {
    final String timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final String startLog = '[$timestamp] $message';
    
    // Print to console
    print(startLog);

    // Write to file
    if (_logFile != null) {
      _logFile!.writeAsStringSync('$startLog\n', mode: FileMode.append);
    }
  }
}
