import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/enums.dart';
import '../../../core/models/laundry_order.dart';
import '../../../services/api_service.dart';
import '../../../services/notification_service.dart';
import '../../role_selection/screens/role_selection_screen.dart';
// Razorpay is not supported on web
import 'package:razorpay_flutter/razorpay_flutter.dart'
    if (dart.library.html) '../../../core/stubs/razorpay_stub.dart';

class CustomerController extends GetxController {
  static CustomerController get instance => Get.find();

  final Rx<CustomerSession?> session = Rx<CustomerSession?>(null);
  final RxList<Map<String, dynamic>> activeOrders = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> pastOrders = <Map<String, dynamic>>[].obs;
  
  // Wallet State
  final RxDouble walletBalance = 0.0.obs;
  final RxList<Map<String, dynamic>> walletHistory = <Map<String, dynamic>>[].obs;

  // Complaints State
  final RxList<Map<String, dynamic>> complaints = <Map<String, dynamic>>[].obs;

  // Order Ratings State
  final RxMap<String, int> orderRatings = <String, int>{}.obs;

  // Subscriptions State
  final RxList<Map<String, dynamic>> availablePlans = <Map<String, dynamic>>[].obs;
  final Rx<Map<String, dynamic>?> activeSubscription = Rx<Map<String, dynamic>?>(null);

  // Active Booking State
  final Rx<Map<String, dynamic>?> selectedPlan = Rx<Map<String, dynamic>?>(null);
  final RxString selectedService = 'Laundry'.obs;
  // Dynamic Items & Services State
  final RxList<Map<String, dynamic>> dynamicServices = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> dynamicItems = <Map<String, dynamic>>[].obs;
  
  final Map<String, RxInt> cartItems = <String, RxInt>{}.obs;

  int get totalCartItems => cartItems.values.fold(0, (v, q) => v + q.value);

  // Address State
  final RxList<Map<String, dynamic>> addresses = <Map<String, dynamic>>[].obs;

  // Location State
  var currentLatitude = RxDouble(0.0);
  final RxDouble currentLongitude = 0.0.obs;
  final RxString currentAddress = 'Locating...'.obs;
  var isFetchingLocation = false.obs;

  late Razorpay _razorpay;
  final RxString selectedPaymentMethod = 'COD'.obs;
  String _pendingOrderAddress = '';

  bool _isRechargingWallet = false;
  double _rechargeAmount = 0.0;

  bool _isSubscribing = false;
  String _pendingPlanCode = '';

  final RxString referralCode = ''.obs;

