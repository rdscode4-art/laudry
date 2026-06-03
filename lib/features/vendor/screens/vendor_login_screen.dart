import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../services/api_service.dart';
import 'vendor_home_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class VendorLoginScreen extends StatefulWidget {
  const VendorLoginScreen({super.key});
  @override State<VendorLoginScreen> createState() => _VendorLoginScreenState();
}
class _VendorLoginScreenState extends State<VendorLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _shopNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLogin = true;
  bool _isLoading = false;
  double? _latitude;
  double? _longitude;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _shopNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String message, {Color color = Colors.redAccent}) {
    Get.snackbar(
      'Notification',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: color,
      colorText: Colors.white,
      margin: const EdgeInsets.all(10),
    );
  }

  Future<void> _fetchLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage('Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showMessage('Location permissions are denied');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showMessage('Location permissions are permanently denied, we cannot request permissions.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _latitude = position.latitude;
      _longitude = position.longitude;

      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        _addressCtrl.text = "${place.name}, ${place.subLocality}, ${place.locality}, ${place.postalCode}, ${place.country}";
      }
    } catch (e) {
      _showMessage('Failed to fetch location: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (_isLogin) {
      if (email.isEmpty || pass.isEmpty) {
        _showMessage('Email and password are required');
        return;
      }
    } else {
      final shopName = _shopNameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final address = _addressCtrl.text.trim();
      if (email.isEmpty || shopName.isEmpty || pass.isEmpty) {
        _showMessage('Email, shop name and password are required for signup');
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        final result = await ApiService.loginVendor(email, pass);
        ApiService.instance.currentVendorAuth = result;
        Get.off(() => VendorHomeScreen(vendorName: result.shopName));
      } else {
        final shopName = _shopNameCtrl.text.trim();
        final phone = _phoneCtrl.text.trim();
        final address = _addressCtrl.text.trim();

        if (_latitude == null || _longitude == null) {
          _showMessage('Please fetch your shop location first');
          setState(() => _isLoading = false);
          return;
        }

        final result = await ApiService.signupVendor(email, pass, shopName, phone, address, latitude: _latitude, longitude: _longitude);
        ApiService.instance.currentVendorAuth = result;
        _showMessage('Vendor registered successfully. Your Vendor ID is ${result.vendorId}', color: kOrange);
        Get.off(() => VendorHomeScreen(vendorName: result.shopName));
      }
    } on ApiException catch (err) {
      _showMessage(err.message);
    } catch (_) {
      _showMessage('Unable to connect to backend');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(children: [
            logoWidget(),
            const SizedBox(height: 12),
            Text(_isLogin ? 'RiDeal Vendor Portal' : 'Join RiDeal Vendor', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimaryBlue)),
            const SizedBox(height: 4),
            Text(_isLogin ? 'Laundry / Dry Cleaner Partner' : 'Create your vendor account', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 20, offset: const Offset(0, 6))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(_isLogin ? 'Vendor Login' : 'Vendor Sign Up', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimaryBlue)),
                const SizedBox(height: 4),
                Text(_isLogin ? 'Login to manage your orders' : 'Register your laundry shop to receive orders', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 22),
                if (!_isLogin) ...[
                  TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined))),
                  const SizedBox(height: 14),
                  TextField(controller: _shopNameCtrl, decoration: const InputDecoration(labelText: 'Shop Name', prefixIcon: Icon(Icons.storefront))),
                  const SizedBox(height: 14),
                  TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined))),
                  const SizedBox(height: 14),
                  TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on_outlined))),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _fetchLocation,
                    icon: const Icon(Icons.my_location, size: 18),
                    label: Text(_latitude == null ? 'Fetch My Shop Location' : 'Location Captured ✅'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _latitude == null ? kPrimaryBlue : kAccentGreen,
                      side: BorderSide(color: _latitude == null ? kPrimaryBlue : kAccentGreen),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (_isLogin) ...[
                  TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined))),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscure = !_obscure)),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: kOrange),
                  child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_isLogin ? 'Login' : 'Sign Up'),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin ? 'Don\'t have an account? Sign Up' : 'Already have an account? Login',
                    style: const TextStyle(color: kOrange, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_isLogin) ...[
                  const SizedBox(height: 14),
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: kOrange.withOpacity(0.07), borderRadius: BorderRadius.circular(10)), child: const Text('Demo: vendor@rideal.com / rideal123', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: kOrange))),
                ]
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
