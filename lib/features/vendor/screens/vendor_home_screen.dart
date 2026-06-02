import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/enums.dart';
import '../../../core/models/delivery_order.dart';
import '../../../services/api_service.dart';
import '../widgets/vendor_order_card.dart';

class VendorHomeScreen extends StatefulWidget {
  final String vendorName;
  const VendorHomeScreen({super.key, required this.vendorName});
  @override State<VendorHomeScreen> createState() => _VendorHomeScreenState();
}
class _VendorHomeScreenState extends State<VendorHomeScreen> {
  int _tab = 0;
  List<DeliveryOrder> _orders = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final list = await ApiService.instance.fetchVendorOrders();
      if (!mounted) return;
      setState(() {
        _orders = list;
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to fetch orders: $e', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<DeliveryOrder> get _list {
    switch (_tab) {
      case 0: return _orders.where((o) => o.status == OrderStatus.pickedUp).toList();
      case 1: return _orders.where((o) => o.status == OrderStatus.inLaundry).toList();
      case 2: return _orders.where((o) => o.status == OrderStatus.outForDelivery || o.status == OrderStatus.delivered).toList();
      default: return _orders;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightBg,
      appBar: AppBar(
        backgroundColor: kOrange,
        title: Row(mainAxisSize: MainAxisSize.min, children: [ClipOval(child: Image.asset('assets/images/logo.jpeg', width: 30, height: 30, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.store, color: Colors.white, size: 24))), const SizedBox(width: 8), const Text('Vendor Portal', style: TextStyle(fontWeight: FontWeight.bold))]),
        actions: [Padding(padding: const EdgeInsets.only(right: 12), child: GestureDetector(onTap: () => _showProfile(context), child: CircleAvatar(radius: 18, backgroundColor: Colors.white.withOpacity(0.25), child: Text(widget.vendorName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))))],
      ),
      body: Column(children: [
        Container(color: kOrange, padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${widget.vendorName} 🏪', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4), const Text('Manage incoming laundry orders', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 16),
          Row(children: [
            _badge('Received', '${_orders.where((o) => o.status == OrderStatus.pickedUp).length}', Colors.white),
            const SizedBox(width: 10),
            _badge('Processing', '${_orders.where((o) => o.status == OrderStatus.inLaundry).length}', Colors.white),
            const SizedBox(width: 10),
            _badge('Dispatched', '${_orders.where((o) => o.status == OrderStatus.outForDelivery || o.status == OrderStatus.delivered).length}', Colors.white),
          ]),
        ])),        Container(color: kCardBg, child: Row(children: [_tabBtn('Received', 0), _tabBtn('Processing', 1), _tabBtn('Dispatched', 2)])),
        Expanded(child: _loading && _orders.isEmpty
            ? const Center(child: CircularProgressIndicator(color: kOrange))
            : RefreshIndicator(
                onRefresh: _fetchOrders,
                color: kOrange,
                child: _list.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300), const SizedBox(height: 12), Text('No orders in this category', style: TextStyle(color: Colors.grey.shade400, fontSize: 16))]))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _list.length,
                        itemBuilder: (_, i) => VendorOrderCard(
                          order: _list[i],
                          onUpdated: () => _fetchOrders(),
                        ),
                      ),
              )),
      ]),
    );
  }

  Widget _badge(String l, String v, Color c) => Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Column(children: [Text(v, style: TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.bold)), Text(l, style: TextStyle(color: c.withOpacity(0.8), fontSize: 11))])));
  Widget _tabBtn(String l, int i) { final a = _tab == i; return Expanded(child: GestureDetector(onTap: () => setState(() => _tab = i), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: a ? kOrange : Colors.transparent, width: 3))), child: Text(l, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, color: a ? kOrange : Colors.grey, fontSize: 13))))); }

  void _showProfile(BuildContext context) {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (_) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 20),
      CircleAvatar(radius: 36, backgroundColor: kOrange.withOpacity(0.15), child: Text(widget.vendorName[0].toUpperCase(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: kOrange))),
      const SizedBox(height: 12), Text(widget.vendorName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryBlue)),
      const SizedBox(height: 4), const Text('Vendor Partner · RiDeal Laundry India', style: TextStyle(fontSize: 13, color: Colors.grey)),
      const SizedBox(height: 20),
      OutlinedButton.icon(onPressed: () { ApiService.instance.currentVendorAuth = null; Get.back(); Get.back(); }, icon: const Icon(Icons.logout, color: Colors.redAccent), label: const Text('Logout', style: TextStyle(color: Colors.redAccent)), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      const SizedBox(height: 8),
    ])));
  }
}
