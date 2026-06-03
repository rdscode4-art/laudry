import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../services/api_service.dart';
import 'delivery_login_screen.dart';
import 'delivery_home_screen.dart';

class DeliveryKycPendingScreen extends StatefulWidget {
  const DeliveryKycPendingScreen({super.key});

  @override
  State<DeliveryKycPendingScreen> createState() => _DeliveryKycPendingScreenState();
}

class _DeliveryKycPendingScreenState extends State<DeliveryKycPendingScreen> {
  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      await ApiService.fetchDriverProfile();
      final auth = ApiService.instance.currentDeliveryAuth;
      if (auth != null && auth.kycStatus != 'pending' && auth.kycStatus != 'submitted') {
        Get.offAll(() => DeliveryHomeScreen(boyName: auth.name));
      }
    } catch (e) {
      debugPrint('Failed to fetch profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightBg,
      appBar: AppBar(title: const Text('Under Review'), automaticallyImplyLeading: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pending_actions, size: 80, color: kOrange),
              const SizedBox(height: 24),
              const Text(
                'KYC Under Review',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kPrimaryBlue),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your KYC documents have been submitted successfully and are currently under review by our admin team. You will be notified once they are approved.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 48),
              OutlinedButton(
                onPressed: () => Get.offAll(() => const DeliveryLoginScreen()),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  side: const BorderSide(color: kPrimaryBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Back to Login', style: TextStyle(fontSize: 16, color: kPrimaryBlue, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
