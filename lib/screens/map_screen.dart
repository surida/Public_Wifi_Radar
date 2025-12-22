import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:public_wifi_radar/models/wifi_info.dart';
import 'package:public_wifi_radar/services/csv_service.dart';

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
    // 1. Request Location Permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
       // Handle permission denied
       if (mounted) {
         setState(() => _isLoading = false);
       }
       return;
    }

    // 2. Get Current Location
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final GoogleMapController controller = await _controllerCompleter.future;
      controller.animateCamera(CameraUpdate.newLatLng(
        LatLng(position.latitude, position.longitude),
      ));
    } catch (e) {
      print("Error getting location: $e");
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _createMarkers() {
    final markers = <Marker>{};
    // Safe limit for simple markers
    final limit = _wifiList.length > 500 ? 500 : _wifiList.length; 
    
    for (var i = 0; i < limit; i++) {
        final wifi = _wifiList[i];
        if (wifi.lat == 0 || wifi.lng == 0) continue;

        final marker = Marker(
            markerId: MarkerId(i.toString()),
            position: LatLng(wifi.lat, wifi.lng),
            infoWindow: InfoWindow(
              title: wifi.installationPlace,
              snippet: wifi.detailedAddress,
            ),
        );
        markers.add(marker);
    }

    setState(() {
      _markers = markers;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Public WiFi Radar')),
      body: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: _kGooglePlex,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        markers: _markers,
        onMapCreated: (GoogleMapController controller) {
          _controllerCompleter.complete(controller);
        },
      ),
    );
  }
}
