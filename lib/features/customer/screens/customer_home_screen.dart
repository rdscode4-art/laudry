import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/enums.dart';
import '../../../services/api_service.dart';
import '../controllers/customer_controller.dart';
import '../widgets/customer_shared_widgets.dart';

import 'customer_booking_screens.dart';
import 'customer_order_screens.dart';
import 'customer_profile_screens.dart';
import 'customer_support_screens.dart';

// ── HOME HUB ───────────────────────────────────────────────────
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});
  @override State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}
class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _tab = 0;
  late String _weather;
  @override void initState() {
    super.initState();
    _weather = ['Sunny','Rainy','Cloudy','Windy'][Random().nextInt(4)];
    final ctrl = CustomerController.instance;
    if (ctrl.selectedService.value == 'Laundry') {
      if (_weather == 'Rainy' || _weather == 'Cloudy') {
        ctrl.selectedService.value = 'Dry Cleaner';
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final pages = [
      _CustHomeTab(weather: _weather, onRefresh: () => setState(() {})),
      const _CustOrdersTab(),
      _CustWalletTab(onRefresh: () => setState(() {})),
      _CustProfileTab(onRefresh: () => setState(() {})),
    ];
    return Scaffold(
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        indicatorColor: kAccentBlue.withOpacity(0.12),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ── HOME TAB ───────────────────────────────────────────────────
class _CustHomeTab extends StatefulWidget {
  final String weather; final VoidCallback onRefresh;
  const _CustHomeTab({required this.weather, required this.onRefresh});
  @override State<_CustHomeTab> createState() => _CustHomeTabState();
}
class _CustHomeTabState extends State<_CustHomeTab> {
  String get _rec => (widget.weather == 'Rainy' || widget.weather == 'Cloudy') ? 'Dry Cleaner' : 'Laundry';
  @override
  Widget build(BuildContext context) {
    final ctrl = CustomerController.instance;
    return Scaffold(
      backgroundColor: kLightBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          ClipOval(child: Image.asset('assets/images/logo.jpeg', width: 30, height: 30, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.local_laundry_service, color: Colors.white, size: 24))),
          const SizedBox(width: 8), const Text('RiDeal Laundry', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Obx(() => Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0D2B5E), kAccentBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: kAccentBlue.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))]),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hello, ${ctrl.session.value?.name.split(' ')[0] ?? 'Guest'} 👋', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text('📦 ${ctrl.activeSubscription.value?['plan_name'] ?? 'No Active Plan'}', style: const TextStyle(color: Colors.white, fontSize: 12))),
              const SizedBox(height: 6),
              Row(children: [const Icon(Icons.account_balance_wallet_outlined, color: Colors.white70, size: 14), const SizedBox(width: 4),
                Text('₹${ctrl.walletBalance.value.toStringAsFixed(0)} Wallet', style: const TextStyle(color: Colors.white70, fontSize: 12))]),
            ])),
            ClipOval(child: Image.asset('assets/images/logo.jpeg', width: 60, height: 60, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.local_laundry_service, color: Colors.white, size: 48))),
          ]))),
        const SizedBox(height: 16),
        // Quick actions
        Row(children: [
          _qa(context, Icons.local_laundry_service, 'Book\nPickup', kAccentBlue, () => Get.to(() => const BookScreen())),
          const SizedBox(width: 10),
          _qa(context, Icons.track_changes, 'Track\nOrder', kAccentGreen, () {
            final active = ctrl.activeOrders.isNotEmpty ? ctrl.activeOrders.first : null;
            Get.to(() => OrderTrackingScreen(orderData: active));
          }),
          const SizedBox(width: 10),
          _qa(context, Icons.receipt_long_outlined, 'Invoice', kOrange, () {
            final latest = (ctrl.activeOrders.isNotEmpty ? ctrl.activeOrders.first : (ctrl.pastOrders.isNotEmpty ? ctrl.pastOrders.first : null));
            Get.to(() => InvoiceScreen(orderData: latest));
          }),
          const SizedBox(width: 10),
          _qa(context, Icons.chat_outlined, 'Support', const Color(0xFF25D366), () => Get.to(() => const SupportScreen())),
        ]),
        const SizedBox(height: 20),
        // Service selection
        const Text('Choose Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kPrimaryBlue)),
        const SizedBox(height: 10),
        Obx(() {
          if (ctrl.dynamicServices.isEmpty) return const Center(child: CircularProgressIndicator());
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ctrl.dynamicServices.map((srv) {
                final String srvName = srv['name'] ?? 'Unknown';
                final String? srvImage = srv['image_url'];
                final active = ctrl.selectedService.value == srvName;
                return GestureDetector(
                  onTap: () { ctrl.selectedService.value = srvName; widget.onRefresh(); },
                  child: AnimatedContainer(
                    width: 110,
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                    decoration: BoxDecoration(
                      color: active ? kAccentBlue : kCardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: active ? kAccentBlue : Colors.grey.shade200, width: 2),
                      boxShadow: [BoxShadow(color: active ? kAccentBlue.withOpacity(0.3) : Colors.black.withOpacity(0.05), blurRadius: active ? 14 : 8)]
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (srvImage != null && srvImage.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              '${ApiService.baseUrl}$srvImage',
                              width: 32, height: 32, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.category, size: 28, color: active ? Colors.white : kAccentBlue),
                            )
                          )
                        else
                          Icon(Icons.category, size: 28, color: active ? Colors.white : kAccentBlue),
                        const SizedBox(height: 8),
                        Text(srvName, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: active ? Colors.white : kPrimaryBlue)),
                        if (active) ...[const SizedBox(height: 4), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                            child: const Text('Selected', style: TextStyle(color: Colors.white, fontSize: 10)))],
                      ]
                    )
                  )
                );
              }).toList()
            )
          );
        }),
        const SizedBox(height: 16),
        _infoCard2(Icons.wb_sunny_outlined, kOrange, "Today: ${widget.weather}", 'Recommended: $_rec', widget.weather),
        const SizedBox(height: 10),
        _infoCard2(Icons.location_on, kAccentGreen, 'Nearest Laundry', 'Quick Clean Laundry', '0.5 km'),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => Get.to(() => const BookScreen()),
          icon: const Icon(Icons.local_laundry_service, size: 22), label: const Text('Book Pickup Now'),
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: kPrimaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 4),
        ),
      ])),
    );
  }
  Widget _qa(BuildContext ctx, IconData icon, String label, Color color, VoidCallback onTap) =>
      Expanded(child: GestureDetector(onTap: onTap, child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(children: [Icon(icon, color: color, size: 20), const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600))]),
      )));
  Widget _infoCard2(IconData icon, Color color, String title, String sub, String badge) =>
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: kPrimaryBlue, fontSize: 13)),
              Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(badge, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600))),
          ]));
}

