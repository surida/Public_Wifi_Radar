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

  Set<Marker> _markers = {};
  Set<ClusterManager> _clusterManagers = {};
  List<WifiInfo> _wifiList = [];
  final Map<String, WifiInfo> _markerIdToWifi = {};

  bool _isLoading = true;

  // Default camera position (Seoul)
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.5665, 126.9780),
    zoom: 14.4746,
  );

  static const ClusterManagerId _clusterManagerId =
      ClusterManagerId('wifi_cluster');

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
        "Cluster tapped: ${cluster.markerIds.length} markers at ${cluster.position}");

    // Zoom into the cluster bounds
    final controller = await _controllerCompleter.future;
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(cluster.bounds, 50),
    );
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
        permission = await Geolocator.requestPermission()
            .timeout(const Duration(seconds: 10));
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
          "Got location: ${position.latitude}, ${position.longitude}");

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

  void _createMarkers() {
    final markers = <Marker>{};
    _markerIdToWifi.clear();

    for (var i = 0; i < _wifiList.length; i++) {
      final wifi = _wifiList[i];
      final markerId = MarkerId('wifi_$i');

      _markerIdToWifi[markerId.value] = wifi;

      final marker = Marker(
        markerId: markerId,
        clusterManagerId: _clusterManagerId,
        position: LatLng(wifi.lat, wifi.lng),
        infoWindow: InfoWindow(
          title: wifi.installationPlace,
          snippet: wifi.detailedAddress,
        ),
      );
      markers.add(marker);
    }

    LogService().log("Created ${markers.length} markers with clustering");

    if (mounted) {
      setState(() {
        _markers = markers;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Public WiFi Radar')),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _kGooglePlex,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: _markers,
            clusterManagers: _clusterManagers,
            onMapCreated: (GoogleMapController controller) {
              _controllerCompleter.complete(controller);
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
