import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cp949_codec/cp949_codec.dart';
import 'package:public_wifi_radar/models/wifi_info.dart';

class CsvService {
  Future<List<WifiInfo>> loadWifiData() async {
    try {
      // Load raw bytes from asset
      final ByteData rawBytes = await rootBundle.load('assets/csv/public_wifi_data.csv');
      
      // Decode CP949/EUC-KR to String
      final List<int> bytes = rawBytes.buffer.asUint8List();
      final String decodedData = cp949.decode(bytes);
      
      // Parse CSV
      // Use CsvToListConverter with the decoded string
      // Setting shouldParseNumbers: false to keep installation year etc as String if needed,
      // but standard conversion usually works fine.
      List<List<dynamic>> rows = const CsvToListConverter().convert(decodedData);

      List<WifiInfo> wifiList = [];
      // Skip header (index 0)
      for (var i = 1; i < rows.length; i++) {
        try {
          wifiList.add(WifiInfo.fromCsv(rows[i]));
        } catch (e) {
          // print('Error parsing row $i: $e');
          continue;
        }
      }
      return wifiList;
    } catch (e) {
      print('Error loading CSV: $e');
      return [];
    }
  }
}
