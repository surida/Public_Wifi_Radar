import 'dart:async';
import 'package:flutter/material.dart';
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
  List<WifiInfo> _wifiList = [];
  Set<Marker> _markers = {};
  bool _isLoading = true;
  Timer? _debounceTimer;
  
  // Default camera position (Seoul)
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.5665, 126.9780),
    zoom: 14.4746,
  );

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // 1. Load CSV Data
    final csvService = CsvService();
    final data = await csvService.loadWifiData();
    LogService().log("CSV Data Loaded: ${data.length} items");
    
    setState(() => _wifiList = data);

    try {
        // 2. Request Location Permission (with timeout)
        LogService().log("Checking permissions...");
        LocationPermission permission = await Geolocator.checkPermission().timeout(const Duration(seconds: 3));
        LogService().log("Permission status: $permission");
        
        if (permission == LocationPermission.denied) {
            LogService().log("Requesting permission...");
            permission = await Geolocator.requestPermission().timeout(const Duration(seconds: 10)); // Time to click dialog
        }

        if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
            LogService().log("Permission denied.");
            if (mounted) setState(() => _isLoading = false);
            _createMarkers(); // Try showing default markers anyway
            return;
        }

        // 3. Get Current Location
        LogService().log("Getting location...");
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).timeout(const Duration(seconds: 5));
        LogService().log("Got location: ${position.latitude}, ${position.longitude}");
        
        final currentLoc = LatLng(position.latitude, position.longitude);
        _controllerCompleter.future.then((controller) {
            controller.animateCamera(CameraUpdate.newLatLng(currentLoc));
        });
        
    } catch (e) {
        LogService().log("Location Error/Timeout: $e");
    } finally {
        if (mounted) {
            setState(() => _isLoading = false);
            _createMarkers();
        }
    }
  }

  void _createMarkers({LatLng? center}) async {
    LogService().log("Starting _createMarkers");
    final markers = <Marker>{};
    
    // Use provided center or get current location/default
    LatLng centerPoint;
    if (center != null) {
      centerPoint = center;
      LogService().log("Using provided center: ${center.latitude}, ${center.longitude}");
    } else {
      centerPoint = _kGooglePlex.target;
      try {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).timeout(const Duration(seconds: 2));
        centerPoint = LatLng(position.latitude, position.longitude);
      } catch (e) {
        // Ignore error, use default
      }
    }

    LogService().log("Center: ${centerPoint.latitude}, ${centerPoint.longitude}");
    LogService().log("Wifi List size: ${_wifiList.length}");

    if (_wifiList.isEmpty) { 
        LogService().log("Warning: Wifi List is Empty in _createMarkers");
    } else {
        // Sort by distance from center point
        _wifiList.sort((a, b) {
            final double distA = Geolocator.distanceBetween(centerPoint.latitude, centerPoint.longitude, a.lat, a.lng);
            final double distB = Geolocator.distanceBetween(centerPoint.latitude, centerPoint.longitude, b.lat, b.lng);
            return distA.compareTo(distB);
        });
        LogService().log("Sorted Wifi List");
    }

    // Take top 500
    final limit = _wifiList.length > 500 ? 500 : _wifiList.length; 
    
    for (var i = 0; i < limit; i++) {
        final wifi = _wifiList[i];
        if (wifi.lat == 0 || wifi.lng == 0) continue;

        if (i < 3) {
             LogService().log("Adding Marker $i: ${wifi.installationPlace}");
        }

        final marker = Marker(
            markerId: MarkerId('${wifi.lat}_${wifi.lng}'),
            position: LatLng(wifi.lat, wifi.lng),
            infoWindow: InfoWindow(
              title: wifi.installationPlace,
              snippet: wifi.detailedAddress,
            ),
        );
        markers.add(marker);
    }

    LogService().log("Final Marker Count: ${markers.length}");

    setState(() {
      _markers = markers;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Public WiFi Radar')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
            LogService().log("Debug Refresh Pressed");
            _createMarkers();
        },
        child: const Icon(Icons.refresh),
      ),
      body: Stack(
        children: [
            GoogleMap(
                mapType: MapType.normal,
                initialCameraPosition: _kGooglePlex,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                markers: _markers,
                onMapCreated: (GoogleMapController controller) {
                  _controllerCompleter.complete(controller);
                },
                onCameraIdle: () async {
                  // Debounce: Wait 300ms after camera stops moving
                  _debounceTimer?.cancel();
                  _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
                    // When camera stops moving, update markers based on new center
                    final controller = await _controllerCompleter.future;
                    final cameraPosition = await controller.getVisibleRegion();
                    final center = LatLng(
                      (cameraPosition.northeast.latitude + cameraPosition.southwest.latitude) / 2,
                      (cameraPosition.northeast.longitude + cameraPosition.southwest.longitude) / 2,
                    );
                    LogService().log("Camera idle, updating markers for center: ${center.latitude}, ${center.longitude}");
                    _createMarkers(center: center);
                  });
                },
            ),
            if (_isLoading)
                const Center(
                    child: CircularProgressIndicator(),
                ),
        ],
      ),
    );
  }
}
