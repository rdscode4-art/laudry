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

  // ── Sound ──────────────────────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _lastSeenOrderId;
  bool _isPlayingSound = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioPlayer.setReleaseMode(ReleaseMode.release);
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
    super.dispose();
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
      Get.snackbar('Error', e.toString().replaceAll('Exception: ', ''));
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
    setState(() => _loading = true);
    try {
      final pickups = await ApiService.instance.fetchAvailablePickups();
      final deliveries = await ApiService.instance.fetchAvailableDeliveries();
      final myRides = await ApiService.instance.fetchMyRides();
      final stats = await ApiService.fetchDriverDashboardStats();
      Map<String, dynamic> settings = {};
      try {
        settings = await ApiService.instance.fetchPlatformSettings();
      } catch (e) {
        debugPrint('Failed to fetch platform settings: $e');
      }
      
      if (mounted) {
        final allAvailable = [...pickups, ...deliveries];
        setState(() {
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
          _loading = false;
        });

        // Play sound if a new available order arrived and driver is online
        if (_isOnline && allAvailable.isNotEmpty) {
          final topOrderId = allAvailable.first.id;
          if (topOrderId != _lastSeenOrderId) {
            _lastSeenOrderId = topOrderId;
            _playOrderSound();
          }
        } else if (allAvailable.isEmpty) {
          _stopOrderSound();
          _lastSeenOrderId = null;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        Get.snackbar('Error', e.toString());
      }
    }
  }

  // ── Sound helpers ──────────────────────────────────────────────
  Future<void> _playOrderSound() async {
    if (_isPlayingSound) return;
    _isPlayingSound = true;
    await _audioPlayer.play(AssetSource('order_sound.mp3'));
    _audioPlayer.onPlayerComplete.listen((_) => _isPlayingSound = false);
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
        title: Row(mainAxisSize: MainAxisSize.min, children: [ClipOval(child: Image.asset('assets/images/logo.jpeg', width: 30, height: 30, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.delivery_dining, color: Colors.white, size: 24))), const SizedBox(width: 8), const Text('RiDeal Delivery', style: TextStyle(fontWeight: FontWeight.bold))]),
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
}
