import 'package:flutter/foundation.dart'; // Import for kDebugMode

import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cp949_codec/cp949_codec.dart';
import 'package:public_wifi_radar/models/wifi_info.dart';

import 'package:public_wifi_radar/services/log_service.dart';

class CsvService {
  Future<List<WifiInfo>> loadWifiData() async {
    List<WifiInfo> allWifiList = [];
    final totalStopwatch = Stopwatch()..start();

    try {
      // Load Seoul data
      LogService().log('Starting Seoul WiFi data loading...');
      final seoulStopwatch = Stopwatch()..start();
      final seoulData = await _loadSingleFile(
        'assets/csv/seoul_public_wifi_data.csv',
      );
      seoulStopwatch.stop();
      allWifiList.addAll(seoulData);
      LogService().log(
        'Seoul WiFi data loaded: ${seoulData.length} items in ${seoulStopwatch.elapsedMilliseconds}ms',
      );

      // Load non-Seoul data (other regions)
      LogService().log('Starting non-Seoul WiFi data loading...');
      final otherStopwatch = Stopwatch()..start();
      final otherData = await _loadSingleFile(
        'assets/csv/public_wifi_data.csv',
      );
      otherStopwatch.stop();
      if (!kDebugMode) {
        // Only load other regions data fully in Release mode or if controlled
        allWifiList.addAll(otherData);
      } else {
        // In debug, maybe skip or add limited amount?
        // Let's implement limiting inside _loadSingleFile based on kDebugMode
        allWifiList.addAll(otherData);
      }

      LogService().log(
        'Non-Seoul WiFi data loaded: ${otherData.length} items in ${otherStopwatch.elapsedMilliseconds}ms',
      );

      totalStopwatch.stop();
      LogService().log(
        'Total WiFi locations loaded: ${allWifiList.length} items in ${totalStopwatch.elapsedMilliseconds}ms (${(totalStopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)}s)',
      );
      return allWifiList;
    } catch (e) {
      totalStopwatch.stop();
      LogService().log(
        'Error loading WiFi data: $e (failed after ${totalStopwatch.elapsedMilliseconds}ms)',
      );
      return [];
    }
  }

  Future<List<WifiInfo>> _loadSingleFile(String assetPath) async {
    try {
      // Load raw bytes from asset
      final ByteData rawBytes = await rootBundle.load(assetPath);

      // Decode CP949/EUC-KR to String
      final List<int> bytes = rawBytes.buffer.asUint8List();
      final String decodedData = cp949.decode(bytes);

      // Parse CSV
      List<List<dynamic>> rows = const CsvToListConverter(
        eol: '\n',
      ).convert(decodedData);

      List<WifiInfo> wifiList = [];

      // DETERMINE LIMIT: 120,000 items is too much for Debug mode (OOM).
      // Limit to 2,000 items per file in Debug mode.
      int loadCount = rows.length;
      if (kDebugMode) {
        loadCount = rows.length > 2000 ? 2000 : rows.length;
        LogService().log(
          '[DEBUG MODE] Limiting $assetPath loading to $loadCount items to prevent OOM.',
        );
      }

      // Skip header (index 0) and load all WiFi locations
      for (var i = 1; i < loadCount; i++) {
        if (i == 1) {
          LogService().log('[$assetPath] Row 1: ${rows[i]}');
          LogService().log('[$assetPath] Row 1 length: ${rows[i].length}');
          if (rows[i].length > 14) {
            LogService().log(
              '[$assetPath] Lat Raw: "${rows[i][13]}", Lng Raw: "${rows[i][14]}"',
            );
          }
        }
        try {
          wifiList.add(WifiInfo.fromCsv(rows[i]));
        } catch (e) {
          // Skip invalid rows
          continue;
        }
      }
      return wifiList;
    } catch (e) {
      LogService().log('Error loading $assetPath: $e');
      return [];
    }
  }
}