  // Platform Pricing State
  final RxDouble taxPercentage = 5.0.obs;
  final RxDouble deliveryCharge = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }

    fetchPlans(); // Always fetch plans on startup
    if (ApiService.instance.isLoggedIn) {
      // Create session from local stored data
      session.value = CustomerSession(
        id: ApiService.instance.currentId ?? '',
        name: ApiService.instance.currentName ?? '',
        email: ApiService.instance.currentEmail ?? '',
        token: ApiService.instance.currentToken ?? '',
        vendorId: ApiService.instance.preferredVendorId,
        referralCode: ApiService.instance.currentReferralCode,
      );
      referralCode.value = session.value?.referralCode ?? '';
      loadDashboardData();
    }
  }

  @override
  void onClose() {
    if (!kIsWeb) _razorpay.clear();
    super.onClose();
  }

  Future<void> loadDashboardData() async {
    await Future.wait([
      fetchOrders(),
      fetchWallet(),
      fetchComplaints(),
      fetchAddresses(),
      fetchActiveSubscription(),
      fetchItems(),
      fetchServices(),
      fetchPlatformSettings(),
    ]);
  }

  Future<void> fetchPlatformSettings() async {
    try {
      final settings = await ApiService.instance.fetchPlatformSettings();
      if (settings['tax_percentage'] != null) taxPercentage.value = (settings['tax_percentage'] as num).toDouble();
      if (settings['delivery_charge'] != null) deliveryCharge.value = (settings['delivery_charge'] as num).toDouble();
    } catch (e) {
      debugPrint('Error fetching platform settings: $e');
    }
  }

  Future<void> fetchServices() async {
    try {
      final data = await ApiService.instance.fetchServices();
      dynamicServices.value = data;
    } catch (e) {
      debugPrint('Failed to fetch services: $e');
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final s = await ApiService.loginCustomer(email, password);
      session.value = s;
      referralCode.value = s.referralCode ?? '';
      await NotificationService.instance.registerToken('customer', s.id);
      await loadDashboardData();
    } catch (e) {
      Get.snackbar('Login Failed', e.toString(), backgroundColor: Colors.red, colorText: Colors.white);
      rethrow;
    }
  }

  Future<void> signup(String name, String email, String password, {String? referredBy}) async {
    try {
      final s = await ApiService.signupCustomer(name, email, password, referredBy: referredBy);
      session.value = s;
      referralCode.value = s.referralCode ?? '';
      await NotificationService.instance.registerToken('customer', s.id);
      await loadDashboardData();
    } catch (e) {
      Get.snackbar('Signup Failed', e.toString(), backgroundColor: Colors.red, colorText: Colors.white);
      rethrow;
    }
  }

  Future<void> logout() async {
    await ApiService.instance.logout();
    session.value = null;
    activeOrders.clear();
    pastOrders.clear();
    walletHistory.clear();
    complaints.clear();
    addresses.clear();
    activeSubscription.value = null;
    Get.offAll(() => const RoleSelectionScreen());
  }

  Future<void> fetchOrders() async {
    try {
      final orders = await ApiService.instance.fetchOrders();
      activeOrders.clear();
      pastOrders.clear();
      
      for (var o in orders) {
        if (o['status'] == 'delivered' || o['status'] == 'cancelled') {
          pastOrders.add(o);
        } else {
          activeOrders.add(o);
        }
      }
    } catch (e) {
      print('Failed to fetch orders: $e');
    }
  }

  Future<void> fetchItems() async {
    try {
      final items = await ApiService.instance.fetchItems();
      dynamicItems.assignAll(items);
      // Initialize cart items for newly fetched items if not already present
      for (var item in items) {
        if (!cartItems.containsKey(item['name'])) {
          cartItems[item['name']] = 0.obs;
        }
      }
    } catch (e) {
      print('Failed to fetch items: $e');
    }
  }

  double calculateItemSubtotal() {
    double total = 0;
    cartItems.forEach((key, val) {
      if (val.value > 0) {
        final itemDetails = dynamicItems.firstWhere((e) => e['name'] == key, orElse: () => {});
        if (itemDetails.isNotEmpty && itemDetails['price'] != null) {
          total += (itemDetails['price'] as num).toDouble() * val.value;
        }
      }
    });
    return total;
  }

  double calculateTax() {
    return calculateItemSubtotal() * (taxPercentage.value / 100);
  }

  double calculateGrandTotal() {
    double subtotal = calculateItemSubtotal();
    if (subtotal == 0) return 0;
    return subtotal + calculateTax() + deliveryCharge.value;
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final success = await ApiService.verifyRazorpayPayment(
      razorpayOrderId: response.orderId ?? '',
      razorpayPaymentId: response.paymentId ?? '',
      razorpaySignature: response.signature ?? '',
    );

    if (success) {
      if (_isRechargingWallet) {
        await rechargeWallet(_rechargeAmount);
        Get.back(); // close the recharge bottom sheet if open
        Get.snackbar('Success', 'Wallet recharged successfully!', backgroundColor: Colors.green, colorText: Colors.white);
      } else if (_isSubscribing) {
        try {
          await ApiService.instance.purchaseCustomerPlan(_pendingPlanCode);
          await fetchActiveSubscription();
          Get.snackbar('Success', 'Subscribed to plan successfully!', backgroundColor: Colors.green, colorText: Colors.white);
        } catch (e) {
          Get.snackbar('Error', 'Failed to activate subscription: $e', backgroundColor: Colors.red, colorText: Colors.white);
        }
      } else {
        await _submitOrder(_pendingOrderAddress, 'ONLINE', 'paid', response.paymentId);
        Get.snackbar('Success', 'Payment Successful! Booking Confirmed.', backgroundColor: Colors.green, colorText: Colors.white);
      }
    } else {
      Get.snackbar('Error', 'Payment verification failed.', backgroundColor: Colors.red, colorText: Colors.white);
    }

    _isRechargingWallet = false;
    _rechargeAmount = 0.0;
    _isSubscribing = false;
    _pendingPlanCode = '';
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _isRechargingWallet = false;
    _rechargeAmount = 0.0;
    _isSubscribing = false;
    _pendingPlanCode = '';
    Get.snackbar('Payment Failed', response.message ?? 'Payment was cancelled or failed.', backgroundColor: Colors.red, colorText: Colors.white);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    Get.snackbar('Wallet', 'External wallet selected: ${response.walletName}');
  }

  Future<void> initiateOnlinePayment(String address) async {
    final total = calculateGrandTotal();
    if (total <= 0) return;

    _pendingOrderAddress = address;

    if (kIsWeb) {
      Get.snackbar('Not Supported', 'Online payment is not available on web. Please use COD.',
          backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    try {
      final orderData = await ApiService.createRazorpayOrder(total);
      final options = {
        'key': 'rzp_live_RoLpvsh1Qs9Cfs', // Real Key ID
        'amount': orderData['amount'],
        'name': 'Rideal Laundry',
        'description': 'Laundry Service Booking',
        'order_id': orderData['id'],
        'prefill': {
          'contact': '9876543210',
          'email': session.value?.email ?? '',
        }
      };
      _razorpay.open(options);
    } catch (e) {
      Get.snackbar('Error', 'Failed to initialize payment: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<bool> createOrder(String address) async {
    final method = selectedPaymentMethod.value;
    if (method == 'ONLINE') {
      await initiateOnlinePayment(address);
      return false; // Dialog will be handled in success listener
    } else if (method == 'WALLET') {
      final total = calculateGrandTotal();
      if (walletBalance.value < total) {
        Get.snackbar('Error', 'Insufficient wallet balance. Please recharge your wallet.', backgroundColor: Colors.red, colorText: Colors.white);
        return false;
      }
      return await _submitOrder(address, 'WALLET', 'paid', null);
    } else {
      return await _submitOrder(address, 'COD', 'pending', null);
    }
  }

  Future<bool> _submitOrder(String address, String method, String status, String? paymentId) async {
    try {
      final itemsMap = <String, int>{};
      cartItems.forEach((key, val) {
        if (val.value > 0) itemsMap[key] = val.value;
      });

      final total = calculateGrandTotal();

      // Resolve vendorId — use session vendorId if present, else pick first available vendor
      String? resolvedVendorId = session.value?.vendorId;
      if (resolvedVendorId == null || resolvedVendorId.isEmpty) {
        try {
          final vendors = await ApiService.instance.fetchVendors();
          if (vendors.isNotEmpty) resolvedVendorId = vendors.first.id;
        } catch (_) {}
      }

      await ApiService.createOrder(
        customerName: session.value?.name ?? 'Customer',
        customerEmail: session.value?.email ?? '',
        customerPhone: '9876543210',
        customerAddress: address,
        latitude: selectedAddress.value?['latitude'] ?? (currentLatitude.value != 0.0 ? currentLatitude.value : null),
        longitude: selectedAddress.value?['longitude'] ?? (currentLongitude.value != 0.0 ? currentLongitude.value : null),
        service: selectedService.value,
        totalItems: totalCartItems,
        items: itemsMap,
        vendorId: resolvedVendorId,
        totalAmount: total,
        paymentMethod: method,
        paymentStatus: status,
        paymentId: paymentId,
      );
      
      // Clear cart
      for (var val in cartItems.values) { val.value = 0; }
      
      await fetchOrders();
      if (method == 'WALLET') {
        await fetchWallet();
      }
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to create order: $e', backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
  }

  // ── Plans & Subscriptions Integrations ────────────────────────
  Future<void> fetchPlans() async {
    try {
      final list = await ApiService.instance.fetchCustomerPlans();
      availablePlans.assignAll(list);
    } catch (e) { print('Failed to fetch plans: $e'); }
  }

  Future<void> fetchActiveSubscription() async {
    try {
      final sub = await ApiService.instance.fetchActiveSubscription();
      activeSubscription.value = sub;
    } catch (e) { print('Failed to fetch subscription: $e'); }
  }

  Future<void> purchasePlan(String planCode) async {
    final plan = availablePlans.firstWhere((p) => p['code'] == planCode, orElse: () => {});
    if (plan.isEmpty) return;

    final price = (plan['priceMonthly'] ?? plan['price_monthly'] ?? 0) as num;
    if (price <= 0) {
      // Free plan or error
      try {
        await ApiService.instance.purchaseCustomerPlan(planCode);
        await fetchActiveSubscription();
        Get.snackbar('Success', 'Subscribed to plan successfully!', backgroundColor: Colors.green, colorText: Colors.white);
      } catch (e) {
        Get.snackbar('Error', 'Failed to subscribe: $e', backgroundColor: Colors.red, colorText: Colors.white);
      }
      return;
    }

    if (kIsWeb) {
      Get.snackbar('Not Supported', 'Online payment is not available on web.', backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    try {
      _isSubscribing = true;
      _pendingPlanCode = planCode;
      
      final orderData = await ApiService.createRazorpayOrder(price.toDouble());
      final options = {
        'key': 'rzp_live_RoLpvsh1Qs9Cfs', // Real Key ID
        'amount': orderData['amount'],
        'name': 'Rideal Laundry',
        'description': 'Subscription Plan Purchase',
        'order_id': orderData['id'],
        'prefill': {
          'contact': '9876543210',
          'email': session.value?.email ?? '',
        }
      };
      _razorpay.open(options);
    } catch (e) {
      _isSubscribing = false;
      Get.snackbar('Error', 'Failed to initialize payment: $e', backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  // ── Wallet ──────────────────────────────────────────────────────
  Future<void> fetchWallet() async {
    try {
      final res = await ApiService.instance.fetchWallet();
      walletBalance.value = (res['balance'] as num).toDouble();
      walletHistory.assignAll(List<Map<String, dynamic>>.from(res['history']));
    } catch (e) { print('Failed to fetch wallet: $e'); }
  }

  Future<bool> rechargeWallet(double amount) async {
    try {
      await ApiService.instance.rechargeWallet(amount);
      await fetchWallet();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> initiateWalletRecharge(double amount) async {
    if (amount <= 0) return;
    if (kIsWeb) {
      Get.snackbar('Not Supported', 'Online payment is not available on web.', backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }
    try {
      _isRechargingWallet = true;
      _rechargeAmount = amount;
      final orderData = await ApiService.createRazorpayOrder(amount);
      final options = {
        'key': 'rzp_live_RoLpvsh1Qs9Cfs', // Real Key ID
        'amount': orderData['amount'],
        'name': 'Rideal Laundry',
        'description': 'Wallet Recharge',
        'order_id': orderData['id'],
        'prefill': {
          'contact': '9876543210',
          'email': session.value?.email ?? '',
        }
      };
      _razorpay.open(options);
    } catch (e) {
      _isRechargingWallet = false;
      _rechargeAmount = 0.0;
      Get.snackbar('Error', 'Failed to initialize payment: $e', backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  // ── Addresses ───────────────────────────────────────────────────
  final Rx<Map<String, dynamic>?> selectedAddress = Rx<Map<String, dynamic>?>(null);

  Future<void> fetchAddresses() async {
    try {
      final res = await ApiService.instance.fetchAddresses();
      addresses.assignAll(res);
      if (addresses.isNotEmpty && selectedAddress.value == null) {
        selectedAddress.value = addresses.first;
      }
    } catch (e) {
      debugPrint('Failed to fetch addresses: $e');
    }
  }

  Future<bool> addAddress(String label, String address, double lat, double lng) async {
    try {
      final newAddr = await ApiService.instance.addAddress(label, address, lat, lng);
      addresses.insert(0, newAddr);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> deleteAddress(String id) async {
    try {
      await ApiService.instance.deleteAddress(id);
      addresses.removeWhere((a) => a['id'].toString() == id);
      Get.snackbar('Success', 'Address deleted', backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete address', backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  bool payFromWallet(double amount) {
    // For now, deduction logic relies on booking. We just check locally.
    if (walletBalance.value >= amount) {
      walletBalance.value -= amount;
      walletHistory.insert(0, {'type': 'debit', 'amount': amount, 'desc': 'Order Payment', 'date': 'Just now'});
      return true;
    }
    return false;
  }

  Future<void> fetchComplaints() async {
    try {
      final list = await ApiService.instance.fetchComplaints();
      complaints.assignAll(list);
    } catch (e) { print('Failed to fetch complaints: $e'); }
  }

  Future<void> addComplaint(String subject, String category, String desc) async {
    try {
      await ApiService.instance.addComplaint(subject, category, desc);
      await fetchComplaints();
      Get.snackbar('Success', 'Complaint registered', backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', 'Failed to submit complaint: $e', backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> submitRating(String orderId, int rating, String review) async {
    try {
      await ApiService.instance.submitOrderRating(orderId, rating, review);
      orderRatings[orderId] = rating;
      Get.snackbar('Success', 'Thank you for your feedback!', backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', 'Failed to submit rating: $e', backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  // ── Location ────────────────────────────────────────────────────
  Future<void> fetchCurrentLocation() async {
    isFetchingLocation.value = true;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied.';
      } 

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      currentLatitude.value = position.latitude;
      currentLongitude.value = position.longitude;

      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address = "${place.name}, ${place.subLocality}, ${place.locality}, ${place.postalCode}, ${place.country}";
        currentAddress.value = address;
      }
    } catch (e) {
      Get.snackbar('Location Error', e.toString(), backgroundColor: Colors.orange, colorText: Colors.white);
    } finally {
      isFetchingLocation.value = false;
    }
  }
}