// ── ORDERS TAB ─────────────────────────────────────────────────
class _CustOrdersTab extends StatelessWidget {
  const _CustOrdersTab();
  @override
  Widget build(BuildContext context) {
    final ctrl = CustomerController.instance;
    return Scaffold(
      backgroundColor: kLightBg,
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('My Orders')),
      body: Obx(() => ListView(padding: const EdgeInsets.all(16), children: [
        if (ctrl.activeOrders.isNotEmpty) ...[
          const Text('Active Orders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPrimaryBlue)),
          const SizedBox(height: 8),
          ...ctrl.activeOrders.map((o) => customerCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.local_laundry_service, color: Colors.purple, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ORD-${o['token'] ?? o['id'].toString().substring(0,6)}', style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryBlue)),
                Text(o['status'] ?? 'Active', style: const TextStyle(fontSize: 12, color: Colors.purple)),
              ])),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: () => Get.to(() => OrderTrackingScreen(orderData: o)),
                icon: const Icon(Icons.track_changes, size: 14), label: const Text('Track', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: kAccentBlue, minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 8)),
              )),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton.icon(
                onPressed: () => Get.to(() => DeliveryOTPScreen(orderData: o)),
                icon: const Icon(Icons.pin_outlined, size: 14), label: const Text('OTP', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: kOrange, minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 8)),
              )),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton.icon(
                onPressed: () => Get.to(() => InvoiceScreen(orderData: o)),
                icon: const Icon(Icons.receipt_outlined, size: 14), label: const Text('Invoice', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: kAccentGreen, minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 8)),
              )),
            ]),
          ]))),
          const SizedBox(height: 16),
        ],
        const Text('Order History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPrimaryBlue)),
        const SizedBox(height: 8),
        if (ctrl.pastOrders.isEmpty)
          const Text('No past orders found.', style: TextStyle(color: Colors.grey)),
        ...ctrl.pastOrders.map((o) => customerCard(child: Column(children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kAccentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.receipt_long_outlined, color: kAccentGreen, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o['id'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryBlue, fontSize: 14)),
              Text('${o['totalItems'] ?? 0} items', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${o['baseAmount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryBlue)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: kAccentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(o['status'] as String, style: const TextStyle(fontSize: 10, color: kAccentGreen, fontWeight: FontWeight.w600))),
            ]),
          ]),
        ]))),
      ])),
    );
  }
}

