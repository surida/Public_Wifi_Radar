class WifiInfo {
  final String installationYear;
  final String installationType;
  final String detailedAddress;
  final String installationPlace;
  final double lat;
  final double lng;

  WifiInfo({
    required this.installationYear,
    required this.installationType,
    required this.detailedAddress,
    required this.installationPlace,
    required this.lat,
    required this.lng,
  });

  factory WifiInfo.fromCsv(List<dynamic> row) {
    // CSV structure based on:
    // 0: 설치년도, 1: 설치유형, 2: 상세주소, 3: 설치장소, 4: WGS84위도, 5: WGS84경도
    return WifiInfo(
      // 0: No, 1: Gu, 2: Name (Place), 3: Road Addr, 4: Detail Addr, 
      // 5: Floor, 6: Type, ... 10: Year, ... 13: Lat, 14: Lng
      installationYear: row.length > 10 ? row[10].toString() : '',
      installationType: row.length > 6 ? row[6].toString() : '',
      detailedAddress: row.length > 4 ? row[4].toString() : '',
      installationPlace: row.length > 2 ? row[2].toString() : '',
      lat: row.length > 13 ? (double.tryParse(row[13].toString()) ?? 0.0) : 0.0,
      lng: row.length > 14 ? (double.tryParse(row[14].toString()) ?? 0.0) : 0.0,
    );
  }
}
