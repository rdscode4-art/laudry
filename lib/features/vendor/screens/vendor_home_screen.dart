import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/enums.dart';
import '../../../core/models/delivery_order.dart';
import '../../../services/api_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/socket_service.dart';
import '../../role_selection/screens/role_selection_screen.dart';
import '../widgets/vendor_order_card.dart';
import 'vendor_order_detail_screen.dart';

import 'package:razorpay_flutter/razorpay_flutter.dart'
    if (dart.library.html) '../../../core/stubs/razorpay_stub.dart';
import 'package:flutter/foundation.dart';

class VendorHomeScreen extends StatefulWidget {
  final String vendorName;
  const VendorHomeScreen({super.key, required this.vendorName});
  @override
  State<VendorHomeScreen> createState() => _VendorHomeScreenState();
}

class _VendorHomeScreenState extends State<VendorHomeScreen>
    with WidgetsBindingObserver {
  int _tab = 0;
  List<DeliveryOrder> _orders = [];
  List<Map<String, dynamic>> _broadcastOrders = [];
  final Set<String> _ignoredBroadcasts = {};
  bool _loading = false;
  double _walletBalance = 0.0;
  double _minWithdraw = 500.0;
  Map<String, dynamic>? _activeSubscription;
  bool _isOnline = false;

  // ── Sound (RiFresh pattern) ────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _lastSeenOrderId;   // tracks last new order id — prevents repeat sound
  bool _isShowingIncoming = false; // prevents duplicate incoming screen

  // ── Polling + Socket + Razorpay ───────────────────────────────────────────
  Timer? _pollTimer;
  late Razorpay _razorpay;
  String? _pendingPlanCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
    
    // Configure to use Alarm stream so it plays loud like notifications
    _audioPlayer.setAudioContext(const AudioContext(
      android: AudioContextAndroid(
        usageType: AndroidUsageType.alarm,
        contentType: AndroidContentType.sonification,
        audioFocus: AndroidAudioFocus.gainTransientExclusive,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: [AVAudioSessionOptions.mixWithOthers],
      ),
    ));
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _fetchOrders();
    _startPolling();
    _connectSocket();
  }

  // ── App lifecycle (RiFresh pattern: resume → cancel OS notif + re-check) ──
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Cancel any OS notification sounds that may be playing
      NotificationService.instance.stopSound();
      // Re-check for pending orders
      _fetchOrders();
    }
  }

  // ── Socket ─────────────────────────────────────────────────────
  void _connectSocket() {
    final token = ApiService.instance.currentVendorAuth?.token;
    if (token != null) {
      SocketService.instance.connect(token);
      SocketService.instance.addOrderListener(_onSocketOrderUpdate);
      SocketService.instance.addNotifListener(_onSocketNotification);
    }
  }

  void _onSocketNotification(Map<String, dynamic> notif) {
    NotificationService.instance.handleSocketNotification(notif);
  }

  void _onSocketOrderUpdate(Map<String, dynamic> payload) {
    if (!mounted) return;
    _fetchOrders();

    // New order arrived via socket → show incoming screen + play sound
    final order = payload['order'] as Map<String, dynamic>?;
    final trackingStatus = order?['trackingStatus'] as String? ?? '';
    final isNew = order?['isNew'] == true || trackingStatus == 'order_placed';
    if (isNew) {
      // Just rely on fetchOrders to pick it up and handle tracking ignored broadcasts
    }
  }

  // ── Polling (10s fallback) ─────────────────────────────────────
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && _isOnline) _fetchOrders();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    SocketService.instance.removeOrderListener(_onSocketOrderUpdate);
    SocketService.instance.removeNotifListener(_onSocketNotification);
    _stopSound(); // always stop on dispose
    _audioPlayer.dispose();
    if (!kIsWeb) _razorpay.clear();
    super.dispose();
  }

  // ── Razorpay Handlers ──────────────────────────────────────────
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final success = await ApiService.verifyRazorpayPayment(
        razorpayOrderId: response.orderId ?? '',
        razorpayPaymentId: response.paymentId ?? '',
        razorpaySignature: response.signature ?? '',
      );
      if (success && _pendingPlanCode != null) {
        await ApiService.instance.purchaseVendorPlan(_pendingPlanCode!);
        await _fetchOrders();
        Get.snackbar('Success', 'Subscription Activated!',
            backgroundColor: Colors.green, colorText: Colors.white);
      } else {
        Get.snackbar('Error', 'Payment verification failed',
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      _pendingPlanCode = null;
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _pendingPlanCode = null;
    Get.snackbar('Payment Failed', response.message ?? 'Unknown error',
        backgroundColor: Colors.red, colorText: Colors.white);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    Get.snackbar('Wallet Selected', response.walletName ?? 'Unknown wallet',
        backgroundColor: Colors.blue, colorText: Colors.white);
  }

  // ── Fetch ──────────────────────────────────────────────────────
  Future<void> _fetchOrders() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final profile = await ApiService.fetchVendorProfile();
      bool currentOnline = true;
      if (profile['isOnline'] != null) {
        currentOnline = profile['isOnline'] as bool;
      }
      
      final list = await ApiService.instance.fetchVendorOrders();
      final broadcasts = currentOnline 
          ? await ApiService.fetchVendorBroadcastOrders() 
          : <Map<String, dynamic>>[];
          
      Map<String, dynamic> settings = {};
      Map<String, dynamic>? sub;
      try {
        settings = await ApiService.instance.fetchPlatformSettings();
        sub = await ApiService.instance.fetchVendorActiveSubscription();
      } catch (_) {}
      if (!mounted) return;
      
      setState(() {
        _isOnline = currentOnline;
        _orders = list;
        _broadcastOrders = broadcasts.where((b) => !_ignoredBroadcasts.contains(b['id'])).toList();
        if (profile['walletBalance'] != null) {
          _walletBalance = (profile['walletBalance'] as num).toDouble();
        }
        if (settings['min_withdraw_vendor'] != null) {
          _minWithdraw = (settings['min_withdraw_vendor'] as num).toDouble();
        }
        _activeSubscription = sub;
        _loading = false;
      });

      // Polling detected a new incoming order → trigger incoming screen
      final incoming = list
          .where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.pickedUp)
          .toList();
      
      String? topId;
      DeliveryOrder? incomingOrder;
      Map<String, dynamic>? broadcastOrder;
      
      if (incoming.isNotEmpty) {
        topId = incoming.first.id;
        incomingOrder = incoming.first;
      } else if (_broadcastOrders.isNotEmpty) {
        topId = _broadcastOrders.first['id'];
        broadcastOrder = _broadcastOrders.first;
      }

      debugPrint('[Vendor] incoming orders: ${incoming.length}, broadcasts: ${_broadcastOrders.length}, lastSeenId: $_lastSeenOrderId');
      if (topId != null) {
        debugPrint('[Vendor] topId: $topId, match: ${topId != _lastSeenOrderId}');
        if (topId != _lastSeenOrderId) {
          _lastSeenOrderId = topId;
          _triggerIncomingOrder(order: incomingOrder, broadcast: broadcastOrder);
        }
      } else {
        // No pending orders — ensure sound and state are reset
        if (!_isShowingIncoming) {
          _stopSound();
          _lastSeenOrderId = null;
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to fetch orders: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent,
          colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Incoming order flow (RiFresh IncomingOrderScreen pattern) ──
  void _triggerIncomingOrder({DeliveryOrder? order, Map<String, dynamic>? broadcast}) {
    if (_isShowingIncoming) {
      debugPrint('[Vendor] _triggerIncomingOrder: already showing, skip');
      return;
    }

    if (order == null && broadcast == null) return;

    _isShowingIncoming = true;
    // Cancel any OS notification sounds first (RiFresh pattern)
    NotificationService.instance.stopSound();
    // Start in-app loop sound
    _playSound();

    // Show incoming order bottom sheet with countdown
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _showIncomingSheet(order: order, broadcast: broadcast);
    });
  }

  void _showIncomingSheet({DeliveryOrder? order, Map<String, dynamic>? broadcast}) {
    int countdown = 30;
    Timer? countdownTimer;
    
    final id = order?.id ?? broadcast?['id'] ?? 'Unknown';
    final items = order?.totalItems ?? broadcast?['totalItems'] ?? 0;
    final service = order?.service ?? broadcast?['service'] ?? 'Laundry';
    final isBroadcast = broadcast != null;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (countdown <= 1) {
              t.cancel();
              if (Navigator.canPop(ctx)) Navigator.pop(ctx);
            } else {
              setSheet(() => countdown--);
            }
          });

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Countdown bar
              LinearProgressIndicator(
                value: countdown / 30,
                color: countdown > 15
                    ? kAccentGreen
                    : countdown > 8 ? kOrange : Colors.red,
                backgroundColor: Colors.grey.shade200,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(isBroadcast ? '📡 Broadcast Order!' : '🛍️ New Order!',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kOrange)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('$countdown s',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: kOrange)),
                ),
              ]),
              const SizedBox(height: 12),
              _infoRow(Icons.confirmation_number_outlined, 'Order ID', id),
              if (!isBroadcast && order != null)
                _infoRow(Icons.person_outline, 'Customer', order.customerName),
              _infoRow(Icons.checkroom_outlined, 'Items', '$items item(s)'),
              _infoRow(Icons.local_laundry_service_outlined, 'Service', service),
              const SizedBox(height: 20),
              Row(children: [
                // Ignore
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      countdownTimer?.cancel();
                      if (isBroadcast && broadcast != null) {
                        _ignoredBroadcasts.add(broadcast['id']);
                        _fetchOrders();
                      }
                      _stopSound(); // stop sound immediately on ignore
                      Navigator.pop(ctx);
                    },
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        side: const BorderSide(color: Colors.redAccent),
                        foregroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: const Text('Ignore'),
                  ),
                ),
                const SizedBox(width: 12),
                // Accept
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      countdownTimer?.cancel();
                      _stopSound(); // stop sound immediately on accept
                      Navigator.pop(ctx);
                      if (isBroadcast) {
                        _acceptBroadcast(id);
                      } else if (order != null) {
                        Get.to(() => VendorOrderDetailScreen(order: order))
                            ?.then((_) => _fetchOrders());
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: kOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: const Text('Accept Order',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
            ]),
          );
        });
      },
    ).whenComplete(() {
      countdownTimer?.cancel();
      _stopSound(); // fallback — stop sound if sheet closed via back gesture/countdown
      _isShowingIncoming = false;
    });
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          SizedBox(width: 72, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
      );

  // ── Sound helpers (RiFresh pattern) ────────────────────────────
  Future<void> _playSound() async {
    debugPrint('[Vendor] _playSound called');
    try {
      await _audioPlayer.play(AssetSource('order_sound.mp3'));
      debugPrint('[Vendor] _playSound: playing');
    } catch (e) {
      debugPrint('[Vendor] _playSound error: $e');
    }
  }

  Future<void> _stopSound() async {
    try {
      await _audioPlayer.stop();
      debugPrint('[Vendor] _stopSound: stopped');
    } catch (e) {
      debugPrint('[Vendor] _stopSound error: $e');
    }
  }

  // ── Accept broadcast order ─────────────────────────────────────
  Future<void> _acceptBroadcast(String orderId) async {
    setState(() => _loading = true);
    _stopSound();
    final res = await ApiService.acceptVendorBroadcastOrder(orderId);
    if (res['success']) {
      Get.snackbar('Success', 'Order accepted!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: kAccentGreen,
          colorText: Colors.white);
      _fetchOrders();
    } else {
      Get.snackbar('Failed', res['message'] ?? 'Could not accept order',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent,
          colorText: Colors.white);
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    setState(() {
      _isOnline = value;
      _loading = true;
    });
    final res = await ApiService.setVendorOnlineStatus(value);
    setState(() => _loading = false);
    if (res['success'] == true) {
      if (value) _fetchOrders(); // Fetch immediately when going online
      Get.snackbar('Status Updated', 'You are now ${value ? "Online" : "Offline"}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: value ? Colors.green : Colors.grey.shade700,
          colorText: Colors.white);
    } else {
      setState(() => _isOnline = !value); // Revert on failure
      Get.snackbar('Failed', res['message'] ?? 'Could not update status',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent,
          colorText: Colors.white);
    }
  }

  List<DeliveryOrder> get _list {
    switch (_tab) {
      case 0:
        return _orders
            .where((o) =>
                o.status == OrderStatus.pending ||
                o.status == OrderStatus.pickedUp)
            .toList();
      case 1:
        return _orders
            .where((o) =>
                o.status == OrderStatus.inLaundry ||
                o.status == OrderStatus.readyForDelivery)
            .toList();
      case 2:
        return _orders
            .where((o) =>
                o.status == OrderStatus.outForDelivery ||
                o.status == OrderStatus.delivered)
            .toList();
      default:
        return _orders;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightBg,
      appBar: AppBar(
        backgroundColor: kOrange,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          ClipOval(
              child: Image.asset('assets/images/logo.jpeg',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.store, color: Colors.white, size: 24))),
          const SizedBox(width: 8),
          const Flexible(
            child: Text('Vendor Portal',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
        actions: [
          Row(
            children: [
              Text(_isOnline ? 'Online' : 'Offline',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              Switch(
                value: _isOnline,
                activeColor: Colors.white,
                activeTrackColor: Colors.green,
                inactiveThumbColor: Colors.grey.shade400,
                inactiveTrackColor: Colors.grey.shade300,
                onChanged: _toggleOnlineStatus,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _showProfile(context),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                child: Text(widget.vendorName[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ),
          )
        ],
      ),
      body: Column(children: [
        // ── Header ─────────────────────────────────────────────
        Container(
          color: kOrange,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${widget.vendorName} 🏪',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Manage incoming laundry orders',
                style: TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 16),
            Row(children: [
              _badge('Broadcasts', '${_broadcastOrders.length}', Colors.white),
              const SizedBox(width: 10),
              _badge('Incoming', '${_orders.where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.pickedUp).length}', Colors.white),
              const SizedBox(width: 10),
              _badge('Processing', '${_orders.where((o) => o.status == OrderStatus.inLaundry || o.status == OrderStatus.readyForDelivery).length}', Colors.white),
              const SizedBox(width: 10),
              _badge('Dispatched', '${_orders.where((o) => o.status == OrderStatus.outForDelivery || o.status == OrderStatus.delivered).length}', Colors.white),
            ]),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Wallet Balance',
                        style: TextStyle(color: Colors.white60, fontSize: 12)),
                    Text('₹${_walletBalance.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                  ]),
                  ElevatedButton(
                    onPressed: _walletBalance > 0 ? () => _requestPayout() : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, foregroundColor: kOrange),
                    child: const Text('Withdraw'),
                  )
                ],
              ),
            ),
          ]),
        ),

        // ── Tabs ───────────────────────────────────────────────
        Container(
          color: kCardBg,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _tabBtn('Broadcasts', 3),
              _tabBtn('Incoming', 0),
              _tabBtn('Processing', 1),
              _tabBtn('Dispatched', 2),
            ]),
          ),
        ),

        // ── List ───────────────────────────────────────────────
        Expanded(
          child: _loading && _orders.isEmpty && _broadcastOrders.isEmpty
              ? const Center(child: CircularProgressIndicator(color: kOrange))
              : RefreshIndicator(
                  onRefresh: _fetchOrders,
                  color: kOrange,
                  child: _tab == 3
                      ? _buildBroadcastList()
                      : _list.isEmpty
                          ? Center(
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.inbox_outlined,
                                        size: 64, color: Colors.grey.shade300),
                                    const SizedBox(height: 12),
                                    Text('No orders in this category',
                                        style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 16)),
                                  ]))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _list.length,
                              itemBuilder: (_, i) => VendorOrderCard(
                                order: _list[i],
                                onUpdated: () => _fetchOrders(),
                              ),
                            ),
                ),
        ),
      ]),
    );
  }

  Widget _buildBroadcastList() {
    if (_broadcastOrders.isEmpty) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.radar, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('No nearby orders found',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _broadcastOrders.length,
      itemBuilder: (_, i) {
        final bo = _broadcastOrders[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('New Order!',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: kOrange, fontSize: 16)),
                Text('${bo['distanceKm']?.toStringAsFixed(1) ?? '?'} km away',
                    style: const TextStyle(
                        color: Colors.grey, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 8),
              Text('${bo['totalItems']} items · ${bo['service']}',
                  style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  onPressed: () => _acceptBroadcast(bo['id']),
                  child: const Text('Accept Order'),
                ),
              )
            ]),
          ),
        );
      },
    );
  }

  Widget _badge(String l, String v, Color c) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text(v,
                style: TextStyle(
                    color: c, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(l,
                style:
                    TextStyle(color: c.withValues(alpha: 0.8), fontSize: 10)),
          ]),
        ),
      );

  Widget _tabBtn(String l, int i) {
    final a = _tab == i;
    return GestureDetector(
      onTap: () => setState(() => _tab = i),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: a ? kOrange : Colors.transparent, width: 3))),
        child: Text(l,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: a ? kOrange : Colors.grey,
                fontSize: 13)),
      ),
    );
  }

  void _showProfile(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          CircleAvatar(
              radius: 36,
              backgroundColor: kOrange.withValues(alpha: 0.15),
              child: Text(widget.vendorName[0].toUpperCase(),
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: kOrange))),
          const SizedBox(height: 12),
          Text(widget.vendorName,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryBlue)),
          const SizedBox(height: 4),
          const Text('Vendor Partner · RiDeal Laundry India',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () {
              Get.back();
              _showSubscriptionDialog();
            },
            icon: const Icon(Icons.star, color: kOrange),
            label: Text(_activeSubscription == null ? 'Get Subscription' : 'Manage Subscription',
                style: const TextStyle(color: kOrange)),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: kOrange),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              ApiService.instance.currentVendorAuth = null;
              Get.offAll(() => const RoleSelectionScreen());
            },
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            label: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _requestPayout() {
    final txt = TextEditingController();
    Get.dialog(AlertDialog(
      title: const Text('Request Payout'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: txt,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Amount (Max ₹${_walletBalance.toStringAsFixed(0)})',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Text('Minimum: ₹${_minWithdraw.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            final amt = double.tryParse(txt.text) ?? 0.0;
            if (amt < _minWithdraw) {
              Get.snackbar('Error', 'Minimum ₹${_minWithdraw.toStringAsFixed(0)}',
                  backgroundColor: Colors.red, colorText: Colors.white);
              return;
            }
            if (amt > _walletBalance) {
              Get.snackbar('Error', 'Insufficient balance',
                  backgroundColor: Colors.red, colorText: Colors.white);
              return;
            }
            Get.back();
            try {
              await ApiService.requestVendorPayout(amt);
              Get.snackbar('Success', 'Payout requested',
                  backgroundColor: Colors.green, colorText: Colors.white);
              _fetchOrders();
            } catch (e) {
              Get.snackbar('Error', e.toString(),
                  backgroundColor: Colors.red, colorText: Colors.white);
            }
          },
          child: const Text('Submit'),
        ),
      ],
    ));
  }

  void _showSubscriptionDialog() async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    List<Map<String, dynamic>> plans = [];
    try {
      plans = await ApiService.instance.fetchVendorPlans();
    } catch (e) {
      if (mounted) {
        Get.back();
        Get.snackbar('Error', 'Plans fetch failed: ${e is ApiException ? e.message : e}',
            backgroundColor: Colors.red, colorText: Colors.white);
      }
      return;
    }
    if (!mounted) return;
    Get.back();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.star, color: kOrange),
                const SizedBox(width: 8),
                const Text('Vendor Subscription', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimaryBlue)),
              ]),
              const SizedBox(height: 12),
              if (_activeSubscription != null && _activeSubscription!['status'] == 'active') ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green)
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Active Plan: ${_activeSubscription!['planName'] ?? _activeSubscription!['planCode'] ?? 'N/A'}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      Text('Valid till: ${(_activeSubscription!['currentPeriodEnd'] ?? _activeSubscription!['trialEndsAt'] ?? 'N/A').toString().split('T').first}',
                          style: const TextStyle(fontSize: 12, color: Colors.green)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
              const Text('Choose a plan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              Expanded(
                child: plans.isEmpty
                  ? const Center(child: Text('No plans available', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                  itemCount: plans.length,
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    final price = plan['priceMonthly'] ?? plan['price_monthly'] ?? 0;
                    final validityDays = plan['validityDays'] ?? plan['validity_days'] ?? 30;
                    final isCurrentPlan = _activeSubscription?['planCode'] == plan['code'] &&
                        _activeSubscription?['status'] == 'active';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: isCurrentPlan ? 3 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isCurrentPlan ? kAccentGreen : Colors.grey.shade300, width: isCurrentPlan ? 2 : 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text(plan['name'] ?? 'Plan', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              if (isCurrentPlan) ...[
                                const SizedBox(width: 8),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: kAccentGreen, borderRadius: BorderRadius.circular(10)), child: const Text('Active', style: TextStyle(color: Colors.white, fontSize: 10))),
                              ],
                            ]),
                            const SizedBox(height: 4),
                            Text('₹$price / ${validityDays >= 60 ? "${validityDays ~/ 30} months" : "month"}',
                                style: const TextStyle(color: kOrange, fontWeight: FontWeight.bold, fontSize: 14)),
                          ])),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCurrentPlan ? Colors.grey : kPrimaryBlue,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: isCurrentPlan ? null : () => _purchasePlan(plan),
                            child: Text(isCurrentPlan ? 'Current' : 'Select'),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _purchasePlan(Map<String, dynamic> plan) async {
    Get.back(); // close modal
    _pendingPlanCode = plan['code'];
    final total = plan['priceMonthly'] ?? plan['price_monthly'];

    if (total == null || total == 0) {
      try {
        await ApiService.instance.purchaseVendorPlan(_pendingPlanCode!);
        await _fetchOrders();
        Get.snackbar('Success', 'Subscribed successfully!', backgroundColor: Colors.green, colorText: Colors.white);
      } catch (e) {
        Get.snackbar('Error', 'Failed to activate plan: $e', backgroundColor: Colors.red, colorText: Colors.white);
      }
      return;
    }

    try {
      final orderData = await ApiService.createRazorpayOrder((total as num).toDouble());
      final options = {
        'key': 'rzp_test_SznBROOyov9Oda', // Use your test or live key
        'amount': orderData['amount'],
        'name': 'RiDeal Laundry',
        'description': 'Vendor Subscription: ${plan['name']}',
        'order_id': orderData['id'],
        'prefill': {
          'contact': '9999999999',
          'email': 'vendor@rideal.in'
        },
        'theme': {'color': '#1E88E5'},
      };
      if (!kIsWeb) {
        _razorpay.open(options);
      } else {
        Get.snackbar('Web Payment', 'Razorpay is not supported on web. Use mobile app.');
      }
    } catch (e) {
      _pendingPlanCode = null;
      Get.snackbar('Error', 'Could not initiate payment: $e', backgroundColor: Colors.red, colorText: Colors.white);
    }
  }
}
