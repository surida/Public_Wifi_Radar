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
      installationYear: row[0].toString(),
      installationType: row[1].toString(),
      detailedAddress: row[2].toString(),
      installationPlace: row[3].toString(),
      lat: double.tryParse(row[4].toString()) ?? 0.0,
      lng: double.tryParse(row[5].toString()) ?? 0.0,
    );
  }
}
