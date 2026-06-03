import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/constants/colors.dart';
import 'features/role_selection/screens/role_selection_screen.dart';
import 'services/api_service.dart';
import 'features/customer/controllers/customer_controller.dart';
import 'features/customer/screens/customer_home_screen.dart';
import 'features/vendor/screens/vendor_home_screen.dart';
import 'features/delivery/screens/delivery_home_screen.dart';
import 'features/delivery/screens/delivery_kyc_screen.dart';
import 'features/delivery/screens/delivery_kyc_pending_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.instance.loadSession();
  
  Get.put(CustomerController(), permanent: true);
  
  runApp(const RiDealApp());
}

class RiDealApp extends StatelessWidget {
  const RiDealApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'RiDeal Laundry India',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kAccentBlue, primary: kPrimaryBlue, secondary: kAccentGreen),
        useMaterial3: true,
        scaffoldBackgroundColor: kLightBg,
        appBarTheme: const AppBarTheme(backgroundColor: kPrimaryBlue, foregroundColor: Colors.white, elevation: 0, centerTitle: true),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kAccentBlue, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kAccentBlue, width: 2)),
        ),
      ),
      home: ApiService.instance.isDeliveryLoggedIn
          ? (ApiService.instance.currentDeliveryAuth!.kycStatus == 'pending'
              ? DeliveryKycScreen(boyName: ApiService.instance.currentDeliveryAuth!.name)
              : (ApiService.instance.currentDeliveryAuth!.kycStatus == 'submitted'
                  ? const DeliveryKycPendingScreen()
                  : DeliveryHomeScreen(boyName: ApiService.instance.currentDeliveryAuth!.name)))
          : ApiService.instance.isLoggedIn
              ? const CustomerHomeScreen()
              : (ApiService.instance.isVendorLoggedIn
                  ? VendorHomeScreen(vendorName: ApiService.instance.currentVendorAuth!.shopName)
                  : const RoleSelectionScreen()),
    );
  }
}
