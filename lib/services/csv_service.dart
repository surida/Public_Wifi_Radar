import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cp949_codec/cp949_codec.dart';
import 'package:public_wifi_radar/models/wifi_info.dart';

import 'package:public_wifi_radar/services/log_service.dart';

class CsvService {
  // 샘플링 비율: N개 중 1개만 로딩 (1 = 100%, 2 = 50%, 3 = 33%, 10 = 10%)
  // Debug 모드에서만 적용, Release는 항상 100%
  static const int sampleRate = 1; // 100% (전체 로딩)

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

      // Debug 모드: 샘플링 적용 (sampleRate개 중 1개만 로딩)
      // Release 모드: 전체 로딩
      final int effectiveSampleRate = kDebugMode ? sampleRate : 1;
      final int totalRows = rows.length - 1; // 헤더 제외
      final int expectedCount = (totalRows / effectiveSampleRate).ceil();

      if (kDebugMode && sampleRate > 1) {
        LogService().log(
          '[DEBUG MODE] Sampling $assetPath: 1/$sampleRate (${(100 / sampleRate).toStringAsFixed(1)}%) = ~$expectedCount items from $totalRows total',
        );
      }

      // Skip header (index 0) and load WiFi locations with sampling
      for (var i = 1; i < rows.length; i++) {
        // 샘플링: effectiveSampleRate개 중 첫 번째만 로딩
        if ((i - 1) % effectiveSampleRate != 0) continue;

        if (wifiList.isEmpty) {
          LogService().log('[$assetPath] Row $i: ${rows[i]}');
          LogService().log('[$assetPath] Row $i length: ${rows[i].length}');
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
