import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/enums.dart';
import '../core/models/delivery_order.dart';

// ── Base URL ────────────────────────────────────────────────────
// Android emulator  → 10.0.2.2 maps to host machine localhost
// Flutter web        → use localhost when running in browser
// Physical device   → set your LAN IP at build time:
//   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000
String get _kDefaultBase {
  final env = const String.fromEnvironment('API_BASE_URL', defaultValue: '');
  if (env.isNotEmpty) return env;
  if (kIsWeb) return 'http://localhost:8000';
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://192.168.1.8:8000';
  return 'http://localhost:8000';
}

// ── Exceptions ──────────────────────────────────────────────────
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  ApiException(this.message, {this.statusCode, this.code});

  @override
  String toString() => 'ApiException: $message';
}

// ── Models ──────────────────────────────────────────────────────
class CustomerSession {
  final String id;
  final String name;
  final String email;
  final String token;
  final String? vendorId;
  final String? referralCode;

  CustomerSession({
    required this.id,
    required this.name,
    required this.email,
    required this.token,
    this.vendorId,
    this.referralCode,
  });

  factory CustomerSession.fromJson(Map<String, dynamic> data) {
    final c = data['customer'] as Map<String, dynamic>;
    return CustomerSession(
      id: c['id'] as String,
      name: c['name'] as String,
      email: c['email'] as String,
      token: data['token'] as String,
      vendorId: c['vendorId'] as String?,
      referralCode: c['referralCode'] as String?,
    );
  }
}

class VendorInfo {
  final String id;
  final String shopName;
  final String? phone;
  final String? address;
  final String? logoUrl;

  VendorInfo({
    required this.id,
    required this.shopName,
    this.phone,
    this.address,
    this.logoUrl,
  });

  factory VendorInfo.fromJson(Map<String, dynamic> j) => VendorInfo(
        id: j['id'] as String,
        shopName: j['shopName'] as String,
        phone: j['phone'] as String?,
        address: j['address'] as String?,
        logoUrl: j['logoUrl'] as String?,
      );
}

class OrderCreated {
  final String id;
  final String token;
  final String pickupOtp;
  final String deliveryOtp;
  final String trackingStatus;

  OrderCreated({
    required this.id,
    required this.token,
    required this.pickupOtp,
    required this.deliveryOtp,
    required this.trackingStatus,
  });

  factory OrderCreated.fromJson(Map<String, dynamic> j) => OrderCreated(
        id: j['id'] as String,
        token: j['token'] as String,
        pickupOtp: j['pickupOtp'] as String? ?? '----',
        deliveryOtp: j['deliveryOtp'] as String? ?? '----',
        trackingStatus: j['trackingStatus'] as String? ?? 'order_placed',
      );
}

class TrackingStep {
  final String status;
  final String label;
  final bool completed;
  final bool current;

  TrackingStep({
    required this.status,
    required this.label,
    required this.completed,
    required this.current,
  });

  factory TrackingStep.fromJson(Map<String, dynamic> j) => TrackingStep(
        status: j['status'] as String,
        label: j['label'] as String,
        completed: j['completed'] as bool? ?? false,
        current: j['current'] as bool? ?? false,
      );
}

class OrderTimeline {
  final String orderId;
  final String currentStatus;
  final String currentLabel;
  final String? estimatedDeliveryAt;
  final Map<String, dynamic>? deliveryPartner;
  final List<TrackingStep> steps;
  final List<Map<String, dynamic>> events;

  OrderTimeline({
    required this.orderId,
    required this.currentStatus,
    required this.currentLabel,
    this.estimatedDeliveryAt,
    this.deliveryPartner,
    required this.steps,
    required this.events,
  });

  factory OrderTimeline.fromJson(Map<String, dynamic> j) {
    final stepsRaw = j['steps'] as List<dynamic>? ?? [];
    final eventsRaw = j['timeline'] as List<dynamic>? ?? [];
    return OrderTimeline(
      orderId: j['orderId'] as String,
      currentStatus: j['currentStatus'] as String,
      currentLabel: j['currentLabel'] as String,
      estimatedDeliveryAt: j['estimatedDeliveryAt'] as String?,
      deliveryPartner: j['deliveryPartner'] as Map<String, dynamic>?,
      steps: stepsRaw.map((e) => TrackingStep.fromJson(e as Map<String, dynamic>)).toList(),
      events: eventsRaw.map((e) => e as Map<String, dynamic>).toList(),
    );
  }
}

