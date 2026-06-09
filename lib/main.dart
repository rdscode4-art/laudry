import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/socket_service.dart';
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

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await ApiService.instance.loadSession();
  await NotificationService.instance.init();
  _connectSocketIfLoggedIn();

  Get.put(CustomerController(), permanent: true);

  runApp(const RiDealApp());
}

void _connectSocketIfLoggedIn() {
  final api = ApiService.instance;
  if (api.isVendorLoggedIn && api.currentVendorAuth != null) {
    SocketService.instance.connect(api.currentVendorAuth!.token);
  } else if (api.isDeliveryLoggedIn && api.currentDeliveryAuth != null) {
    SocketService.instance.connect(api.currentDeliveryAuth!.token);
  } else if (api.isLoggedIn && api.currentToken != null) {
    SocketService.instance.connect(api.currentToken!);
  }
}

class RiDealApp extends StatelessWidget {
  const RiDealApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'RiDeal Laundry India',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: kAccentBlue,
            primary: kPrimaryBlue,
            secondary: kAccentGreen),
        useMaterial3: true,
        scaffoldBackgroundColor: kLightBg,
        appBarTheme: const AppBarTheme(
            backgroundColor: kPrimaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kAccentBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kAccentBlue, width: 2)),
        ),
      ),
      // _AppWrapper: stops OS notification sound on app open + resume
      home: const _AppWrapper(),
    );
  }
}

// ── App lifecycle wrapper (RiFresh _HomeWrapper pattern) ──────────
// Stops OS notification sound immediately when app opens or resumes
class _AppWrapper extends StatefulWidget {
  const _AppWrapper();
  @override
  State<_AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<_AppWrapper> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // App just opened → stop any lingering OS notification sound
    NotificationService.instance.stopSound();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Came back to foreground → stop OS notification sound immediately
      NotificationService.instance.stopSound();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = ApiService.instance;
    if (api.isDeliveryLoggedIn) {
      final kyc = api.currentDeliveryAuth!.kycStatus;
      if (kyc == 'pending') {
        return DeliveryKycScreen(boyName: api.currentDeliveryAuth!.name);
      } else if (kyc == 'submitted') {
        return const DeliveryKycPendingScreen();
      }
      return DeliveryHomeScreen(boyName: api.currentDeliveryAuth!.name);
    }
    if (api.isLoggedIn) return const CustomerHomeScreen();
    if (api.isVendorLoggedIn) {
      return VendorHomeScreen(vendorName: api.currentVendorAuth!.shopName);
    }
    return const RoleSelectionScreen();
  }
}
