import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cp949_codec/cp949_codec.dart';
import 'package:public_wifi_radar/models/wifi_info.dart';

import 'package:public_wifi_radar/services/log_service.dart';

class CsvService {
  Future<List<WifiInfo>> loadWifiData() async {
    try {
      // Load raw bytes from asset
      final ByteData rawBytes = await rootBundle.load(
        'assets/csv/seoul_public_wifi_data.csv',
      );

      // Decode CP949/EUC-KR to String
      final List<int> bytes = rawBytes.buffer.asUint8List();
      final String decodedData = cp949.decode(bytes);

      // Parse CSV
      // Use CsvToListConverter with the decoded string
      // Setting shouldParseNumbers: false to keep installation year etc as String if needed,
      // but standard conversion usually works fine.
      List<List<dynamic>> rows = const CsvToListConverter(
        eol: '\n',
      ).convert(decodedData);

      List<WifiInfo> wifiList = [];
      // Skip header (index 0) and load all WiFi locations
      for (var i = 1; i < rows.length; i++) {
        if (i == 1) {
          LogService().log('Row 1: ${rows[i]}');
          LogService().log('Row 1 length: ${rows[i].length}');
          if (rows[i].length > 14) {
            LogService().log(
              'Lat Raw: "${rows[i][13]}", Lng Raw: "${rows[i][14]}"',
            );
          }
        }
        try {
          wifiList.add(WifiInfo.fromCsv(rows[i]));
        } catch (e) {
          // print('Error parsing row $i: $e');
          continue;
        }
      }
      LogService().log(
        'CSV Loaded: ${wifiList.length} items parsed from seoul_public_wifi_data.csv',
      );
      return wifiList;
    } catch (e) {
      LogService().log('Error loading CSV: $e');
      return [];
    }
  }
}