// ── VendorAuth (kept for existing main.dart compat) ─────────────
class VendorAuth {
  final String token;
  final String vendorId;
  final String shopName;
  final String phone;
  final String address;

  VendorAuth({
    required this.token,
    required this.vendorId,
    required this.shopName,
    required this.phone,
    required this.address,
  });

  factory VendorAuth.fromJson(Map<String, dynamic> json) => VendorAuth(
        token: json['token'] as String,
        vendorId: json['vendor']['id'] as String,
        shopName: json['vendor']['shopName'] as String,
        phone: (json['vendor']['phone'] as String?) ?? '',
        address: (json['vendor']['address'] as String?) ?? '',
      );
}

class DeliveryAuth {
  final String token;
  final String deliveryId;
  final String name;
  final String email;
  final String phone;
  final String kycStatus;

  DeliveryAuth({
    required this.token,
    required this.deliveryId,
    required this.name,
    required this.email,
    required this.phone,
    required this.kycStatus,
  });

  factory DeliveryAuth.fromJson(Map<String, dynamic> json) => DeliveryAuth(
        token: json['token'] as String,
        deliveryId: json['deliveryBoy']['id'] as String,
        name: json['deliveryBoy']['name'] as String,
        email: (json['deliveryBoy']['email'] as String?) ?? '',
        phone: (json['deliveryBoy']['phone'] as String?) ?? '',
        kycStatus: (json['deliveryBoy']['kycStatus'] as String?) ?? 'pending',
      );
}

class OrderResponse {
  final String id;
  final String token;

  OrderResponse({required this.id, required this.token});

  factory OrderResponse.fromJson(Map<String, dynamic> json) =>
      OrderResponse(id: json['id'] as String, token: json['token'] as String);
}

// ── Customer Session Store ──────────────────────────────────────
class _SessionStore {
  static const _tokenKey = 'rideal_customer_token';
  static const _emailKey = 'rideal_customer_email';
  static const _nameKey  = 'rideal_customer_name';
  static const _idKey    = 'rideal_customer_id';
  static const _vendorKey = 'rideal_vendor_id';
  static const _referralKey = 'rideal_referral_code';

  String? token;
  String? email;
  String? name;
  String? id;
  String? vendorId;
  String? referralCode;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    token    = p.getString(_tokenKey);
    email    = p.getString(_emailKey);
    name     = p.getString(_nameKey);
    id       = p.getString(_idKey);
    vendorId = p.getString(_vendorKey);
    referralCode = p.getString(_referralKey);
  }

  Future<void> save(CustomerSession s) async {
    token    = s.token;
    email    = s.email;
    name     = s.name;
    id       = s.id;
    vendorId = s.vendorId;
    referralCode = s.referralCode;
    final p = await SharedPreferences.getInstance();
    await p.setString(_tokenKey, s.token);
    await p.setString(_emailKey, s.email);
    await p.setString(_nameKey,  s.name);
    await p.setString(_idKey,    s.id);
    if (s.vendorId != null) await p.setString(_vendorKey, s.vendorId!);
    if (s.referralCode != null) await p.setString(_referralKey, s.referralCode!);
  }

  Future<void> clear() async {
    token = email = name = id = vendorId = referralCode = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_tokenKey);
    await p.remove(_emailKey);
    await p.remove(_nameKey);
    await p.remove(_idKey);
    await p.remove(_vendorKey);
    await p.remove(_referralKey);
  }

  bool get isLoggedIn => token != null;
}

// ── Vendor Session Store ────────────────────────────────────────
class _VendorSessionStore {
  static const _tokenKey = 'rideal_vendor_token';
  static const _idKey = 'rideal_vendor_auth_id';
  static const _shopNameKey = 'rideal_vendor_shop_name';
  static const _phoneKey = 'rideal_vendor_phone';
  static const _addressKey = 'rideal_vendor_address';

  String? token;
  String? vendorId;
  String? shopName;
  String? phone;
  String? address;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString(_tokenKey);
    vendorId = p.getString(_idKey);
    shopName = p.getString(_shopNameKey);
    phone = p.getString(_phoneKey);
    address = p.getString(_addressKey);
  }

  Future<void> save(VendorAuth v) async {
    token = v.token;
    vendorId = v.vendorId;
    shopName = v.shopName;
    phone = v.phone;
    address = v.address;
    
    final p = await SharedPreferences.getInstance();
    await p.setString(_tokenKey, v.token);
    await p.setString(_idKey, v.vendorId);
    await p.setString(_shopNameKey, v.shopName);
    await p.setString(_phoneKey, v.phone);
    await p.setString(_addressKey, v.address);
  }

  Future<void> clear() async {
    token = vendorId = shopName = phone = address = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_tokenKey);
    await p.remove(_idKey);
    await p.remove(_shopNameKey);
    await p.remove(_phoneKey);
    await p.remove(_addressKey);
  }

  bool get isLoggedIn => token != null;
}

