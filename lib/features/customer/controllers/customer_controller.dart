import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/enums.dart';
import '../../../core/models/laundry_order.dart';
import '../../../services/api_service.dart';
import '../../role_selection/screens/role_selection_screen.dart';

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
  final Rx<ServiceType> selectedService = ServiceType.laundry.obs;
  final Map<String, RxInt> cartItems = {
    'Shirt': 0.obs, 'Pant': 0.obs, 'Saree': 0.obs, 'Shorts': 0.obs,
    'T-Shirt': 0.obs, 'Kurta': 0.obs, 'Blazer': 0.obs, 'Suit': 0.obs
  };

  int get totalCartItems => cartItems.values.fold(0, (v, q) => v + q.value);

  // Address State
  final RxList<Map<String, dynamic>> addresses = <Map<String, dynamic>>[].obs;

  final RxString referralCode = ''.obs;

  @override
  void onInit() {
    super.onInit();
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

  Future<void> loadDashboardData() async {
    await fetchOrders();
    fetchWallet();
    fetchComplaints();
    fetchAddresses();
    fetchActiveSubscription();
  }

  Future<void> login(String email, String password) async {
    try {
      final s = await ApiService.loginCustomer(email, password);
      session.value = s;
      referralCode.value = s.referralCode ?? '';
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

  Future<bool> createOrder(String address) async {
    try {
      final itemsMap = <String, int>{};
      cartItems.forEach((key, val) {
        if (val.value > 0) itemsMap[key] = val.value;
      });

      await ApiService.createOrder(
        customerName: session.value?.name ?? 'Customer',
        customerEmail: session.value?.email ?? '',
        customerPhone: '9876543210', // Still mocked since phone isn't in session yet
        customerAddress: address,
        service: selectedService.value.label,
        totalItems: totalCartItems,
        items: itemsMap,
        vendorId: session.value?.vendorId,
      );
      
      // Clear cart
      for (var val in cartItems.values) { val.value = 0; }
      
      await fetchOrders();
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
    try {
      await ApiService.instance.purchaseCustomerPlan(planCode);
      await fetchActiveSubscription();
      Get.snackbar('Success', 'Subscribed to plan successfully!', backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', 'Failed to subscribe: $e', backgroundColor: Colors.red, colorText: Colors.white);
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

  // ── Addresses ───────────────────────────────────────────────────
  Future<void> fetchAddresses() async {
    try {
      final res = await ApiService.instance.fetchAddresses();
      addresses.assignAll(res);
    } catch (e) {
      print('Failed to fetch addresses: $e');
    }
  }

  Future<void> addAddress(String label, String address) async {
    try {
      final newAddr = await ApiService.instance.addAddress(label, address);
      addresses.insert(0, newAddr);
      Get.snackbar('Success', 'Address added', backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', 'Failed to add address', backgroundColor: Colors.red, colorText: Colors.white);
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
}
