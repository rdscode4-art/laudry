import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/shared_widgets.dart';

import '../../customer/screens/customer_auth_screen.dart';
import '../../delivery/screens/delivery_login_screen.dart';
import '../../vendor/screens/vendor_login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              const SizedBox(height: 16),
              logoWidget(),
              const SizedBox(height: 16),
              const Text('RiDeal Laundry India',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kPrimaryBlue)),
              const SizedBox(height: 6),
              const Text('Clean Care. Fast Service. Fresh Every Time.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 40),
              const Text('Select Your Role', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryBlue)),
              const SizedBox(height: 8),
              Text('Choose how you want to continue', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 28),
              _roleCard(
                icon: Icons.person_outline,
                title: 'Customer',
                subtitle: 'Book laundry pickup & track orders',
                color: kAccentBlue,
                onTap: () => Get.to(() => const CustomerAuthScreen()),
              ),
              const SizedBox(height: 16),
              _roleCard(
                icon: Icons.delivery_dining,
                title: 'Delivery Boy',
                subtitle: 'Manage pickups & deliveries',
                color: kAccentGreen,
                onTap: () => Get.to(() => const DeliveryLoginScreen()),
              ),
              const SizedBox(height: 16),
              _roleCard(
                icon: Icons.store_outlined,
                title: 'Vendor / Laundry',
                subtitle: 'Manage incoming orders & processing',
                color: kOrange,
                onTap: () => Get.to(() => const VendorLoginScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleCard({
    required IconData icon, required String title, required String subtitle,
    required Color color, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kCardBg, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
