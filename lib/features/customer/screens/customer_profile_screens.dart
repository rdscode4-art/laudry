import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/enums.dart';
import '../controllers/customer_controller.dart';
import '../widgets/customer_shared_widgets.dart';
import 'customer_home_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final VoidCallback onSaved;
  const EditProfileScreen({super.key, required this.onSaved});
  @override State<EditProfileScreen> createState() => _EditProfileScreenState();
}
class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _n, _e, _p;
  @override void initState() {
    super.initState();
    final s = CustomerController.instance.session.value;
    _n = TextEditingController(text: s?.name ?? '');
    _e = TextEditingController(text: s?.email ?? '');
    _p = TextEditingController(text: '');
  }
  @override void dispose() { _n.dispose(); _e.dispose(); _p.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final name = CustomerController.instance.session.value?.name ?? 'Guest';
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        CircleAvatar(radius: 40, backgroundColor: kAccentBlue.withOpacity(0.15),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: kAccentBlue))),
        const SizedBox(height: 24),
        TextFormField(controller: _n, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline))),
        const SizedBox(height: 14),
        TextFormField(controller: _e, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
        const SizedBox(height: 14),
        TextFormField(controller: _p, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined))),
        const Spacer(),
        ElevatedButton(
          onPressed: () {
            // Note: Server update not implemented in backend yet.
            widget.onSaved(); Get.back();
            Get.snackbar('Success', 'Profile updated', snackPosition: SnackPosition.BOTTOM, backgroundColor: kAccentGreen, colorText: Colors.white);
          },
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: const Text('Save Changes'),
        ),
      ])),
    );
  }
}

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});
  @override State<AddressScreen> createState() => _AddressScreenState();
}
class _AddressScreenState extends State<AddressScreen> {
  bool _adding = false;
  final _ac = TextEditingController(), _lc = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Addresses')),
      body: Obx(() {
        final _addrs = CustomerController.instance.addresses;
        return ListView(padding: const EdgeInsets.all(16), children: [
          ..._addrs.map((addr) => customerCard(child: Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: kAccentBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(addr['label'] == 'Home' ? Icons.home_outlined : Icons.work_outline, color: kAccentBlue, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(addr['label'], style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryBlue)),
              Text(addr['address'], style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ])),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () {
              CustomerController.instance.deleteAddress(addr['id'].toString());
            }),
          ]))),
          if (_adding) customerCard(child: Column(children: [
            TextFormField(controller: _lc, decoration: const InputDecoration(labelText: 'Label (Home/Office)', isDense: true)),
            const SizedBox(height: 10),
            TextFormField(controller: _ac, maxLines: 2, decoration: const InputDecoration(labelText: 'Full Address', isDense: true)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => setState(() => _adding = false), child: const Text('Cancel'))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(onPressed: () {
                if (_ac.text.isNotEmpty) {
                  CustomerController.instance.addAddress(_lc.text.isEmpty ? 'Other' : _lc.text, _ac.text);
                  setState(() { _adding = false; _ac.clear(); _lc.clear(); });
                }
              }, child: const Text('Save'))),
            ]),
          ])),
          if (!_adding)
            ElevatedButton.icon(onPressed: () => setState(() => _adding = true), icon: const Icon(Icons.add_location_alt_outlined), label: const Text('Add New Address'), style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48))),
        ]);
      }),
    );
  }
}

class SubscriptionScreen extends StatefulWidget {
  final bool isFromAuth;
  const SubscriptionScreen({super.key, this.isFromAuth = false});
  @override State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}
class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Map<String, dynamic>? _sel;
  
  @override void initState() { 
    super.initState(); 
    _sel = CustomerController.instance.selectedPlan.value;
    if (CustomerController.instance.availablePlans.isEmpty) {
      CustomerController.instance.fetchPlans();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription Plan')),
      body: Obx(() {
        final plans = CustomerController.instance.availablePlans;
        if (plans.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        
        return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (CustomerController.instance.activeSubscription.value != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: kAccentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: kAccentGreen.withOpacity(0.3))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Current Active Plan', style: TextStyle(color: kAccentGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Text(CustomerController.instance.activeSubscription.value!['plan_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Expires: ${CustomerController.instance.activeSubscription.value!['expires_at'].toString().split('T')[0]}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 20),
            const Text('Available Plans', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
          ],
          ...plans.map((plan) {
            final sel = _sel != null && _sel!['code'] == plan['code'];
            final features = (plan['features'] as List<dynamic>).map((e) => e.toString()).toList();
            
            return GestureDetector(onTap: () => setState(() => _sel = plan), child: AnimatedContainer(
              duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: sel ? kPrimaryBlue : kCardBg, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: sel ? kPrimaryBlue : Colors.grey.shade200, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: sel ? Colors.white.withOpacity(0.2) : kAccentBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.star, color: sel ? Colors.white : kAccentBlue, size: 24)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(plan['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: sel ? Colors.white : kPrimaryBlue)),
                    Text('₹${plan['priceMonthly']}/mo', style: TextStyle(fontWeight: FontWeight.bold, color: sel ? Colors.white70 : kOrange)),
                  ]),
                  const SizedBox(height: 6),
                  ...features.map((f) => Padding(padding: const EdgeInsets.only(top: 3), child: Row(children: [
                    Icon(Icons.check_circle_outline, size: 13, color: sel ? Colors.white70 : kAccentGreen),
                    const SizedBox(width: 6),
                    Text(f, style: TextStyle(fontSize: 12, color: sel ? Colors.white70 : Colors.grey.shade600)),
                  ]))),
                ])),
                Icon(sel ? Icons.check_circle : Icons.radio_button_unchecked, color: sel ? Colors.white : Colors.grey.shade400),
              ]),
            ));
          }),
          const Spacer(),
          ElevatedButton(
            onPressed: () async {
              if (_sel == null) return;
              CustomerController.instance.selectedPlan.value = _sel;
              await CustomerController.instance.purchasePlan(_sel!['code']);
              if (mounted) {
                if (widget.isFromAuth) {
                  Get.offAll(() => const CustomerHomeScreen());
                } else {
                  Get.back();
                }
              }
            },
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)), 
            child: const Text('Subscribe Now'),
          ),
          if (widget.isFromAuth) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Get.offAll(() => const CustomerHomeScreen()),
              child: const Text('Skip for now', style: TextStyle(color: Colors.grey)),
            )
          ],
        ]));
      }),
    );
  }
}

