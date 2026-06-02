import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../services/api_service.dart';
import 'vendor_home_screen.dart';

class VendorLoginScreen extends StatefulWidget {
  const VendorLoginScreen({super.key});
  @override State<VendorLoginScreen> createState() => _VendorLoginScreenState();
}
class _VendorLoginScreenState extends State<VendorLoginScreen> {
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _shopNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLogin = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _idCtrl.dispose();
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

  Future<void> _submit() async {
    final id = _idCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (_isLogin) {
      if (id.isEmpty || pass.isEmpty) {
        _showMessage('Vendor ID and password are required');
        return;
      }
    } else {
      final shopName = _shopNameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final address = _addressCtrl.text.trim();
      if (shopName.isEmpty || pass.isEmpty) {
        _showMessage('Shop name and password are required for signup');
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        final result = await ApiService.loginVendor(id, pass);
        ApiService.instance.currentVendorAuth = result;
        Get.off(() => VendorHomeScreen(vendorName: result.shopName));
      } else {
        final shopName = _shopNameCtrl.text.trim();
        final phone = _phoneCtrl.text.trim();
        final address = _addressCtrl.text.trim();

        final result = await ApiService.signupVendor(pass, shopName, phone, address);
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
                  TextField(controller: _shopNameCtrl, decoration: const InputDecoration(labelText: 'Shop Name', prefixIcon: Icon(Icons.storefront))),
                  const SizedBox(height: 14),
                  TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined))),
                  const SizedBox(height: 14),
                  TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on_outlined))),
                  const SizedBox(height: 14),
                ],
                if (_isLogin) ...[
                  TextField(controller: _idCtrl, decoration: const InputDecoration(labelText: 'Vendor ID', prefixIcon: Icon(Icons.store_outlined))),
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
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: kOrange.withOpacity(0.07), borderRadius: BorderRadius.circular(10)), child: const Text('Demo: vendor01 / rideal123', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: kOrange))),
                ]
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
