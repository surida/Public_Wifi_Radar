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
    // Handle two different CSV formats:
    // Seoul format (16 columns): coordinates at index 13, 14
    // Non-Seoul format (6 columns): coordinates at index 4, 5
    
    if (row.length >= 16) {
      // Seoul format
      return WifiInfo(
        installationYear: row.length > 10 ? row[10].toString() : '',
        installationType: row.length > 6 ? row[6].toString() : '',
        detailedAddress: row.length > 4 ? row[4].toString() : '',
        installationPlace: row.length > 2 ? row[2].toString() : '',
        lat: row.length > 13 ? (double.tryParse(row[13].toString()) ?? 0.0) : 0.0,
        lng: row.length > 14 ? (double.tryParse(row[14].toString()) ?? 0.0) : 0.0,
      );
    } else if (row.length >= 6) {
      // Non-Seoul format (경기도, etc.)
      // Format: [지역, 시군구, 주소, 상세위치, 위도, 경도]
      return WifiInfo(
        installationYear: '',
        installationType: row.length > 0 ? row[0].toString() : '', // Use region as type
        detailedAddress: row.length > 2 ? row[2].toString() : '',
        installationPlace: row.length > 3 ? row[3].toString() : '',
        lat: row.length > 4 ? (double.tryParse(row[4].toString()) ?? 0.0) : 0.0,
        lng: row.length > 5 ? (double.tryParse(row[5].toString()) ?? 0.0) : 0.0,
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
      );
    }
  }
}