// ── Delivery Session Store ───────────────────────────────────────
class _DeliverySessionStore {
  static const _tokenKey = 'rideal_delivery_token';
  static const _idKey = 'rideal_delivery_id';
  static const _nameKey = 'rideal_delivery_name';
  static const _kycKey = 'rideal_delivery_kyc';

  String? token;
  String? deliveryId;
  String? name;
  String? kycStatus;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString(_tokenKey);
    deliveryId = p.getString(_idKey);
    name = p.getString(_nameKey);
    kycStatus = p.getString(_kycKey) ?? 'pending';
  }

  Future<void> save(DeliveryAuth d) async {
    token = d.token;
    deliveryId = d.deliveryId;
    name = d.name;
    kycStatus = d.kycStatus;
    
    final p = await SharedPreferences.getInstance();
    await p.setString(_tokenKey, d.token);
    await p.setString(_idKey, d.deliveryId);
    await p.setString(_nameKey, d.name);
    await p.setString(_kycKey, d.kycStatus);
  }

  Future<void> clear() async {
    token = deliveryId = name = kycStatus = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_tokenKey);
    await p.remove(_idKey);
    await p.remove(_nameKey);
    await p.remove(_kycKey);
  }

  bool get isLoggedIn => token != null;
}

// ── ApiService ──────────────────────────────────────────────────
class ApiService {
  static String get baseUrl => _kDefaultBase;

  final _session = _SessionStore();
  final _vendorSession = _VendorSessionStore();
  final _deliverySession = _DeliverySessionStore();

  ApiService._();
  static final ApiService instance = ApiService._();

  bool get isLoggedIn => _session.isLoggedIn;
  bool get isVendorLoggedIn => _vendorSession.isLoggedIn;
  bool get isDeliveryLoggedIn => _deliverySession.isLoggedIn;

  CustomerSession? get currentCustomer => isLoggedIn
      ? CustomerSession(token: _session.token!, name: _session.name!, email: _session.email!, id: _session.id!, vendorId: _session.vendorId, referralCode: _session.referralCode)
      : null;

  DeliveryAuth? get currentDeliveryAuth => isDeliveryLoggedIn
      ? DeliveryAuth(token: _deliverySession.token!, deliveryId: _deliverySession.deliveryId!, name: _deliverySession.name!, email: '', phone: '', kycStatus: _deliverySession.kycStatus!)
      : null;

  set currentDeliveryAuth(DeliveryAuth? d) {
    if (d == null) {
      _deliverySession.clear();
    } else {
      _deliverySession.save(d);
    }
  }

  String? get currentEmail  => _session.email;
  String? get currentName   => _session.name;
  String? get currentId     => _session.id;
  String? get currentToken  => _session.token;
  String? get preferredVendorId => _session.vendorId;
  String? get currentReferralCode => _session.referralCode;

  VendorAuth? get currentVendorAuth => _vendorSession.isLoggedIn
      ? VendorAuth(
          token: _vendorSession.token!,
          vendorId: _vendorSession.vendorId!,
          shopName: _vendorSession.shopName!,
          phone: _vendorSession.phone ?? '',
          address: _vendorSession.address ?? '',
        )
      : null;

  set currentVendorAuth(VendorAuth? v) {
    if (v == null) {
      _vendorSession.clear();
    } else {
      _vendorSession.save(v);
    }
  }

  Future<void> loadSession() async {
    await _session.load();
    await _vendorSession.load();
    await _deliverySession.load();
  }

