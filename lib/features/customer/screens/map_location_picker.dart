import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/constants/colors.dart';
import '../controllers/customer_controller.dart';

class MapLocationPickerScreen extends StatefulWidget {
  const MapLocationPickerScreen({super.key});

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng _currentLatLng = const LatLng(28.6139, 77.2090); // Default: New Delhi
  bool _isSearching = false;
  bool _isLocating = false;
  bool _isCameraMoving = false;
  String _currentAddressDisplay = "Searching address...";

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final ctrl = CustomerController.instance;
    if (ctrl.currentLatitude.value != 0.0) {
      _currentLatLng = LatLng(ctrl.currentLatitude.value, ctrl.currentLongitude.value);
    } else {
      _moveToCurrentLocation();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _moveToCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception("Location services are disabled.");

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception("Location permission denied.");
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception("Location permissions are permanently denied.");
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final newLatLng = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _currentLatLng = newLatLng;
      });

      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newLatLng, 16));
      _reverseGeocode(newLatLng);
    } catch (e) {
      Get.snackbar(
        "Location Error",
        e.toString().replaceAll("Exception: ", ""),
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLocating = false);
    }
  }

  Future<void> _searchAndFlyToAddress(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final target = LatLng(loc.latitude, loc.longitude);
        
        setState(() {
          _currentLatLng = target;
        });

        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
        _reverseGeocode(target);
        FocusScope.of(context).unfocus();
      } else {
        throw Exception("No location matches found.");
      }
    } catch (e) {
      Get.snackbar(
        "Search Failed",
        "Could not resolve searched location.",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _reverseGeocode(LatLng coordinates) async {
    setState(() {
      _currentAddressDisplay = "Searching address...";
    });
    try {
      final placemarks = await placemarkFromCoordinates(coordinates.latitude, coordinates.longitude);
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        setState(() {
          _currentAddressDisplay = "${pm.name}, ${pm.subLocality}, ${pm.locality}, ${pm.postalCode}, ${pm.country}";
        });
      }
    } catch (_) {
      setState(() {
        _currentAddressDisplay = "Unknown location";
      });
    }
  }

  void _confirmLocation() {
    final ctrl = CustomerController.instance;
    ctrl.currentLatitude.value = _currentLatLng.latitude;
    ctrl.currentLongitude.value = _currentLatLng.longitude;
    ctrl.currentAddress.value = _currentAddressDisplay;
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLatLng,
              zoom: 15,
            ),
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
            }.toSet(),
            onMapCreated: (ctrl) {
              _mapController = ctrl;
              _reverseGeocode(_currentLatLng);
            },
            onCameraMoveStarted: () {
              setState(() => _isCameraMoving = true);
            },
            onCameraMove: (pos) {
              _currentLatLng = pos.target;
            },
            onCameraIdle: () {
              setState(() => _isCameraMoving = false);
              _reverseGeocode(_currentLatLng);
            },
            zoomControlsEnabled: false,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: false,
          ),

          // Floating Center Pin
          IgnorePointer(
            child: Center(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: _isCameraMoving ? 52 : 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_pin,
                      color: kAccentBlue,
                      size: 48,
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _isCameraMoving ? 14 : 6,
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: _isCameraMoving ? 8 : 2,
                            spreadRadius: _isCameraMoving ? 4 : 1,
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Search Bar
          Positioned(
            top: 12, left: 12, right: 12,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
              ),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search place / area...',
                  prefixIcon: const Icon(Icons.search, color: kPrimaryBlue),
                  suffixIcon: _isSearching
                      ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                      : IconButton(
                          icon: const Icon(Icons.arrow_forward, color: kPrimaryBlue),
                          onPressed: () => _searchAndFlyToAddress(_searchCtrl.text),
                        ),
                  filled: true, fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onSubmitted: _searchAndFlyToAddress,
              ),
            ),
          ),

          // Current Location Button
          Positioned(
            right: 12, bottom: 150,
            child: FloatingActionButton(
              heroTag: "recenter_location",
              onPressed: _moveToCurrentLocation,
              backgroundColor: Colors.white,
              foregroundColor: kPrimaryBlue,
              child: _isLocating 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location),
            ),
          ),

          // Bottom Sheet with confirm button
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Selected Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kPrimaryBlue)),
                  const SizedBox(height: 8),
                  Text(_currentAddressDisplay, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isCameraMoving ? null : _confirmLocation,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    child: const Text('Confirm Location'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
