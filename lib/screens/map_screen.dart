import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:public_wifi_radar/l10n/app_localizations.dart';
import 'package:korean_romanization_converter/korean_romanization_converter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:public_wifi_radar/models/wifi_info.dart';
import 'package:public_wifi_radar/services/csv_service.dart';
import 'package:public_wifi_radar/services/log_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controllerCompleter = Completer();

  Set<Marker> _markers = {};
  Set<ClusterManager> _clusterManagers = {};
  List<WifiInfo> _wifiList = [];
  final Map<String, WifiInfo> _markerIdToWifi = {};

  bool _isLoading = true;
  double _currentZoom = 16.0;
  bool _showDebugOverlay = true;
  Timer? _debounceTimer;

  // Default camera position (Seoul)
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.5665, 126.9780),
    zoom: 16.0,
  );

  // 줌 레벨 제한
  static const double _minZoomLevel = 10.0; // 최소 줌 (시/도 단위)
  static const double _maxZoomLevel = 20.0; // 최대 줌 (건물 단위)

  static const ClusterManagerId _clusterManagerId = ClusterManagerId(
    'wifi_cluster',
  );

  /// 줌 레벨에 따른 마커 최대 개수 반환
  int _getMarkerCountForZoom(double zoom) {
    if (zoom <= 10) return 200; // 시/도 단위
    if (zoom <= 12) return 500; // 구/군 단위
    if (zoom <= 14) return 1000; // 동네 단위
    return 2000; // 상세 보기
  }

  @override
  void initState() {
    super.initState();
    _initClusterManager();
    _initializeData();
  }

  void _initClusterManager() {
    _clusterManagers = {
      ClusterManager(
        clusterManagerId: _clusterManagerId,
        onClusterTap: _onClusterTap,
      ),
    };
  }

  void _onClusterTap(Cluster cluster) async {
    LogService().log(
      "Cluster tapped: ${cluster.markerIds.length} markers at ${cluster.position}",
    );

    // Zoom into the cluster bounds
    final controller = await _controllerCompleter.future;
    controller.animateCamera(CameraUpdate.newLatLngBounds(cluster.bounds, 50));
  }

  Future<void> _initializeData() async {
    // 1. Load CSV Data
    final csvService = CsvService();
    final data = await csvService.loadWifiData();
    LogService().log("CSV Data Loaded: ${data.length} items");

    // Filter out invalid coordinates
    final validData = data.where((w) => w.lat != 0 && w.lng != 0).toList();
    LogService().log("Valid WiFi locations: ${validData.length}");

    _wifiList = validData;
    _createMarkers();

    try {
      // 2. Request Location Permission (with timeout)
      LogService().log("Checking permissions...");
      LocationPermission permission = await Geolocator.checkPermission()
          .timeout(const Duration(seconds: 3));
      LogService().log("Permission status: $permission");

      if (permission == LocationPermission.denied) {
        LogService().log("Requesting permission...");
        permission = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 10),
        );
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        LogService().log("Permission denied.");
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 3. Get Current Location
      LogService().log("Getting location...");
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 5));
      LogService().log(
        "Got location: ${position.latitude}, ${position.longitude}",
      );

      final currentLoc = LatLng(position.latitude, position.longitude);
      _controllerCompleter.future.then((controller) {
        controller.animateCamera(CameraUpdate.newLatLng(currentLoc));
      });
    } catch (e) {
      LogService().log("Location Error/Timeout: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getLocalizedText(String text) {
    if (Localizations.localeOf(context).languageCode == 'en') {
      return KoreanRomanizationConverter().romanize(text);
    }
    return text;
  }

  void _createMarkers({LatLng? center}) {
    if (_wifiList.isEmpty) return;

    final markers = <Marker>{};
    _markerIdToWifi.clear();

    // 중심 좌표가 있으면 거리순 정렬
    if (center != null) {
      _wifiList.sort((a, b) {
        final distA = Geolocator.distanceBetween(
          center.latitude,
          center.longitude,
          a.lat,
          a.lng,
        );
        final distB = Geolocator.distanceBetween(
          center.latitude,
          center.longitude,
          b.lat,
          b.lng,
        );
        return distA.compareTo(distB);
      });
    }

    // 줌 레벨에 따른 마커 개수 조절
    final maxCount = _getMarkerCountForZoom(_currentZoom);
    final count = _wifiList.length > maxCount ? maxCount : _wifiList.length;
    for (var i = 0; i < count; i++) {
      final wifi = _wifiList[i];
      final markerId = MarkerId(
        'wifi_${wifi.lat}_${wifi.lng}',
      ); // ID에 좌표 포함하여 고유성 보장

      _markerIdToWifi[markerId.value] = wifi;

      final marker = Marker(
        markerId: markerId,
        clusterManagerId: _clusterManagerId,
        position: LatLng(wifi.lat, wifi.lng),
        infoWindow: InfoWindow(
          title: _getLocalizedText(wifi.installationPlace),
          snippet: _getLocalizedText(wifi.detailedAddress),
        ),
      );
      markers.add(marker);
    }

    LogService().log(
      "Updated markers: $count items (Center: ${center?.latitude}, ${center?.longitude})",
    );

    if (mounted) {
      setState(() {
        _markers = markers;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.appTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.blue.shade700.withOpacity(0.9),
                Colors.blue.shade500.withOpacity(0.6),
                Colors.transparent,
              ],
            ),
          ),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      floatingActionButton: kDebugMode
          ? FloatingActionButton.small(
              onPressed: () =>
                  setState(() => _showDebugOverlay = !_showDebugOverlay),
              backgroundColor: Colors.black54,
              child: Icon(
                _showDebugOverlay
                    ? Icons.bug_report
                    : Icons.bug_report_outlined,
                color: Colors.white,
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _kGooglePlex,
            minMaxZoomPreference: const MinMaxZoomPreference(
              _minZoomLevel,
              _maxZoomLevel,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: _markers,
            clusterManagers: _clusterManagers,
            onMapCreated: (GoogleMapController controller) {
              _controllerCompleter.complete(controller);
            },
            onCameraMove: (CameraPosition position) {
              _currentZoom = position.zoom;
            },
            onCameraIdle: () {
              _debounceTimer?.cancel();
              _debounceTimer = Timer(
                const Duration(milliseconds: 500),
                () async {
                  final controller = await _controllerCompleter.future;
                  final bounds = await controller.getVisibleRegion();
                  final center = LatLng(
                    (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
                    (bounds.northeast.longitude + bounds.southwest.longitude) /
                        2,
                  );
                  _createMarkers(center: center);
                },
              );
            },
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          // Debug overlay (Debug 빌드에서만 표시)
          if (kDebugMode && _showDebugOverlay)
            Positioned(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🔍 Zoom: ${_currentZoom.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '📡 WiFi Data: ${_wifiList.length} (${(100 / CsvService.sampleRate).toStringAsFixed(0)}%)',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '📍 Markers: ${_markers.length}/${_getMarkerCountForZoom(_currentZoom)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.infoTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📡 ${l10n.dataSource}'),
              const SizedBox(height: 8),
              Text('📲 ${l10n.appVersion}: 1.0.0'),
              const SizedBox(height: 8),
              Text('📧 ${l10n.contact}: contact@publicwifiradar.com'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }
}