  Map<String, String> _getHeaders(String path) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (path.startsWith('/api/customer') && _session.token != null) {
      headers['Authorization'] = 'Bearer ${_session.token}';
    } else if (path.startsWith('/api/vendor') && _vendorSession.token != null) {
      headers['Authorization'] = 'Bearer ${_vendorSession.token}';
    } else if (path.startsWith('/api/driver') && _deliverySession.token != null) {
      headers['Authorization'] = 'Bearer ${_deliverySession.token}';
    } else if (path.startsWith('/api/orders') && _vendorSession.token != null) {
      headers['Authorization'] = 'Bearer ${_vendorSession.token}';
    } else {
      if (_session.token != null) {
        headers['Authorization'] = 'Bearer ${_session.token}';
      } else if (_vendorSession.token != null) {
        headers['Authorization'] = 'Bearer ${_vendorSession.token}';
      } else if (_deliverySession.token != null) {
        headers['Authorization'] = 'Bearer ${_deliverySession.token}';
      }
    }
    return headers;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) uri = uri.replace(queryParameters: query);

    http.Response res;
    final reqHeaders = _getHeaders(path);
    switch (method) {
      case 'GET':
        res = await http.get(uri, headers: reqHeaders).timeout(const Duration(seconds: 15));
        break;
      case 'POST':
        res = await http.post(uri, headers: reqHeaders, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 15));
        break;
      case 'PATCH':
        res = await http.patch(uri, headers: reqHeaders, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 15));
        break;
      case 'DELETE':
        res = await http.delete(uri, headers: reqHeaders).timeout(const Duration(seconds: 15));
        break;
      default:
        throw ApiException('Unsupported method $method');
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        res.statusCode >= 500 ? 'Server error. Is backend running at $baseUrl?' : 'Invalid server response',
        statusCode: res.statusCode,
      );
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        decoded['message'] as String? ?? 'Request failed',
        statusCode: res.statusCode,
        code: decoded['code'] as String?,
      );
    }
    return decoded;
  }

  // ── Customer Items ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchItems() async {
    final res = await _request('GET', '/api/customer/items');
    final data = res['data'] as List<dynamic>? ?? [];
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> fetchServices() async {
    final res = await _request('GET', '/api/customer/services');
    final data = res['data'] as List<dynamic>? ?? [];
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> fetchPlatformSettings() async {
    final res = await _request('GET', '/api/customer/settings');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  // ── Customer Auth ──────────────────────────────────────────────────────

  Future<CustomerSession> _signupCustomer(String name, String email, String password, {String? vendorId, String? referredBy}) async {
    final res = await _request('POST', '/api/customer/signup', body: {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      if (vendorId != null) 'vendorId': vendorId,
      if (referredBy != null && referredBy.isNotEmpty) 'referredBy': referredBy,
    });
    final s = CustomerSession.fromJson(res['data'] as Map<String, dynamic>);
    await _session.save(s);
    return s;
  }

  Future<CustomerSession> _loginCustomer(String email, String password) async {
    final res = await _request('POST', '/api/customer/login', body: {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    final s = CustomerSession.fromJson(res['data'] as Map<String, dynamic>);
    await _session.save(s);
    return s;
  }

  Future<void> logout() => _session.clear();

  static Future<void> updateDriverLocation(double lat, double lng) async {
    final res = await http.put(
      Uri.parse('$_kDefaultBase/api/driver/location'),
      headers: instance._getHeaders('/api/driver/location'),
      body: jsonEncode({'latitude': lat, 'longitude': lng}),
    );
    if (res.statusCode != 200) throw Exception(res.body);
  }

  static Future<void> updateDriverStatus(String status) async {
    final res = await http.post(
      Uri.parse('$_kDefaultBase/api/driver/status'),
      headers: instance._getHeaders('/api/driver/status'),
      body: jsonEncode({'status': status}),
    );
    if (res.statusCode != 200) throw Exception(res.body);
  }

  static Future<void> fetchDriverProfile() async {
    final res = await instance._request('GET', '/api/driver/profile');
    final driver = res['data'] as Map<String, dynamic>;
    if (instance.currentDeliveryAuth != null) {
      final current = instance.currentDeliveryAuth!;
      final updated = DeliveryAuth(
        token: current.token,
        deliveryId: current.deliveryId,
        name: driver['name'] as String? ?? current.name,
        email: driver['email'] as String? ?? current.email,
        phone: driver['phone'] as String? ?? current.phone,
        kycStatus: driver['kyc_status'] as String? ?? current.kycStatus,
      );
      await instance._deliverySession.save(updated);
    }
  }

  static Future<Map<String, dynamic>> fetchDriverDashboardStats() async {
    final driverId = instance.currentDeliveryAuth?.deliveryId;
    if (driverId == null) return {};
    try {
      final res = await instance._request('GET', '/api/driver/profile/$driverId');
      final data = res['data'] as Map<String, dynamic>? ?? {};
      if (data['wallet_balance'] != null) {
        data['walletBalance'] = data['wallet_balance'];
      }
      return data;
    } catch (_) {
      return {};
    }
  }

  static Future<void> requestDriverPayout(double amount) async {
    final res = await http.post(
      Uri.parse('$_kDefaultBase/api/driver/payout/request'),
      headers: instance._getHeaders('/api/driver/payout/request'),
      body: jsonEncode({'amount': amount}),
    );
    if (res.statusCode != 200) {
      final b = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(b['message'] as String? ?? 'Payout request failed', statusCode: res.statusCode);
    }
  }

  // ── Vendor Endpoints ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> fetchVendorProfile() async {
    final res = await instance._request('GET', '/api/vendor/me');
    final data = res['data'] as Map<String, dynamic>? ?? {};
    if (data['wallet_balance'] != null) {
      data['walletBalance'] = data['wallet_balance'];
    }
    return data;
  }

  static Future<void> requestVendorPayout(double amount) async {
    final res = await http.post(
      Uri.parse('$_kDefaultBase/api/vendor/payout/request'),
      headers: instance._getHeaders('/api/vendor/payout/request'),
      body: jsonEncode({'amount': amount}),
    );
    if (res.statusCode != 200) {
      final b = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(b['message'] as String? ?? 'Payout request failed', statusCode: res.statusCode);
    }
  }

  Future<List<VendorInfo>> fetchVendors() async {
    final res = await _request('GET', '/api/customer/vendors');
    final list = res['data'] as List<dynamic>;
    return list.map((e) => VendorInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Orders ────────────────────────────────────────────────────

  Future<OrderCreated> _createOrder({
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String service,
    required int totalItems,
    required Map<String, int> items,
    String? vendorId,
    String? customerAddress,
    double? latitude,
    double? longitude,
    required double totalAmount,
    required String paymentMethod,
    required String paymentStatus,
    String? paymentId,
  }) async {
    final res = await _request('POST', '/api/customer/orders', body: {
      'customerName':  customerName,
      'customerEmail': customerEmail.trim().toLowerCase(),
      'customerPhone': customerPhone,
      'service':       service,
      'totalItems':    totalItems,
      'items':         items,
      if (vendorId != null) 'vendorId': vendorId,
      if (customerAddress != null) 'customerAddress': customerAddress,
      if (latitude  != null) 'customerLatitude':  latitude,
      if (longitude != null) 'customerLongitude': longitude,
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      if (paymentId != null) 'paymentId': paymentId,
    });
    return OrderCreated.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> fetchOrders() async {
    final query = _session.email != null ? {'email': _session.email!} : <String, String>{};
    final res   = await _request('GET', '/api/customer/orders', query: query);
    return (res['data'] as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> fetchOrderDetail(String orderId) async {
    final query = _session.email != null ? {'email': _session.email!} : <String, String>{};
    final res   = await _request('GET', '/api/customer/orders/$orderId', query: query);
    return res['data'] as Map<String, dynamic>;
  }

  // ── Live tracking ─────────────────────────────────────────────
  Future<OrderTimeline> getOrderTimeline(String orderId) async {
    return fetchOrderTimeline(orderId);
  }

  Future<OrderTimeline> fetchOrderTimeline(String orderId) async {
    final query = _session.email != null ? {'email': _session.email!} : <String, String>{};
    final res   = await _request('GET', '/api/tracking/orders/$orderId/timeline', query: query);
    return OrderTimeline.fromJson(res['data'] as Map<String, dynamic>);
  }

  // ── Wallet ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> fetchWallet() async {
    final res = await _request('GET', '/api/customer/wallet');
    return res['data'] as Map<String, dynamic>;
  }

  Future<void> rechargeWallet(double amount) async {
    await _request('POST', '/api/customer/wallet/recharge', body: {'amount': amount});
  }

  // ── Complaints ──────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchComplaints() async {
    final res = await _request('GET', '/api/customer/complaints');
    return (res['data'] as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> addComplaint(String subject, String category, String description) async {
    final res = await _request('POST', '/api/customer/complaints', body: {
      'subject': subject,
      'category': category,
      'description': description,
    });
    return res['data'] as Map<String, dynamic>;
  }

  // ── Ratings ─────────────────────────────────────────────────────
  Future<void> submitOrderRating(String orderId, int rating, String review) async {
    await _request('POST', '/api/customer/orders/$orderId/rating', body: {
      'rating': rating,
      'review': review,
    });
  }

  // ── Addresses ───────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchAddresses() async {
    final res = await _request('GET', '/api/customer/addresses');
    return (res['data'] as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> addAddress(String label, String address, double lat, double lng) async {
    final res = await _request('POST', '/api/customer/addresses', body: {
      'label': label,
      'address': address,
      'latitude': lat,
      'longitude': lng,
    });
    return res['data'] as Map<String, dynamic>;
  }

  Future<void> deleteAddress(String id) async {
    await _request('DELETE', '/api/customer/addresses/$id');
  }

  // ── Plans & Subscriptions ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchCustomerPlans() async {
    final res = await _request('GET', '/api/customer/plans');
    return (res['data'] as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>?> fetchActiveSubscription() async {
    final res = await _request('GET', '/api/customer/subscription');
    return res['data'] as Map<String, dynamic>?;
  }

  Future<void> purchaseCustomerPlan(String planCode) async {
    await _request('POST', '/api/customer/subscription/subscribe', body: {
      'planCode': planCode,
    });
  }

  // ── Vendor login (kept for role-select screen compat) ─────────

  static Future<VendorAuth> loginVendor(String email, String password) async {
    final uri = Uri.parse('$baseUrl/api/auth/login');
    final res = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password}));
    if (res.statusCode != 200) {
      final b = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(b['message'] as String? ?? 'Login failed', statusCode: res.statusCode);
    }
    return VendorAuth.fromJson((jsonDecode(res.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  static Future<VendorAuth> signupVendor(String email, String password, String shopName, String phone, String address, {double? latitude, double? longitude}) async {
    final res = await instance._request('POST', '/api/auth/vendor/signup', body: {
      'email': email,
      'password': password,
      'shopName': shopName,
      'phone': phone,
      'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return VendorAuth.fromJson(res['data'] as Map<String, dynamic>);
  }

  static Future<DeliveryAuth> loginDeliveryBoy(String login, String password) async {
    final uri = Uri.parse('$baseUrl/api/auth/delivery/login');
    final res = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'login': login.trim(), 'password': password}));
    if (res.statusCode != 200) {
      final b = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(b['message'] as String? ?? 'Login failed', statusCode: res.statusCode);
    }
    final auth = DeliveryAuth.fromJson(
        (jsonDecode(res.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    await instance._deliverySession.save(auth);
    return auth;
  }

  static Future<DeliveryAuth> signupDeliveryBoy(
      String password, String name, String email, String phone, [String? vendorId]) async {
    final uri = Uri.parse('$baseUrl/api/auth/delivery/signup');
    final res = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'password': password, 'name': name, 'email': email, 'phone': phone, if (vendorId != null) 'vendorId': vendorId}));
    if (res.statusCode != 200 && res.statusCode != 201) {
      final b = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(b['message'] as String? ?? 'Signup failed', statusCode: res.statusCode);
    }
    final auth = DeliveryAuth.fromJson(
        (jsonDecode(res.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    await instance._deliverySession.save(auth);
    return auth;
  }

  static Future<void> uploadDriverKyc({
    required String aadharFrontBase64,
    required String aadharBackBase64,
    required String selfieBase64,
    required String aadharNumber,
  }) async {
    final uri = Uri.parse('$_kDefaultBase/api/driver/kyc-upload');
    final res = await http.post(uri,
        headers: {
          'Content-Type': 'application/json',
          if (instance._deliverySession.token != null) 'Authorization': 'Bearer ${instance._deliverySession.token}',
        },
        body: jsonEncode({
          'aadhar_front': aadharFrontBase64,
          'aadhar_back': aadharBackBase64,
          'selfie': selfieBase64,
          'aadhar_number': aadharNumber,
        }));
    if (res.statusCode != 200) {
      final b = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(b['message'] as String? ?? 'Upload failed', statusCode: res.statusCode);
    }

    if (instance.currentDeliveryAuth != null) {
      final current = instance.currentDeliveryAuth!;
      final updated = DeliveryAuth(
        token: current.token,
        deliveryId: current.deliveryId,
        name: current.name,
        email: current.email,
        phone: current.phone,
        kycStatus: 'submitted',
      );
      await instance._deliverySession.save(updated);
    }
  }

  // ── Legacy static helpers (keeps existing main.dart calls working) ──

  static Future<CustomerSession> signupCustomer(String name, String email, String password, {String? vendorId, String? referredBy}) =>
      instance._signupCustomer(name, email, password, vendorId: vendorId, referredBy: referredBy);

  static Future<CustomerSession> loginCustomer(String email, String password) =>
      instance._loginCustomer(email, password);

  static Future<OrderResponse> createOrder({
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String service,
    required int totalItems,
    required Map<String, int> items,
    String? vendorId,
    String? customerAddress,
    double? latitude,
    double? longitude,
    required double totalAmount,
    required String paymentMethod,
    required String paymentStatus,
    String? paymentId,
  }) async {
    final o = await instance._createOrder(
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      latitude: latitude,
      longitude: longitude,
      service: service,
      totalItems: totalItems,
      items: items,
      vendorId: vendorId,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      paymentId: paymentId,
    );
    return OrderResponse(id: o.id, token: o.token);
  }

  static Future<void> cancelOrder(String orderId) async {
    final res = await http.post(
      Uri.parse('$_kDefaultBase/api/customer/orders/$orderId/cancel'),
      headers: instance._getHeaders('/api/customer/orders/$orderId/cancel'),
    );
    if (res.statusCode != 200) {
      final b = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(b['message'] as String? ?? 'Cancel failed', statusCode: res.statusCode);
    }
  }

  static Future<void> rateOrder(String orderId, int rating, String review) async {
    final res = await http.post(
      Uri.parse('$_kDefaultBase/api/customer/orders/$orderId/rate'),
      headers: instance._getHeaders('/api/customer/orders/$orderId/rate'),
      body: jsonEncode({'rating': rating, 'review': review}),
    );
    if (res.statusCode != 200) {
      final b = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(b['message'] as String? ?? 'Rating failed', statusCode: res.statusCode);
    }
  }

  static Future<Map<String, dynamic>> createRazorpayOrder(double amount) async {
    final res = await instance._request('POST', '/api/payment/razorpay/create-order', body: {
      'amount': amount,
      'currency': 'INR',
    });
    return res['data'] as Map<String, dynamic>;
  }

  static Future<bool> verifyRazorpayPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    try {
      final res = await instance._request('POST', '/api/payment/razorpay/verify', body: {
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_signature': razorpaySignature,
      });
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  static OrderStatus mapBackendStatus(String backendStatus) {
    switch (backendStatus) {
      case 'received': return OrderStatus.pickedUp;
      case 'accepted': 
      case 'washing':
      case 'drying': return OrderStatus.inLaundry;
      case 'readyForDelivery': return OrderStatus.readyForDelivery;
      case 'handedToDelivery': return OrderStatus.outForDelivery;
      case 'delivered': return OrderStatus.delivered;
      default: return OrderStatus.pending;
    }
  }

  OrderStatus _determineDriverStatus(Map<String, dynamic> map) {
    String backendStatus = map['status'] as String;
    if (backendStatus == 'received') {
      if (map['pickupVerifiedAt'] == null) {
        return OrderStatus.pending;
      }
      return OrderStatus.pickedUp;
    }
    return mapBackendStatus(backendStatus);
  }

  List<DeliveryOrder> _parseDeliveryOrderList(List<dynamic> list) {
    return list.map((e) {
      final map = e as Map<String, dynamic>;
      return DeliveryOrder(
        id: map['id'] as String,
        customerName: map['customerName'] as String,
        customerAddress: (map['customerAddress'] as String?) ?? '',
        customerPhone: (map['customerPhone'] as String?) ?? '',
        token: map['token'] as String,
        pickupOtp: (map['pickupOtp'] as String?) ?? '1234',
        deliveryOtp: (map['deliveryOtp'] as String?) ?? '1234',
        vendorDropoffOtp: (map['vendorDropoffOtp'] as String?) ?? '1234',
        vendorDispatchOtp: (map['vendorDispatchOtp'] as String?) ?? '1234',
        totalItems: (map['totalItems'] as num).toInt(),
        service: map['service'] as String,
        customerLatitude: map['customerLatitude'] != null ? (map['customerLatitude'] as num).toDouble() : null,
        customerLongitude: map['customerLongitude'] != null ? (map['customerLongitude'] as num).toDouble() : null,
        vendorLatitude: map['vendorLatitude'] != null ? (map['vendorLatitude'] as num).toDouble() : (map['vendor_lat'] != null ? (map['vendor_lat'] as num).toDouble() : null),
        vendorLongitude: map['vendorLongitude'] != null ? (map['vendorLongitude'] as num).toDouble() : (map['vendor_lon'] != null ? (map['vendor_lon'] as num).toDouble() : null),
        status: _determineDriverStatus(map),
      );
    }).toList();
  }

  Future<List<DeliveryOrder>> fetchVendorOrders() async {
    final res = await _request('GET', '/api/orders');
    return _parseDeliveryOrderList(res['data'] as List<dynamic>);
  }

  Future<void> advanceVendorOrderStatusTo(String id, OrderStatus target) async {
    final res = await _request('GET', '/api/orders/$id');
    final currentStatus = res['data']['status'] as String;
    
    if (target == OrderStatus.inLaundry) {
      if (currentStatus == 'received') {
        await _request('PATCH', '/api/orders/$id/status'); // received -> accepted
        await _request('PATCH', '/api/orders/$id/status'); // accepted -> washing
      } else if (currentStatus == 'accepted') {
        await _request('PATCH', '/api/orders/$id/status'); // accepted -> washing
      }
    } else if (target == OrderStatus.readyForDelivery) {
      if (currentStatus == 'accepted') {
        await _request('PATCH', '/api/orders/$id/status'); // accepted -> washing
        await _request('PATCH', '/api/orders/$id/status'); // washing -> drying
        await _request('PATCH', '/api/orders/$id/status'); // drying -> readyForDelivery
      } else if (currentStatus == 'washing') {
        await _request('PATCH', '/api/orders/$id/status'); // washing -> drying
        await _request('PATCH', '/api/orders/$id/status'); // drying -> readyForDelivery
      } else if (currentStatus == 'drying') {
        await _request('PATCH', '/api/orders/$id/status'); // drying -> readyForDelivery
      }
    }
  }

  // --- Vendor Broadcast ---
  static Future<List<Map<String, dynamic>>> fetchVendorBroadcastOrders() async {
    try {
      final res = await instance._request('GET', '/api/vendor/broadcast-orders');
      final data = res['data'] as List;
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Failed to fetch broadcast orders: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> acceptVendorBroadcastOrder(String orderId) async {
    try {
      final res = await instance._request('POST', '/api/vendor/accept-order', body: {
        'orderId': orderId,
      });
      return {'success': true, 'data': res};
    } catch (e) {
      String message = 'Accept failed';
      if (e is ApiException) {
      }
      return {'success': false, 'message': message};
    }
  }

  // ── Driver ──────────────────────────────────────────────────────
  Future<List<DeliveryOrder>> fetchMyRides() async {
    final res = await _request('GET', '/api/driver/my-rides');
    return _parseDeliveryOrderList(res['data'] as List<dynamic>);
  }

  Future<List<DeliveryOrder>> fetchAvailablePickups() async {
    final res = await _request('GET', '/api/driver/pickups');
    return _parseDeliveryOrderList(res['data'] as List<dynamic>);
  }

  Future<List<DeliveryOrder>> fetchAvailableDeliveries() async {
    final res = await _request('GET', '/api/driver/rides');
    return _parseDeliveryOrderList(res['data'] as List<dynamic>);
  }

  Future<void> acceptPickup(String rideId) async {
    await _request('POST', '/api/driver/accept-pickup', body: {'rideId': rideId});
  }

  Future<void> acceptRide(String rideId) async {
    await _request('POST', '/api/driver/accept-ride', body: {'rideId': rideId});
  }

  Future<void> verifyPickupOtp(String rideId, String otp) async {
    await _request('POST', '/api/driver/verify-pickup-otp', body: {'rideId': rideId, 'otp': otp});
  }

  Future<void> verifyVendorDropoffOtp(String rideId, String otp) async {
    await _request('POST', '/api/driver/verify-vendor-dropoff-otp', body: {'rideId': rideId, 'otp': otp});
  }

  Future<void> verifyVendorDispatchOtp(String rideId, String otp) async {
    await _request('POST', '/api/driver/verify-vendor-dispatch-otp', body: {'rideId': rideId, 'otp': otp});
  }

  Future<void> completeRide(String rideId, String otp) async {
    await _request('POST', '/api/driver/complete-ride', body: {'rideId': rideId, 'otp': otp});
  }

  // ── Push Notifications ──────────────────────────────────────────
  Future<void> registerDeviceToken(String userType, String userId, String token) async {
    try {
      await _request('POST', '/api/notifications/device-token', body: {
        'userType': userType,
        'userId': userId,
        'token': token,
        'platform': defaultTargetPlatform.name,
      });
    } catch (e) {
      print('Failed to register device token: $e');
    }
  }
}