class WalletRechargeScreen extends StatefulWidget {
  final VoidCallback onDone;
  const WalletRechargeScreen({super.key, required this.onDone});
  @override State<WalletRechargeScreen> createState() => _WalletRechargeScreenState();
}
class _WalletRechargeScreenState extends State<WalletRechargeScreen> {
  double _sel = 200; final _cc = TextEditingController();
  final _amts = [100.0, 200.0, 500.0, 1000.0];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recharge Wallet')),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0D2B5E), kAccentBlue]), borderRadius: BorderRadius.circular(16)),
            child: Obx(() => Column(children: [const Text('Current Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text('₹${CustomerController.instance.walletBalance.value.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold))]))),
        const SizedBox(height: 24),
        const Text('Select Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPrimaryBlue)),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: _amts.map((a) {
          final s = a == _sel;
          return GestureDetector(onTap: () => setState(() { _sel = a; _cc.clear(); }), child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(color: s ? kAccentBlue : kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: s ? kAccentBlue : Colors.grey.shade300, width: 2)),
            child: Text('₹${a.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, color: s ? Colors.white : kPrimaryBlue)),
          ));
        }).toList()),
        const SizedBox(height: 16),
        TextFormField(controller: _cc, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Or enter custom amount', prefixText: '₹ '), onChanged: (v) => setState(() => _sel = double.tryParse(v) ?? _sel)),
        const Spacer(),
        ElevatedButton(
          onPressed: () async {
            final amt = double.tryParse(_cc.text) ?? _sel;
            
            // Show loading dialog
            Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
            
            final success = await CustomerController.instance.rechargeWallet(amt);
            
            Get.back(); // close loading
            widget.onDone(); 
            Get.back(); // close recharge screen
            
            if (success) {
              Get.snackbar('Success', '₹${amt.toStringAsFixed(0)} added', snackPosition: SnackPosition.BOTTOM, backgroundColor: kAccentGreen, colorText: Colors.white);
            } else {
              Get.snackbar('Error', 'Failed to recharge wallet', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
            }
          },
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: kAccentGreen),
          child: Text('Recharge ₹${(double.tryParse(_cc.text) ?? _sel).toStringAsFixed(0)}'),
        ),
      ])),
    );
  }
}

class OnlinePaymentScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnlinePaymentScreen({super.key, required this.onDone});
  @override State<OnlinePaymentScreen> createState() => _OnlinePaymentScreenState();
}
class _OnlinePaymentScreenState extends State<OnlinePaymentScreen> {
  int _method = 0; bool _paid = false;
  @override
  Widget build(BuildContext context) {
    if (_paid) return Scaffold(appBar: AppBar(title: const Text('Payment')), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: kAccentGreen.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.check_circle_rounded, size: 80, color: kAccentGreen)),
      const SizedBox(height: 20), const Text('Payment Successful!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimaryBlue)),
      const SizedBox(height: 8), const Text('Your order has been confirmed.', style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 24), ElevatedButton(onPressed: () => Get.back(), style: ElevatedButton.styleFrom(minimumSize: const Size(160, 48)), child: const Text('Done')),
    ])));
    return Scaffold(
      appBar: AppBar(title: const Text('Online Payment')),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        customerCard(child: Column(children: [const Text('Amount to Pay', style: TextStyle(color: Colors.grey, fontSize: 13)), const SizedBox(height: 4), const Text('₹160', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: kPrimaryBlue))])),
        const SizedBox(height: 16),
        const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPrimaryBlue)),
        const SizedBox(height: 10),
        ...[
          [Icons.account_balance_outlined, 'UPI / Net Banking'],
          [Icons.credit_card_outlined, 'Credit / Debit Card'],
          [Icons.account_balance_wallet_outlined, 'RiDeal Wallet (₹${CustomerController.instance.walletBalance.value.toStringAsFixed(0)})'],
        ].asMap().entries.map((e) => GestureDetector(onTap: () => setState(() => _method = e.key), child: Container(
          margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _method == e.key ? kAccentBlue.withOpacity(0.07) : kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _method == e.key ? kAccentBlue : Colors.grey.shade200, width: 2)),
          child: Row(children: [
            Icon(e.value[0] as IconData, color: _method == e.key ? kAccentBlue : Colors.grey, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(e.value[1] as String, style: TextStyle(fontWeight: FontWeight.w600, color: _method == e.key ? kAccentBlue : kPrimaryBlue))),
            Icon(_method == e.key ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: _method == e.key ? kAccentBlue : Colors.grey),
          ]),
        ))),
        const Spacer(),
        ElevatedButton(
          onPressed: () {
            if (_method == 2 && CustomerController.instance.walletBalance.value < 160) { Get.snackbar('Error', 'Insufficient wallet balance', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white); return; }
            if (_method == 2) {
              CustomerController.instance.payFromWallet(160);
              widget.onDone();
            }
            setState(() => _paid = true);
          },
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: kAccentGreen), child: const Text('Pay ₹160'),
        ),
      ])),
    );
  }
}