// ── WALLET TAB ─────────────────────────────────────────────────
class _CustWalletTab extends StatefulWidget {
  final VoidCallback onRefresh;
  const _CustWalletTab({required this.onRefresh});
  @override State<_CustWalletTab> createState() => _CustWalletTabState();
}
class _CustWalletTabState extends State<_CustWalletTab> {
  @override
  Widget build(BuildContext context) {
    final ctrl = CustomerController.instance;
    return Scaffold(
      backgroundColor: kLightBg,
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Wallet')),
      body: Obx(() => ListView(padding: const EdgeInsets.all(16), children: [
        Container(padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0D2B5E), kAccentBlue]), borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            const Text('Wallet Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            Text('₹${ctrl.walletBalance.value.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              ElevatedButton.icon(
                onPressed: () => Get.to(() => WalletRechargeScreen(onDone: () {})),
                icon: const Icon(Icons.add, size: 16), label: const Text('Recharge'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), foregroundColor: Colors.white),
              ),
              ElevatedButton.icon(
                onPressed: () => Get.to(() => OnlinePaymentScreen(onDone: () {})),
                icon: const Icon(Icons.payment, size: 16), label: const Text('Pay Online'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), foregroundColor: Colors.white),
              ),
            ]),
          ])),
        const SizedBox(height: 20),
        const Text('Transaction History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPrimaryBlue)),
        const SizedBox(height: 8),
        ...ctrl.walletHistory.map((tx) => customerCard(child: Row(children: [
          Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: tx['type'] == 'credit' ? kAccentGreen.withOpacity(0.1) : Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(tx['type'] == 'credit' ? Icons.arrow_downward : Icons.arrow_upward,
                  color: tx['type'] == 'credit' ? kAccentGreen : Colors.red, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((tx['description'] ?? tx['desc'] ?? 'Transaction') as String, style: const TextStyle(fontWeight: FontWeight.w600, color: kPrimaryBlue, fontSize: 14)),
            Text((tx['created_at'] ?? tx['date'] ?? '') as String, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ])),
          Text('${tx['type'] == 'credit' ? '+' : '-'}₹${((tx['amount'] ?? 0) as num).toDouble().toStringAsFixed(0)}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: tx['type'] == 'credit' ? kAccentGreen : Colors.red)),
        ]))),
      ])),
    );
  }
}

// ── PROFILE TAB ────────────────────────────────────────────────
class _CustProfileTab extends StatefulWidget {
  final VoidCallback onRefresh;
  const _CustProfileTab({required this.onRefresh});
  @override State<_CustProfileTab> createState() => _CustProfileTabState();
}
class _CustProfileTabState extends State<_CustProfileTab> {
  @override
  Widget build(BuildContext context) {
    final ctrl = CustomerController.instance;
    return Scaffold(
      backgroundColor: kLightBg,
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('My Profile')),
      body: Obx(() {
        final name = ctrl.session.value?.name ?? 'Guest';
        final email = ctrl.session.value?.email ?? '';
        return ListView(padding: const EdgeInsets.all(16), children: [
          customerCard(child: Row(children: [
            CircleAvatar(radius: 32, backgroundColor: kAccentBlue.withOpacity(0.15),
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kAccentBlue))),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: kPrimaryBlue)),
              Text(email, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ])),
          ])),
          _menuTile(Icons.location_on_outlined, 'Manage Addresses', kAccentBlue, () => Get.to(() => const AddressScreen())),
          _menuTile(Icons.subscriptions_outlined, 'Subscription Plan', kOrange, () => Get.to(() => const SubscriptionScreen())),
          _menuTile(Icons.support_agent_outlined, 'Complaint Ticket', Colors.red, () => Get.to(() => const ComplaintScreen())),
          _menuTile(Icons.chat_outlined, 'Help & Support', const Color(0xFF25D366), () => Get.to(() => const SupportScreen())),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => ctrl.logout(),
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            label: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ]);
      }),
    );
  }
  Widget _menuTile(IconData icon, String label, Color color, VoidCallback onTap) =>
      customerCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: GestureDetector(onTap: onTap, child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kPrimaryBlue))),
        Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
      ])));
}
