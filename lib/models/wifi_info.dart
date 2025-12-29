/// WiFi 데이터 출처를 구분하는 enum
enum WifiDataSource {
  seoul, // 서울시 데이터 (seoul_public_wifi_data.csv)
  nationwide, // 중앙정부 데이터 (public_wifi_data.csv)
}

class WifiInfo {
  final String installationYear;
  final String installationType;
  final String detailedAddress;
  final String installationPlace;
  final double lat;
  final double lng;
  final WifiDataSource dataSource;

  WifiInfo({
    required this.installationYear,
    required this.installationType,
    required this.detailedAddress,
    required this.installationPlace,
    required this.lat,
    required this.lng,
    required this.dataSource,
  });

  factory WifiInfo.fromCsv(
    List<dynamic> row, {
    WifiDataSource source = WifiDataSource.nationwide,
  }) {
    // Handle two different CSV formats:
    // Seoul format (16 columns): coordinates at index 13, 14
    // Non-Seoul format (6 columns): coordinates at index 4, 5

    if (row.length >= 16) {
      // Seoul format
      // index 3: 도로명주소, index 4: 상세주소
      final roadAddress = row.length > 3 ? row[3].toString().trim() : '';
      final detail = row.length > 4 ? row[4].toString().trim() : '';
      final fullAddress =
          detail.isNotEmpty ? '$roadAddress $detail' : roadAddress;

      return WifiInfo(
        installationYear: row.length > 10 ? row[10].toString() : '',
        installationType: row.length > 6 ? row[6].toString() : '',
        detailedAddress: fullAddress,
        installationPlace: row.length > 2 ? row[2].toString() : '',
        lat: row.length > 13
            ? (double.tryParse(row[13].toString()) ?? 0.0)
            : 0.0,
        lng: row.length > 14
            ? (double.tryParse(row[14].toString()) ?? 0.0)
            : 0.0,
        dataSource: source,
      );
    } else if (row.length >= 6) {
      // Non-Seoul format (경기도, etc.)
      // Format: [지역, 시군구, 주소, 상세위치, 위도, 경도]
      return WifiInfo(
        installationYear: '',
        installationType: row.isNotEmpty
            ? row[0].toString()
            : '', // Use region as type
        detailedAddress: row.length > 2 ? row[2].toString() : '',
        installationPlace: row.length > 3 ? row[3].toString() : '',
        lat: row.length > 4 ? (double.tryParse(row[4].toString()) ?? 0.0) : 0.0,
        lng: row.length > 5 ? (double.tryParse(row[5].toString()) ?? 0.0) : 0.0,
        dataSource: source,
      );
    } else {
      // Fallback for unexpected formats
      return WifiInfo(
        installationYear: '',
        installationType: '',
        detailedAddress: '',
        installationPlace: 'Unknown',
        lat: 0.0,
        lng: 0.0,
        dataSource: source,
      );
    }
  }
}
