import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/enums.dart';
import '../../../core/models/delivery_order.dart';
import '../../../services/api_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/socket_service.dart';
import '../../role_selection/screens/role_selection_screen.dart';
import '../widgets/delivery_order_card.dart';
import 'delivery_order_detail_screen.dart';

import 'package:razorpay_flutter/razorpay_flutter.dart'
    if (dart.library.html) '../../../core/stubs/razorpay_stub.dart';
import 'package:flutter/foundation.dart';

class DeliveryHomeScreen extends StatefulWidget {
  final String boyName;
  const DeliveryHomeScreen({super.key, required this.boyName});
  @override State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}
class _DeliveryHomeScreenState extends State<DeliveryHomeScreen>
    with WidgetsBindingObserver {
  int _tab = 0;
  bool _loading = false;
  List<DeliveryOrder> _available = [];
  List<DeliveryOrder> _myRides = [];

  bool _isOnline = false;
  double _walletBalance = 0.0;
  double _totalEarnings = 0.0;
  double _minWithdraw = 200.0;
  Timer? _locationTimer;
  Position? _lastPosition;

  // ── Sound & Incoming ───────────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _lastSeenOrderId;
  bool _isPlayingSound = false;
  bool _isShowingIncoming = false;
  final Set<String> _ignoredOrders = {};
  Timer? _pollTimer;
  Map<String, dynamic>? _activeSubscription;

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
    _connectSocket();
    _loadStatus();
    _fetchData();
    _startPolling();
  }

  // ── App lifecycle (RiFresh pattern) ────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Cancel OS notification sounds + re-check for pending orders
      NotificationService.instance.stopSound();
      if (_isOnline) _fetchData();
    }
  }

  void _connectSocket() {
    final token = ApiService.instance.currentDeliveryAuth?.token;
    if (token != null) {
      SocketService.instance.connect(token);
      SocketService.instance.addOrderListener(_onSocketOrderUpdate);
      SocketService.instance.addNotifListener(_onSocketNotification);
    }
  }

  void _onSocketNotification(Map<String, dynamic> notif) {
    NotificationService.instance.handleSocketNotification(notif);
  }

  void _onSocketOrderUpdate(Map<String, dynamic> _) {
    if (mounted) _fetchData();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && _isOnline) _fetchData();
    });
  }

  Future<void> _loadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isOnline = prefs.getBool('driver_is_online') ?? false;
    if (isOnline) {
      _toggleStatus(true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _locationTimer?.cancel();
    SocketService.instance.removeOrderListener(_onSocketOrderUpdate);
    SocketService.instance.removeNotifListener(_onSocketNotification);
    _stopOrderSound();
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
        await ApiService.instance.purchaseDriverPlan(_pendingPlanCode!);
        await _fetchData();
        Get.snackbar('Success', 'Subscription Activated!', backgroundColor: Colors.green, colorText: Colors.white);
      } else {
        Get.snackbar('Error', 'Payment verification failed', backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      Get.snackbar('Error', e.toString(), backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      _pendingPlanCode = null;
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _pendingPlanCode = null;
    Get.snackbar('Payment Failed', response.message ?? 'Unknown error', backgroundColor: Colors.red, colorText: Colors.white);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    Get.snackbar('Wallet Selected', response.walletName ?? 'Unknown wallet', backgroundColor: Colors.blue, colorText: Colors.white);
  }

  Future<void> _toggleStatus(bool val) async {
    setState(() => _isOnline = val);
    try {
      await ApiService.updateDriverStatus(val ? 'online' : 'offline');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('driver_is_online', val);
      if (val) {
        _startLocationTracking();
      } else {
        _locationTimer?.cancel();
        _locationTimer = null;
        _stopOrderSound(); // stop sound when going offline
      }
      _fetchData();
    } catch (e) {
      setState(() => _isOnline = !val);
      final msg = e is ApiException ? e.message : e.toString().replaceAll('Exception: ', '');
      Get.snackbar('Error', msg);
    }
  }

  Future<void> _startLocationTracking() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    _locationTimer?.cancel();
    _checkAndSendLocation(); // send immediately once
    _locationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkAndSendLocation();
    });
  }

  Future<void> _checkAndSendLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (_lastPosition != null) {
        final dist = Geolocator.distanceBetween(_lastPosition!.latitude, _lastPosition!.longitude, pos.latitude, pos.longitude);
        if (dist > 200) {
          await ApiService.updateDriverLocation(pos.latitude, pos.longitude);
          _lastPosition = pos;
        }
      } else {
        await ApiService.updateDriverLocation(pos.latitude, pos.longitude);
        _lastPosition = pos;
      }
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final profile = await ApiService.fetchDriverProfileData();
      bool currentOnline = false;
      if (profile['status'] == 'online') {
        currentOnline = true;
      }

      final pickups = currentOnline ? await ApiService.instance.fetchAvailablePickups() : <DeliveryOrder>[];
      final deliveries = currentOnline ? await ApiService.instance.fetchAvailableDeliveries() : <DeliveryOrder>[];
      final myRides = await ApiService.instance.fetchMyRides();
      final stats = await ApiService.fetchDriverDashboardStats();
      Map<String, dynamic> settings = {};
      Map<String, dynamic>? sub;
      try {
        settings = await ApiService.instance.fetchPlatformSettings();
        sub = await ApiService.instance.fetchDriverActiveSubscription();
      } catch (e) {
        debugPrint('Failed to fetch platform settings/subscription: $e');
      }
      
      if (mounted) {
        final allAvailable = [...pickups, ...deliveries]
            .where((o) => !_ignoredOrders.contains(o.id))
            .toList();
            
        setState(() {
          _isOnline = currentOnline;
          _available = allAvailable;
          _myRides = myRides;
          if (stats['totalEarnings'] != null) {
            _totalEarnings = (stats['totalEarnings'] as num).toDouble();
          }
          if (stats['walletBalance'] != null) {
            _walletBalance = (stats['walletBalance'] as num).toDouble();
          }
          if (settings['min_withdraw_driver'] != null) {
            _minWithdraw = (settings['min_withdraw_driver'] as num).toDouble();
          }
          _activeSubscription = sub;
          _loading = false;
        });

        // Trigger incoming screen if driver is online and new orders exist
        if (_isOnline && allAvailable.isNotEmpty) {
          final topOrderId = allAvailable.first.id;
          if (topOrderId != _lastSeenOrderId) {
            _lastSeenOrderId = topOrderId;
            _triggerIncomingOrder(allAvailable.first);
          }
        } else if (allAvailable.isEmpty) {
          if (!_isShowingIncoming) {
            _stopOrderSound();
            _lastSeenOrderId = null;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ── Incoming order flow ────────────────────────────────────────
  void _triggerIncomingOrder(DeliveryOrder order) {
    if (_isShowingIncoming) return;
    _isShowingIncoming = true;
    NotificationService.instance.stopSound();
    _playOrderSound();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _showIncomingSheet(order);
    });
  }

  void _showIncomingSheet(DeliveryOrder order) {
    int countdown = 30;
    Timer? countdownTimer;
    final isRide = order.status == OrderStatus.inLaundry || order.status == OrderStatus.readyForDelivery;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
              LinearProgressIndicator(
                value: countdown / 30,
                color: countdown > 15 ? kAccentGreen : countdown > 8 ? kOrange : Colors.red,
                backgroundColor: Colors.grey.shade200,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(isRide ? '🛵 Delivery Ride!' : '📦 Pickup Request!',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kAccentGreen)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
                  child: Text('$countdown s', style: const TextStyle(fontWeight: FontWeight.bold, color: kAccentGreen)),
                ),
              ]),
              const SizedBox(height: 12),
              _infoRow(Icons.location_on_outlined, 'Location', order.customerAddress),
              _infoRow(Icons.checkroom_outlined, 'Items', '${order.totalItems} item(s)'),
              _infoRow(Icons.local_laundry_service_outlined, 'Service', order.service),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      countdownTimer?.cancel();
                      _ignoredOrders.add(order.id);
                      _stopOrderSound();
                      Navigator.pop(ctx);
                      _fetchData();
                    },
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), side: const BorderSide(color: Colors.redAccent), foregroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Ignore'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      countdownTimer?.cancel();
                      _stopOrderSound();
                      Navigator.pop(ctx);
                      Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
                      try {
                        if (order.status == OrderStatus.pending) {
                          await ApiService.instance.acceptPickup(order.id);
                        } else {
                          await ApiService.instance.acceptRide(order.id);
                        }
                        Get.back(); // close loading
                        Get.to(() => DeliveryOrderDetailScreen(order: order))?.then((_) => _fetchData());
                      } catch (e) {
                        Get.back(); // close loading
                        Get.snackbar('Error', e.toString());
                      }
                    },
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: kAccentGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Accept Ride', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ]),
          );
        });
      },
    ).whenComplete(() {
      countdownTimer?.cancel();
      _isShowingIncoming = false;
      _stopOrderSound();
    });
  }
  
  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.grey)),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  // ── Sound helpers ──────────────────────────────────────────────
  Future<void> _playOrderSound() async {
    if (_isPlayingSound) return;
    _isPlayingSound = true;
    try {
      await _audioPlayer.play(AssetSource('order_sound.mp3'));
    } catch (_) {}
  }

  Future<void> _stopOrderSound() async {
    _isPlayingSound = false;
    await _audioPlayer.stop();
  }

  int get _requests => _available.length;
  int get _activeCount => _myRides.where((o) => o.status != OrderStatus.delivered).length;
  int get _doneCount   => _myRides.where((o) => o.status == OrderStatus.delivered).length;
  
  List<DeliveryOrder> get _list {
    if (_tab == 0) return _available;
    if (_tab == 1) return _myRides.where((o) => o.status != OrderStatus.delivered).toList();
    return _myRides.where((o) => o.status == OrderStatus.delivered).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightBg,
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [ClipOval(child: Image.asset('assets/images/logo.jpeg', width: 30, height: 30, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.delivery_dining, color: Colors.white, size: 24))), const SizedBox(width: 8), const Flexible(child: Text('RiDeal Delivery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis))]),
        actions: [Padding(padding: const EdgeInsets.only(right: 12), child: GestureDetector(onTap: () => _showProfile(context), child: CircleAvatar(radius: 18, backgroundColor: Colors.white.withOpacity(0.25), child: Text(widget.boyName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))))],
      ),
      body: Column(children: [
        Container(color: kPrimaryBlue, padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Hello, ${widget.boyName} 👋', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Row(children: [
              Text(_isOnline ? 'Online' : 'Offline', style: TextStyle(color: _isOnline ? kAccentGreen : Colors.white54, fontSize: 14, fontWeight: FontWeight.bold)),
              Switch(value: _isOnline, onChanged: _toggleStatus, activeColor: kAccentGreen, activeTrackColor: kAccentGreen.withOpacity(0.5)),
            ]),
          ]),
          const SizedBox(height: 4), const Text("Here's your delivery dashboard", style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 16),
          Row(children: [
            _badge('Requests', '$_requests', kOrange), 
            const SizedBox(width: 10), 
            _badge('Active', '$_activeCount', Colors.teal), 
            const SizedBox(width: 10), 
            _badge('Delivered', '$_doneCount', kAccentGreen)
          ]),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.2))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Wallet Balance', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  Text('₹${_walletBalance.toStringAsFixed(0)}', style: const TextStyle(color: kAccentGreen, fontSize: 24, fontWeight: FontWeight.bold)),
                ]),
                ElevatedButton(
                  onPressed: _walletBalance > 0 ? () => _requestPayout() : null,
                  style: ElevatedButton.styleFrom(backgroundColor: kAccentGreen, foregroundColor: Colors.white),
                  child: const Text('Withdraw'),
                )
              ]
            ),
          ),
        ])),
        Container(color: kCardBg, child: Row(children: [_tabBtn('Available', 0), _tabBtn('Active', 1), _tabBtn('Delivered', 2)])),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _list.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300), const SizedBox(height: 12), Text('No orders here', style: TextStyle(color: Colors.grey.shade400, fontSize: 16))]))
            : RefreshIndicator(onRefresh: _fetchData, child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _list.length, itemBuilder: (_, i) => DeliveryOrderCard(order: _list[i], onUpdated: _fetchData, isAvailable: _tab == 0, onAccepted: _tab == 0 ? _stopOrderSound : null)))),
      ]),
    );
  }

  Widget _badge(String l, String v, Color c) => Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(0.3))), child: Column(children: [Text(v, style: TextStyle(color: c, fontSize: 22, fontWeight: FontWeight.bold)), Text(l, style: TextStyle(color: c.withOpacity(0.8), fontSize: 11))])));
  Widget _tabBtn(String l, int i) { final a = _tab == i; return Expanded(child: GestureDetector(onTap: () => setState(() => _tab = i), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: a ? kAccentGreen : Colors.transparent, width: 3))), child: Text(l, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, color: a ? kAccentGreen : Colors.grey, fontSize: 14))))); }

  void _showProfile(BuildContext context) {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (_) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 20),
      CircleAvatar(radius: 36, backgroundColor: kAccentGreen.withOpacity(0.15), child: Text(widget.boyName[0].toUpperCase(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: kAccentGreen))),
      const SizedBox(height: 12), Text(widget.boyName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryBlue)),
      const SizedBox(height: 4), const Text('Delivery Partner · RiDeal Laundry India', style: TextStyle(fontSize: 13, color: Colors.grey)),
      const SizedBox(height: 20),
      OutlinedButton.icon(onPressed: () { Navigator.pop(context); _showSubscriptionDialog(); }, icon: const Icon(Icons.star, color: kOrange), label: Text(_activeSubscription == null ? 'Get Subscription' : 'Manage Subscription', style: const TextStyle(color: kOrange)), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), side: const BorderSide(color: kOrange), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: () { ApiService.instance.currentDeliveryAuth = null; Get.offAll(() => RoleSelectionScreen()); }, icon: const Icon(Icons.logout, color: Colors.redAccent), label: const Text('Logout', style: TextStyle(color: Colors.redAccent)), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height: 8),
    ])));
  }

  void _requestPayout() {
    final txt = TextEditingController();
    Get.dialog(AlertDialog(
      title: const Text('Request Payout'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: txt,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Amount (Max ₹${_walletBalance.toStringAsFixed(0)})',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 8),
          Text(
            'Minimum withdrawal limit: ₹${_minWithdraw.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            final amt = double.tryParse(txt.text) ?? 0.0;
            if (amt < _minWithdraw) {
              Get.snackbar('Error', 'Amount must be at least ₹${_minWithdraw.toStringAsFixed(0)}', backgroundColor: Colors.red, colorText: Colors.white);
              return;
            }
            if (amt > _walletBalance) {
              Get.snackbar('Error', 'Insufficient wallet balance', backgroundColor: Colors.red, colorText: Colors.white);
              return;
            }
            Get.back();
            try {
              await ApiService.requestDriverPayout(amt);
              Get.snackbar('Success', 'Payout requested successfully', backgroundColor: Colors.green, colorText: Colors.white);
              _fetchData();
            } catch (e) {
              Get.snackbar('Error', e.toString(), backgroundColor: Colors.red, colorText: Colors.white);
            }
          },
          child: const Text('Submit'),
        )
      ],
    ));
  }

  void _showSubscriptionDialog() async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    List<Map<String, dynamic>> plans = [];
    try {
      plans = await ApiService.instance.fetchDriverPlans();
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
                const Text('Driver Subscription', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimaryBlue)),
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
                      Text('Active Plan: ${_activeSubscription!['plan_name'] ?? _activeSubscription!['plan_code'] ?? 'N/A'}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      Text('Valid till: ${(_activeSubscription!['expires_at'] ?? 'N/A').toString().split('T').first}',
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
                    final price = plan['price_monthly'] ?? 0;
                    final validityDays = plan['validity_days'] ?? 30;
                    final isCurrentPlan = _activeSubscription?['plan_code'] == plan['code'] &&
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
    final total = plan['price_monthly'] ?? plan['priceMonthly'];

    if (total == null || total == 0) {
      try {
        await ApiService.instance.purchaseDriverPlan(_pendingPlanCode!);
        await _fetchData();
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
        'description': 'Driver Subscription: ${plan['name']}',
        'order_id': orderData['id'],
        'prefill': {
          'contact': '9999999999',
          'email': 'driver@rideal.in'
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
