import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/enums.dart';
import '../../../core/models/delivery_order.dart';
import '../screens/delivery_order_detail_screen.dart';

class DeliveryOrderCard extends StatelessWidget {
  final DeliveryOrder order; final VoidCallback onUpdated;
  const DeliveryOrderCard({super.key, required this.order, required this.onUpdated});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async { await Get.to(() => DeliveryOrderDetailScreen(order: order)); onUpdated(); },
      child: Container(margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: order.status.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(order.status.icon, color: order.status.color, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPrimaryBlue)), Text(order.id, style: TextStyle(fontSize: 12, color: Colors.grey.shade500))])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: order.status.color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Text(order.status.label, style: TextStyle(fontSize: 11, color: order.status.color, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 10), const Divider(height: 1), const SizedBox(height: 10),
        Row(children: [const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey), const SizedBox(width: 4), Expanded(child: Text(order.customerAddress, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis))]),
        const SizedBox(height: 6),
        Row(children: [_chip(Icons.checkroom_outlined, '${order.totalItems} items', kAccentBlue), const SizedBox(width: 8), _chip(Icons.local_laundry_service_outlined, order.service, kAccentGreen), const SizedBox(width: 8), _chip(Icons.confirmation_number_outlined, 'Token: ${order.token}', kOrange)]),
      ])),
    );
  }
  Widget _chip(IconData icon, String label, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: color), const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500))]));
}
