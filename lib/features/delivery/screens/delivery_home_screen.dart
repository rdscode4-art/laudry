import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/enums.dart';
import '../../../core/models/delivery_order.dart';
import '../../../services/api_service.dart';
import '../../role_selection/screens/role_selection_screen.dart';
import '../widgets/delivery_order_card.dart';

class DeliveryHomeScreen extends StatefulWidget {
  final String boyName;
  const DeliveryHomeScreen({super.key, required this.boyName});
  @override State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}
class _DeliveryHomeScreenState extends State<DeliveryHomeScreen> {
  int _tab = 1;
  bool _loading = false;
  List<DeliveryOrder> _available = [];
  List<DeliveryOrder> _myRides = [];

  bool _isOnline = false;
  Timer? _locationTimer;
  Position? _lastPosition;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _fetchData();
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
    _locationTimer?.cancel();
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
      
      if (mounted) {
        setState(() {
          _available = [...pickups, ...deliveries];
          _myRides = myRides;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        Get.snackbar('Error', e.toString());
      }
    }
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
          Row(children: [_badge('Requests', '$_requests', kOrange), const SizedBox(width: 10), _badge('Active', '$_activeCount', Colors.teal), const SizedBox(width: 10), _badge('Delivered', '$_doneCount', kAccentGreen)]),
        ])),
        Container(color: kCardBg, child: Row(children: [_tabBtn('Available', 0), _tabBtn('Active', 1), _tabBtn('Delivered', 2)])),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _list.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300), const SizedBox(height: 12), Text('No orders here', style: TextStyle(color: Colors.grey.shade400, fontSize: 16))]))
            : RefreshIndicator(onRefresh: _fetchData, child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _list.length, itemBuilder: (_, i) => DeliveryOrderCard(order: _list[i], onUpdated: _fetchData, isAvailable: _tab == 0)))),
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
}
