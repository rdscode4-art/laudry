import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/enums.dart';
import '../../../services/api_service.dart';
import '../controllers/customer_controller.dart';
import '../widgets/customer_shared_widgets.dart';

class OrderTrackingScreen extends StatelessWidget {
  final Map<String, dynamic>? orderData;
  const OrderTrackingScreen({super.key, this.orderData});
  @override
  Widget build(BuildContext context) {
    final String status = orderData?['status'] ?? 'pending';
    final String tracking = orderData?['tracking_status'] ?? 'order_placed';
    
    // For a real app, map backend status to steps.
    final bool isCancelled = status == 'cancelled';
    final bool isDelivered = status == 'delivered';
    final bool isCancellable = (status == 'pending' || status == 'received') && tracking == 'order_placed';

    final steps = [
      {'label': 'Order Placed',     'sub': 'Your order has been confirmed',       'done': true,  'icon': Icons.check_circle_outline},
      {'label': 'Picked Up',        'sub': 'Clothes picked up from your address', 'done': status != 'pending' && status != 'received',  'icon': Icons.shopping_bag_outlined},
      {'label': 'In Laundry',       'sub': 'Being washed at Quick Clean',         'done': ['washing', 'drying', 'readyForDelivery', 'handedToDelivery', 'delivered'].contains(status),  'icon': Icons.local_laundry_service},
      {'label': 'Out for Delivery', 'sub': 'On the way to your address',          'done': ['handedToDelivery', 'delivered'].contains(status), 'icon': Icons.delivery_dining},
      {'label': 'Delivered',        'sub': 'Clothes delivered fresh & clean',     'done': isDelivered, 'icon': Icons.home_outlined},
    ];

    if (isCancelled) {
      steps.clear();
      steps.add({'label': 'Cancelled', 'sub': 'This order was cancelled.', 'done': true, 'icon': Icons.cancel});
    }

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
        if (isCancellable) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _handleCancel(context, orderData?['id']),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel Order'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, minimumSize: const Size.fromHeight(50)),
          ),
        ],
        if (isDelivered) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showRatingBottomSheet(context, orderData?['id']),
            icon: const Icon(Icons.star_outline),
            label: const Text('Rate Experience'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade600, minimumSize: const Size.fromHeight(50)),
          ),
        ]
      ])),
    );
  }

  void _handleCancel(BuildContext context, String? orderId) {
    if (orderId == null) return;
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('Cancel Order?'),
      content: const Text('Are you sure you want to cancel this order? Any paid amount will be refunded to your wallet.'),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('No')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            Get.back();
            try {
              await ApiService.cancelOrder(orderId);
              Get.snackbar('Success', 'Order cancelled successfully', backgroundColor: Colors.green, colorText: Colors.white);
              CustomerController.instance.fetchOrders();
              Get.back(); // close tracking screen
            } catch (e) {
              Get.snackbar('Error', e.toString(), backgroundColor: Colors.red, colorText: Colors.white);
            }
          },
          child: const Text('Yes, Cancel'),
        ),
      ],
    ));
  }

  void _showRatingBottomSheet(BuildContext context, String? orderId) {
    if (orderId == null) return;
    int rating = 5;
    final txt = TextEditingController();
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Rate your experience', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) => IconButton(
                    icon: Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 40),
                    onPressed: () => setState(() => rating = i + 1),
                  )),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: txt,
                  decoration: InputDecoration(
                    hintText: 'Leave a review (optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await ApiService.rateOrder(orderId, rating, txt.text);
                      Get.back();
                      Get.snackbar('Success', 'Thank you for your rating!', backgroundColor: Colors.green, colorText: Colors.white);
                    } catch (e) {
                      Get.snackbar('Error', e.toString(), backgroundColor: Colors.red, colorText: Colors.white);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kAccentBlue, minimumSize: const Size.fromHeight(50)),
                  child: const Text('Submit'),
                ),
              ],
            );
          }
        )
      )
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
    final rawItemsJson = orderData?['items_json'] ?? orderData?['items'] ?? '{}';
    Map<String, dynamic> parsedItems = {};
    if (rawItemsJson is String) {
      try { parsedItems = jsonDecode(rawItemsJson); } catch (_) {}
    } else if (rawItemsJson is Map) {
      parsedItems = Map<String, dynamic>.from(rawItemsJson);
    }
    
    if (parsedItems.isEmpty) {
      parsedItems = {'Shirt': 3, 'Pant': 2, 'Shorts': 3}; // fallback mock if empty
    }
    
    final dynItems = CustomerController.instance.dynamicItems;
    
    double sub = 0.0;
    final itemRows = parsedItems.entries.map((e) {
      final name = e.key;
      final quantity = (e.value as num).toInt();
      final match = dynItems.firstWhere((element) => element['name'] == name, orElse: () => {'price': 20.0});
      final price = (match['price'] as num).toDouble();
      final imageUrl = match['image_url'] as String?;
      final lineTotal = quantity * price;
      sub += lineTotal;
      return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
        if (imageUrl != null && imageUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              '${ApiService.baseUrl}$imageUrl',
              width: 16, height: 16, fit: BoxFit.cover,
              errorBuilder: (c, e, s) => const Icon(Icons.checkroom_outlined, size: 14, color: Colors.grey),
            )
          )
        else
          const Icon(Icons.checkroom_outlined, size: 14, color: Colors.grey), 
        const SizedBox(width: 8),
        Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
        Text('$quantity × ₹${price.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(width: 12),
        Text('₹${lineTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, color: kPrimaryBlue)),
      ]));
    }).toList();

    final tax = sub * (CustomerController.instance.taxPercentage.value / 100);
    final delivery = CustomerController.instance.deliveryCharge.value;
    final total = sub + tax + delivery;
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
        ...itemRows,
        const Divider(height: 20),
        _billRow('Subtotal', '₹${sub.toStringAsFixed(0)}'),
        _billRow('Tax (${CustomerController.instance.taxPercentage.value}%)', '₹${tax.toStringAsFixed(0)}'),
        if (delivery > 0) _billRow('Delivery Charge', '₹${delivery.toStringAsFixed(0)}'),
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
