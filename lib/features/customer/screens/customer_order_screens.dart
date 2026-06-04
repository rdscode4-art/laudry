import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/enums.dart';
import '../controllers/customer_controller.dart';
import '../widgets/customer_shared_widgets.dart';

class OrderTrackingScreen extends StatelessWidget {
  final Map<String, dynamic>? orderData;
  const OrderTrackingScreen({super.key, this.orderData});
  @override
  Widget build(BuildContext context) {
    final steps = [
      {'label': 'Order Placed',     'sub': 'Your order has been confirmed',       'done': true,  'icon': Icons.check_circle_outline},
      {'label': 'Picked Up',        'sub': 'Clothes picked up from your address', 'done': true,  'icon': Icons.shopping_bag_outlined},
      {'label': 'In Laundry',       'sub': 'Being washed at Quick Clean',         'done': true,  'icon': Icons.local_laundry_service},
      {'label': 'Out for Delivery', 'sub': 'On the way to your address',          'done': false, 'icon': Icons.delivery_dining},
      {'label': 'Delivered',        'sub': 'Clothes delivered fresh & clean',     'done': false, 'icon': Icons.home_outlined},
    ];
    return Scaffold(
      appBar: AppBar(title: Text('Track ${orderData?['token'] ?? orderData?['id'] ?? "Order"}')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        customerCard(child: Column(children: [
          customerInfoRow(Icons.confirmation_number_outlined, 'Token', orderData?['token']?.toString() ?? '4821'),
          customerInfoRow(Icons.store_outlined, 'Laundry', 'Quick Clean Laundry'),
          customerInfoRow(Icons.local_laundry_service_outlined, 'Service', orderData?['service'] ?? 'Laundry'),
          customerInfoRow(Icons.checkroom_outlined, 'Items', '${orderData?['total_items'] ?? 8} clothes'),
        ])),
        customerCard(child: Column(children: steps.asMap().entries.map((e) {
          final step = e.value; final done = step['done'] as bool;
          final current = !done && (e.key == 0 || (steps[e.key - 1]['done'] as bool));
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle, color: done ? kAccentGreen : (current ? kAccentBlue : Colors.grey.shade200)),
                  child: Icon(done ? Icons.check : step['icon'] as IconData, size: 16, color: done || current ? Colors.white : Colors.grey)),
              if (e.key < steps.length - 1) Container(width: 2, height: 36, color: done ? kAccentGreen : Colors.grey.shade200),
            ]),
            const SizedBox(width: 14),
            Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(step['label'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: done ? kAccentGreen : (current ? kAccentBlue : Colors.grey))),
                if (current) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: kAccentBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Now', style: TextStyle(fontSize: 10, color: kAccentBlue, fontWeight: FontWeight.bold)))],
              ]),
              Text(step['sub'] as String, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ]))),
          ]);
        }).toList())),
      ])),
    );
  }
}

class DeliveryOTPScreen extends StatelessWidget {
  final Map<String, dynamic>? orderData;
  const DeliveryOTPScreen({super.key, this.orderData});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery OTP')),
      body: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: const LinearGradient(colors: [kAccentGreen, Color(0xFF2E7D32)]), borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 48),
              const SizedBox(height: 12),
              const Text('Your clothes are on the way!', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text('Pickup OTP', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(orderData?['pickupOtp']?.toString() ?? '1234', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: 8)),
              const SizedBox(height: 16),
              const Text('Delivery OTP', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(orderData?['deliveryOtp']?.toString() ?? '5678', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: 8)),
            ])),
        const SizedBox(height: 20),
        customerCard(child: Column(children: [
          customerInfoRow(Icons.confirmation_number_outlined, 'Token', orderData?['token']?.toString() ?? '4821'),
          customerInfoRow(Icons.checkroom_outlined, 'Items', '${orderData?['totalItems'] ?? orderData?['total_items'] ?? 8} clothes'),
          customerInfoRow(Icons.local_laundry_service_outlined, 'Service', orderData?['service'] ?? 'Laundry'),
        ])),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: orderData?['deliveryOtp']?.toString() ?? '5678'));
            Get.snackbar('Copied', 'OTP copied!', snackPosition: SnackPosition.BOTTOM, backgroundColor: kAccentGreen, colorText: Colors.white);
          },
          icon: const Icon(Icons.copy), label: const Text('Copy Delivery OTP'),
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: kAccentGreen),
        ),
      ])),
    );
  }
}

class InvoiceScreen extends StatelessWidget {
  final Map<String, dynamic>? orderData;
  const InvoiceScreen({super.key, this.orderData});
  @override
  Widget build(BuildContext context) {
    // For now, mock items if not provided or empty
    final disp = [const MapEntry('Shirt', 3), const MapEntry('Pant', 2), const MapEntry('Shorts', 3)];
    const price = 20.0;
    final sub = disp.fold(0.0, (s, e) => s + e.value * price);
    final tax = sub * 0.05; final total = sub + tax;
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice'), actions: [IconButton(icon: const Icon(Icons.share_outlined), onPressed: () => Get.snackbar('Shared', 'Invoice shared', snackPosition: SnackPosition.BOTTOM, backgroundColor: kAccentBlue, colorText: Colors.white))]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: customerCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('RiDeal Laundry India', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kPrimaryBlue)),
            Text('Clean Care. Fast Service.', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: kAccentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Text('PAID', style: TextStyle(color: kAccentGreen, fontWeight: FontWeight.bold, fontSize: 13))),
        ]),
        const Divider(height: 24),
        customerInfoRow(Icons.confirmation_number_outlined, 'Invoice #', 'INV-${orderData?['token'] ?? '4821'}'),
        customerInfoRow(Icons.person_outline, 'Customer', CustomerController.instance.session.value?.name ?? 'Customer'),
        customerInfoRow(Icons.calendar_today_outlined, 'Date', orderData?['created_at']?.toString().split('T')[0] ?? 'Today'),
        customerInfoRow(Icons.store_outlined, 'Laundry', 'Quick Clean Laundry'),
        customerInfoRow(Icons.local_laundry_service_outlined, 'Service', orderData?['service'] ?? 'Laundry'),
        const Divider(height: 24),
        const Text('Items', style: TextStyle(fontWeight: FontWeight.bold, color: kPrimaryBlue)),
        const SizedBox(height: 10),
        ...disp.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
          const Icon(Icons.checkroom_outlined, size: 14, color: Colors.grey), const SizedBox(width: 8),
          Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
          Text('${e.value} × ₹${price.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(width: 12),
          Text('₹${(e.value * price).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, color: kPrimaryBlue)),
        ]))),
        const Divider(height: 20),
        _billRow('Subtotal', '₹${sub.toStringAsFixed(0)}'),
        _billRow('GST (5%)', '₹${tax.toStringAsFixed(0)}'),
        const Divider(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kPrimaryBlue)),
          Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kAccentGreen)),
        ]),
      ]))),
    );
  }
  Widget _billRow(String l, String v) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(l, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)), Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kPrimaryBlue)),
  ]));
}
