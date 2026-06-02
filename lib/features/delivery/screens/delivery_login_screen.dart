import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../services/api_service.dart';
import 'delivery_home_screen.dart';

class DeliveryLoginScreen extends StatefulWidget {
  const DeliveryLoginScreen({super.key});
  @override State<DeliveryLoginScreen> createState() => _DeliveryLoginScreenState();
}
class _DeliveryLoginScreenState extends State<DeliveryLoginScreen> {
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLogin = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _idCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
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
    final login = _idCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (_isLogin) {
      if (login.isEmpty || pass.isEmpty) {
        _showMessage('Email/Delivery ID and password are required');
        return;
      }
    } else {
      final name = _nameCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      if (name.isEmpty || email.isEmpty || pass.isEmpty) {
        _showMessage('Name, email, and password are required for signup');
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        final result = await ApiService.loginDeliveryBoy(login, pass);
        Get.off(() => DeliveryHomeScreen(boyName: result.name));
      } else {
        final name = _nameCtrl.text.trim();
        final email = _emailCtrl.text.trim();
        final phone = _phoneCtrl.text.trim();

        final result = await ApiService.signupDeliveryBoy(pass, name, email, phone);
        _showMessage('Delivery partner registered successfully. Your ID is ${result.deliveryId}', color: kAccentGreen);
        Get.off(() => DeliveryHomeScreen(boyName: result.name));
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
            Text(_isLogin ? 'RiDeal Delivery' : 'Join RiDeal Delivery', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimaryBlue)),
            const SizedBox(height: 4),
            Text(_isLogin ? 'Login to your delivery account' : 'Sign up as a delivery partner', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 20, offset: const Offset(0, 6))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(_isLogin ? 'Welcome Back!' : 'Create Account', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimaryBlue)),
                const SizedBox(height: 4),
                Text(_isLogin ? 'Sign in to continue' : 'Create your RiDeal delivery partner account', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 22),
                if (!_isLogin) ...[
                  TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Your Name', prefixIcon: Icon(Icons.person_outline))),
                  const SizedBox(height: 14),
                  TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
                  const SizedBox(height: 14),
                  TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined))),
                  const SizedBox(height: 14),
                ],
                if (_isLogin) ...[
                  TextField(
                    controller: _idCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email or Delivery ID',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 14),
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
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: kAccentGreen),
                  child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_isLogin ? 'Login' : 'Sign Up'),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin ? 'Don\'t have an account? Sign Up' : 'Already have an account? Login',
                    style: const TextStyle(color: kAccentGreen, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_isLogin) ...[
                  const SizedBox(height: 14),
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: kAccentGreen.withOpacity(0.07), borderRadius: BorderRadius.circular(10)), child: const Text('Demo: delivery01 / rideal123', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: kAccentGreen))),
                ]
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
