import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cp949_codec/cp949_codec.dart';
import 'package:public_wifi_radar/models/wifi_info.dart';

import 'package:public_wifi_radar/services/log_service.dart';

class CsvService {
  Future<List<WifiInfo>> loadWifiData() async {
    List<WifiInfo> allWifiList = [];

    try {
      // Load Seoul data
      final seoulData = await _loadSingleFile(
        'assets/csv/seoul_public_wifi_data.csv',
      );
      allWifiList.addAll(seoulData);
      LogService().log('Seoul WiFi data loaded: ${seoulData.length} items');

      // Load non-Seoul data (other regions)
      final otherData = await _loadSingleFile(
        'assets/csv/public_wifi_data.csv',
      );
      allWifiList.addAll(otherData);
      LogService().log('Non-Seoul WiFi data loaded: ${otherData.length} items');

      LogService().log(
        'Total WiFi locations loaded: ${allWifiList.length} items',
      );
      return allWifiList;
    } catch (e) {
      LogService().log('Error loading WiFi data: $e');
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
      // Skip header (index 0) and load all WiFi locations
      for (var i = 1; i < rows.length; i++) {
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
