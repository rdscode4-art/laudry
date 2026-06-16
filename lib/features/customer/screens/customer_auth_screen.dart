import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/models/laundry_order.dart';
import '../../../services/api_service.dart';
import '../controllers/customer_controller.dart';
import 'customer_booking_screens.dart';
import 'customer_profile_screens.dart';
import 'customer_home_screen.dart';

class CustomerAuthScreen extends StatefulWidget {
  const CustomerAuthScreen({super.key});
  @override State<CustomerAuthScreen> createState() => _CustomerAuthScreenState();
}
class _CustomerAuthScreenState extends State<CustomerAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController(), _emailCtrl = TextEditingController(), _passCtrl = TextEditingController(), _referralCtrl = TextEditingController();
  bool _isLogin = true, _obscure = true, _isLoading = false;

  @override void dispose() { _nameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose(); _referralCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final email = _emailCtrl.text.trim();
      final password = _passCtrl.text;
      
      final controller = Get.put(CustomerController());
      if (_isLogin) {
        await controller.login(email, password);
      } else {
        await controller.signup(_nameCtrl.text.trim(), email, password, referredBy: _referralCtrl.text.trim());
      }

      if (!mounted) return;
      if (controller.activeSubscription.value != null) {
        Get.offAll(() => const CustomerHomeScreen());
      } else {
        Get.offAll(() => const SubscriptionScreen(isFromAuth: true));
      }
    } catch (err) {
      final message = err is ApiException ? err.message : 'Unable to connect to backend';
      Get.snackbar('Error', message, snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            const SizedBox(height: 10),
            const Text('RiDeal Laundry India', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimaryBlue)),
            const SizedBox(height: 4),
            const Text('Clean Care. Fast Service. Fresh Every Time.', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 20, offset: const Offset(0, 6))]),
              child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(_isLogin ? 'Welcome Back!' : 'Create Account', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimaryBlue)),
                const SizedBox(height: 4),
                Text(_isLogin ? 'Login to continue' : 'Sign up to get started', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 20),
                if (!_isLogin) ...[
                  TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)), validator: (v) => v?.isEmpty == true ? 'Enter name' : null),
                  const SizedBox(height: 14),
                  TextFormField(controller: _referralCtrl, decoration: const InputDecoration(labelText: 'Referral Code (Optional)', prefixIcon: Icon(Icons.card_giftcard))),
                  const SizedBox(height: 14),
                ],
                TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)), validator: (v) => v != null && v.contains('@') ? null : 'Enter valid email'),
                const SizedBox(height: 14),
                TextFormField(controller: _passCtrl, obscureText: _obscure, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscure = !_obscure))), validator: (v) => v != null && v.length >= 6 ? null : 'Min 6 chars'),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_isLogin ? 'Login' : 'Sign Up'),
                ),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_isLogin ? "Don't have an account? " : 'Already have an account? ', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  GestureDetector(onTap: () => setState(() => _isLogin = !_isLogin), child: Text(_isLogin ? 'Sign Up' : 'Login', style: const TextStyle(color: kAccentBlue, fontWeight: FontWeight.bold, fontSize: 13))),
                ]),
                if (_isLogin) ...[
                  const SizedBox(height: 14),
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: kAccentBlue.withOpacity(0.07), borderRadius: BorderRadius.circular(10)),
                      child: const Text('Use your registered email and password to login', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: kAccentBlue))),
                ],
              ])),
            ),
          ]),
        ),
      ),
    );
  }
}
