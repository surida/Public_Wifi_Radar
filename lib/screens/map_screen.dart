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

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final Completer<GoogleMapController> _controllerCompleter = Completer();

  Set<Marker> _markers = {};
  Set<ClusterManager> _clusterManagers = {};
  Set<Circle> _circles = {};
  List<WifiInfo> _wifiList = [];
  final Map<String, WifiInfo> _markerIdToWifi = {};

  bool _isLoading = true;
  double _currentZoom = 16.0;
  bool _showDebugOverlay = true;
  Timer? _debounceTimer;

  // 데이터 출처별 마커 수 (디버그용)
  int _seoulMarkerCount = 0;
  int _nationwideMarkerCount = 0;

  // 위치 트래킹 관련
  StreamSubscription<Position>? _positionStream;
  LatLng? _currentPosition;
  bool _isTracking = false; // 초기 상태: 트래킹 OFF
  bool _hasLocationPermission = false;
  bool _isUserDragging = false; // 사용자 드래그 감지용

  // 펄스 애니메이션 관련
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
    _initPulseAnimation();
    _initClusterManager();
    _initializeData();
  }

  void _initPulseAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 2.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseAnimation.addListener(() {
      _updateLocationCircles();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _positionStream?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
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

      // 3. Get Current Location and Start Tracking
      _hasLocationPermission = true;
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
      setState(() {
        _currentPosition = currentLoc;
      });

      _controllerCompleter.future.then((controller) {
        controller.animateCamera(CameraUpdate.newLatLng(currentLoc));
      });

      // 4. Start Position Stream for Real-time Tracking
      _startPositionStream();
    } catch (e) {
      LogService().log("Location Error/Timeout: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startPositionStream() {
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10, // 10미터 이동 시마다 업데이트
          ),
        ).listen((Position position) {
          if (!mounted) return;

          final newPosition = LatLng(position.latitude, position.longitude);
          setState(() {
            _currentPosition = newPosition;
          });

          LogService().log(
            "Position updated: ${position.latitude}, ${position.longitude}",
          );

          // 트래킹 모드일 때만 카메라 이동
          if (_isTracking) {
            _controllerCompleter.future.then((controller) {
              controller.animateCamera(CameraUpdate.newLatLng(newPosition));
            });
          }
        });
  }

  void _updateLocationCircles() {
    // 트래킹 모드가 아니면 펄스 원 숨김 (기본 파란 점 사용)
    if (!_isTracking || _currentPosition == null || !_hasLocationPermission) {
      if (_circles.isNotEmpty) {
        setState(() {
          _circles = {};
        });
      }
      return;
    }

    // 줌 레벨에 따른 원 크기 조절 (미터 단위)
    final baseRadius = _currentZoom >= 16 ? 30.0 : 60.0;
    final pulseRadius = baseRadius * _pulseAnimation.value;

    setState(() {
      _circles = {
        // 바깥 펄스 원 (투명 파랑)
        Circle(
          circleId: const CircleId('pulse_outer'),
          center: _currentPosition!,
          radius: pulseRadius,
          fillColor: Colors.blue.withValues(alpha: 0.15),
          strokeWidth: 0,
        ),
        // 안쪽 고정 원 (진한 파랑)
        Circle(
          circleId: const CircleId('location_inner'),
          center: _currentPosition!,
          radius: baseRadius * 0.4,
          fillColor: Colors.blue,
          strokeColor: Colors.white,
          strokeWidth: 3,
        ),
      };
    });
  }

  /// 위치 버튼 탭: 트래킹 토글
  void _onLocationButtonTap() {
    if (_currentPosition == null) return;

    // 트래킹 중이면 OFF, 아니면 ON
    if (_isTracking) {
      _disableTracking();
      LogService().log("Tracking disabled - button tapped");
    } else {
      setState(() {
        _isTracking = true;
      });

      // 애니메이션 시작 + 현재 위치로 이동
      _pulseController.repeat(reverse: true);
      _controllerCompleter.future.then((controller) {
        controller.animateCamera(CameraUpdate.newLatLng(_currentPosition!));
      });

      LogService().log("Tracking enabled - moved to current location");
    }
  }

  /// 트래킹 비활성화 (지도 드래그 시 호출)
  void _disableTracking() {
    if (!_isTracking) return;

    setState(() {
      _isTracking = false;
      _circles = {};
    });
    _pulseController.stop();

    LogService().log("Tracking disabled - user dragged map");
  }

  String _getLocalizedText(String text) {
    if (Localizations.localeOf(context).languageCode == 'en') {
      return KoreanRomanizationConverter().romanize(text);
    }
    return text;
  }

  /// 데이터 출처에 따른 마커 아이콘 반환 (디버그 모드에서만 색상 구분)
  BitmapDescriptor _getMarkerIcon(WifiInfo wifi) {
    if (!kDebugMode) {
      return BitmapDescriptor.defaultMarker; // 릴리즈: 기본 빨간색
    }

    switch (wifi.dataSource) {
      case WifiDataSource.seoul:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      case WifiDataSource.nationwide:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
  }

  /// 데이터 출처 표시 텍스트 (디버그 모드용)
  String _getSourcePrefix(WifiDataSource source) {
    switch (source) {
      case WifiDataSource.seoul:
        return '[Seoul] ';
      case WifiDataSource.nationwide:
        return '[Gov] ';
    }
  }

  void _createMarkers({LatLng? center}) {
    if (_wifiList.isEmpty) return;

    final markers = <Marker>{};
    _markerIdToWifi.clear();

    // 출처별 카운터 초기화
    int seoulCount = 0;
    int nationwideCount = 0;

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

      // 출처별 카운터 증가
      if (wifi.dataSource == WifiDataSource.seoul) {
        seoulCount++;
      } else {
        nationwideCount++;
      }

      // 디버그 모드에서만 출처 prefix 추가
      final snippetText = kDebugMode
          ? '${_getSourcePrefix(wifi.dataSource)}${_getLocalizedText(wifi.detailedAddress)}'
          : _getLocalizedText(wifi.detailedAddress);

      final marker = Marker(
        markerId: markerId,
        clusterManagerId: _clusterManagerId,
        position: LatLng(wifi.lat, wifi.lng),
        icon: _getMarkerIcon(wifi),
        infoWindow: InfoWindow(
          title: _getLocalizedText(wifi.installationPlace),
          snippet: snippetText,
        ),
      );
      markers.add(marker);
    }

    // 출처별 카운터 저장
    _seoulMarkerCount = seoulCount;
    _nationwideMarkerCount = nationwideCount;

    LogService().log(
      "Updated markers: $count items (Seoul: $seoulCount, Gov: $nationwideCount) (Center: ${center?.latitude}, ${center?.longitude})",
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
            fontWeight: FontWeight.bold,
            fontSize: 20,
            shadows: [
              Shadow(
                color: Colors.black54,
                blurRadius: 4,
                offset: Offset(1, 1),
              ),
              Shadow(color: Colors.black26, blurRadius: 8),
            ],
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
                Colors.black.withValues(alpha: 0.8),
                Colors.black.withValues(alpha: 0.4),
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 위치 버튼 (1탭 = 트래킹 ON + 현재 위치 이동)
          if (_hasLocationPermission)
            FloatingActionButton.small(
              heroTag: 'location',
              onPressed: _onLocationButtonTap,
              backgroundColor: _isTracking ? Colors.blue : Colors.white,
              child: Icon(
                _isTracking ? Icons.my_location : Icons.location_searching,
                color: _isTracking ? Colors.white : Colors.grey[700],
              ),
            ),
          if (_hasLocationPermission) const SizedBox(height: 8),
          // 디버그 토글 버튼 (Debug 빌드에서만)
          if (kDebugMode)
            FloatingActionButton.small(
              heroTag: 'debug',
              onPressed: () =>
                  setState(() => _showDebugOverlay = !_showDebugOverlay),
              backgroundColor: Colors.black54,
              child: Icon(
                _showDebugOverlay
                    ? Icons.bug_report
                    : Icons.bug_report_outlined,
                color: Colors.white,
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
            myLocationButtonEnabled: false, // 커스텀 버튼 사용
            markers: _markers,
            circles: _circles,
            clusterManagers: _clusterManagers,
            onMapCreated: (GoogleMapController controller) {
              _controllerCompleter.complete(controller);
            },
            onCameraMoveStarted: () {
              // 사용자가 지도를 드래그하기 시작하면 트래킹 해제
              _isUserDragging = true;
              _disableTracking();
            },
            onCameraMove: (CameraPosition position) {
              _currentZoom = position.zoom;
            },
            onCameraIdle: () {
              _isUserDragging = false;
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
                  color: Colors.black.withValues(alpha: 0.7),
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
                    const SizedBox(height: 4),
                    Text(
                      '   🔵 Seoul: $_seoulMarkerCount',
                      style: const TextStyle(color: Colors.lightBlue, fontSize: 11),
                    ),
                    Text(
                      '   🟢 Gov: $_nationwideMarkerCount',
                      style: const TextStyle(color: Colors.lightGreen, fontSize: 11),
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
