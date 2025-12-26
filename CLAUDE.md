# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Public WiFi Radar is a Flutter mobile application that displays public WiFi hotspot locations on an interactive map using Google Maps. The app loads nationwide WiFi data from CSV files (Seoul and other regions) and displays the nearest 500 locations based on user position with dynamic marker updates as the map is panned.

## Development Commands

### Setup and Dependencies
```bash
# Install dependencies
flutter pub get

# Clean build artifacts
flutter clean
```

### Running the Application
```bash
# Run on connected device/emulator
flutter run

# Run on specific device
flutter devices  # List available devices
flutter run -d <device-id>

# Run with specific flavor
flutter run --debug
flutter run --release
flutter run --profile
```

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage
```

### Code Quality
```bash
# Analyze code for issues
flutter analyze

# Format code
flutter format .

# Format specific files
flutter format lib/
```

### Building
```bash
# Build APK (Android)
flutter build apk --release

# Build App Bundle (Android)
flutter build appbundle --release

# Build iOS app
flutter build ios --release

# Build for macOS
flutter build macos --release
```

## Architecture Overview

### Core Data Flow
1. **App Initialization** ([main.dart:8-56](lib/main.dart#L8-L56)): Zone-guarded initialization with Firebase Crashlytics integration for comprehensive error tracking
2. **CSV Loading** ([csv_service.dart:10-51](lib/services/csv_service.dart#L10-L51)): CP949/EUC-KR encoded CSV files decoded and parsed into WifiInfo models
3. **Location Services** ([map_screen.dart:35-79](lib/screens/map_screen.dart#L35-L79)): Permission handling with timeouts, fallback to default location (Seoul) on errors
4. **Dynamic Marker Rendering** ([map_screen.dart:81-142](lib/screens/map_screen.dart#L81-L142)): Proximity-based sorting, displaying nearest 500 WiFi locations with debounced camera updates

### Key Components

#### Models
- **WifiInfo** ([models/wifi_info.dart](lib/models/wifi_info.dart)): Handles dual CSV format parsing
  - Seoul format: 16 columns with coordinates at indices 13-14
  - Non-Seoul format: 6 columns with coordinates at indices 4-5
  - Automatic format detection in `fromCsv()` factory

#### Services
- **CsvService** ([services/csv_service.dart](lib/services/csv_service.dart)): Asset loading with CP949 decoding
  - `loadWifiData()`: Loads both Seoul and nationwide data sequentially
  - `_loadSingleFile()`: Handles encoding conversion and CSV parsing
  - Performance logging with millisecond precision

- **LogService** ([services/log_service.dart](lib/services/log_service.dart)): Singleton file-based logging
  - Timestamped log files in application documents directory
  - Console and file output for debugging
  - Initialized before Firebase in app startup sequence

#### Screens
- **MapScreen** ([screens/map_screen.dart](lib/screens/map_screen.dart)): Main Google Maps interface
  - Proximity-based marker sorting from current/center position
  - 500 marker limit for performance optimization
  - Debounced camera updates (300ms) to prevent excessive re-renders
  - Graceful degradation when location services unavailable

### CSV Data Format

The app expects two CSV files in `assets/csv/`:
- `seoul_public_wifi_data.csv`: Seoul-specific data with 16 columns
- `public_wifi_data.csv`: Nationwide data with 6 columns

Both formats are CP949/EUC-KR encoded and require the `cp949_codec` package for proper Korean character handling.

### Error Handling Strategy

The app implements comprehensive error tracking:
- **Zone-guarded execution**: All async errors caught in `runZonedGuarded`
- **Flutter framework errors**: Captured via `FlutterError.onError`
- **Firebase Crashlytics**: Automatic reporting of fatal and non-fatal errors
- **Timeouts**: All location/permission operations have explicit timeouts (2-10s)
- **Fallback behavior**: Default to Seoul coordinates when location unavailable

### Platform-Specific Configuration

#### Android
- **Google Maps API Key**: Must be set in `android/app/src/main/AndroidManifest.xml:12`
- Required permissions: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `INTERNET`

#### iOS
- Location usage description in `ios/Runner/Info.plist:31-32`
- File sharing enabled for log access
- Embedded views enabled for Google Maps integration

## Important Development Notes

### Working with Maps
- The app loads markers dynamically based on camera position to maintain performance
- Marker updates are debounced by 300ms to prevent thrashing during map panning
- Always test with large datasets to ensure the 500-marker limit provides good UX

### CSV Data Updates
- When updating CSV files, verify the encoding is CP949/EUC-KR (Korean Windows encoding)
- Seoul data uses different column indices than nationwide data - verify format in `WifiInfo.fromCsv()`
- Test both data sources independently as they use different parsing logic

### Location Services
- All location operations have timeouts to prevent app hangs
- Permission requests are retried once but fallback gracefully on denial
- Default camera position is Seoul (37.5665, 126.9780) at zoom 14.4746

### Firebase Integration
- Firebase initialization happens before `runApp()` in the same zone
- All errors are automatically reported to Crashlytics
- LogService provides local debugging alternative to Crashlytics

### Performance Considerations
- CSV loading happens on app startup and can take several seconds for large files
- Marker creation uses proximity sorting (O(n log n)) on every camera update
- Consider caching sorted results or implementing spatial indexing for very large datasets
