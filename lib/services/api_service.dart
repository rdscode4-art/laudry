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
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://192.168.1.16:8000';
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

  DeliveryAuth({
    required this.token,
    required this.deliveryId,
    required this.name,
    required this.email,
    required this.phone,
  });

  factory DeliveryAuth.fromJson(Map<String, dynamic> json) => DeliveryAuth(
        token: json['token'] as String,
        deliveryId: json['deliveryBoy']['id'] as String,
        name: json['deliveryBoy']['name'] as String,
        email: (json['deliveryBoy']['email'] as String?) ?? '',
        phone: (json['deliveryBoy']['phone'] as String?) ?? '',
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

// ── ApiService ──────────────────────────────────────────────────
class ApiService {
  static String get baseUrl => _kDefaultBase;

  final _session = _SessionStore();
  final _vendorSession = _VendorSessionStore();

  ApiService._();
  static final ApiService instance = ApiService._();

  bool get isLoggedIn => _session.isLoggedIn;
  bool get isVendorLoggedIn => _vendorSession.isLoggedIn;

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
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_session.token != null) 'Authorization': 'Bearer ${_session.token}',
        if (_vendorSession.token != null) 'Authorization': 'Bearer ${_vendorSession.token}',
      };

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) uri = uri.replace(queryParameters: query);

    http.Response res;
    switch (method) {
      case 'GET':
        res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
        break;
      case 'POST':
        res = await http.post(uri, headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 15));
        break;
      case 'PATCH':
        res = await http.patch(uri, headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 15));
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

  // ── Auth ──────────────────────────────────────────────────────

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

  // ── Vendor list ───────────────────────────────────────────────

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
  }) async {
    final res = await _request('POST', '/api/customer/orders', body: {
      'customerName':  customerName,
      'customerEmail': customerEmail.trim().toLowerCase(),
      'customerPhone': customerPhone,
      'service':       service,
      'totalItems':    totalItems,
      'items':         items,
      'vendorId':      vendorId ?? _session.vendorId ?? 'vendor01',
      if (customerAddress != null) 'customerAddress': customerAddress,
      if (latitude  != null) 'customerLatitude':  latitude,
      if (longitude != null) 'customerLongitude': longitude,
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

  Future<Map<String, dynamic>> addAddress(String label, String address) async {
    final res = await _request('POST', '/api/customer/addresses', body: {
      'label': label,
      'address': address,
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

  static Future<VendorAuth> loginVendor(String vendorId, String password) async {
    final uri = Uri.parse('$baseUrl/api/auth/login');
    final res = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'vendorId': vendorId.trim(), 'password': password}));
    if (res.statusCode != 200) {
      final b = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(b['message'] as String? ?? 'Login failed', statusCode: res.statusCode);
    }
    return VendorAuth.fromJson((jsonDecode(res.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  static Future<VendorAuth> signupVendor(String password, String shopName, String phone, String address) async {
    final uri = Uri.parse('$baseUrl/api/auth/vendor/signup');
    final res = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'password': password, 'shopName': shopName, 'phone': phone, 'address': address}));
    if (res.statusCode != 200) {
      final b = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(b['message'] as String? ?? 'Signup failed', statusCode: res.statusCode);
    }
    return VendorAuth.fromJson((jsonDecode(res.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>);
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
    return DeliveryAuth.fromJson(
        (jsonDecode(res.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  static Future<DeliveryAuth> signupDeliveryBoy(
      String password, String name, String email, String phone, [String vendorId = 'vendor01']) async {
    final uri = Uri.parse('$baseUrl/api/auth/delivery/signup');
    final res = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'password': password, 'name': name, 'email': email, 'phone': phone, 'vendorId': vendorId}));
    if (res.statusCode != 200 && res.statusCode != 201) {
      final b = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(b['message'] as String? ?? 'Signup failed', statusCode: res.statusCode);
    }
    return DeliveryAuth.fromJson(
        (jsonDecode(res.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>);
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
    );
    return OrderResponse(id: o.id, token: o.token);
  }

  static OrderStatus mapBackendStatus(String backendStatus) {
    switch (backendStatus) {
      case 'received': return OrderStatus.pickedUp;
      case 'washing':
      case 'drying': return OrderStatus.inLaundry;
      case 'readyForDelivery': return OrderStatus.outForDelivery;
      case 'handedToDelivery': return OrderStatus.delivered;
      default: return OrderStatus.pending;
    }
  }

  Future<List<DeliveryOrder>> fetchVendorOrders() async {
    final res = await _request('GET', '/api/orders');
    final list = res['data'] as List<dynamic>;
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
        totalItems: (map['totalItems'] as num).toInt(),
        service: map['service'] as String,
        status: mapBackendStatus(map['status'] as String),
      );
    }).toList();
  }

  Future<void> advanceVendorOrderStatusTo(String id, OrderStatus target) async {
    final res = await _request('GET', '/api/orders/$id');
    final currentStatus = res['data']['status'] as String;
    
    if (target == OrderStatus.inLaundry) {
      if (currentStatus == 'received') {
        await _request('PATCH', '/api/orders/$id/status');
      }
    } else if (target == OrderStatus.outForDelivery) {
      if (currentStatus == 'washing') {
        await _request('PATCH', '/api/orders/$id/status'); // to drying
        await _request('PATCH', '/api/orders/$id/status'); // to readyForDelivery
      } else if (currentStatus == 'drying') {
        await _request('PATCH', '/api/orders/$id/status'); // to readyForDelivery
      }
    }
  }
}
