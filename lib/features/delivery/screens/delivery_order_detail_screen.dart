import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/enums.dart';
import '../../../core/models/delivery_order.dart';

class DeliveryOrderDetailScreen extends StatefulWidget {
  final DeliveryOrder order;
  const DeliveryOrderDetailScreen({super.key, required this.order});
  @override State<DeliveryOrderDetailScreen> createState() => _DeliveryOrderDetailScreenState();
}
class _DeliveryOrderDetailScreenState extends State<DeliveryOrderDetailScreen> {
  final _pickupCtrl = TextEditingController(), _deliveryCtrl = TextEditingController();
  @override void dispose() { _pickupCtrl.dispose(); _deliveryCtrl.dispose(); super.dispose(); }

  void _verifyPickup() {
    if (_pickupCtrl.text.trim() != widget.order.pickupOtp) { Get.snackbar('Error', '❌ Wrong Pickup OTP', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white); return; }
    setState(() => widget.order.status = OrderStatus.pickedUp); _pickupCtrl.clear();
    Get.snackbar('Success', '✅ Pickup verified!', snackPosition: SnackPosition.BOTTOM, backgroundColor: kAccentGreen, colorText: Colors.white);
  }
  void _verifyDelivery() {
    if (_deliveryCtrl.text.trim() != widget.order.deliveryOtp) { Get.snackbar('Error', '❌ Wrong Delivery OTP', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white); return; }
    setState(() => widget.order.status = OrderStatus.delivered); _deliveryCtrl.clear();
    Get.snackbar('Success', '✅ Delivered!', snackPosition: SnackPosition.BOTTOM, backgroundColor: kAccentGreen, colorText: Colors.white);
  }
  void _next(OrderStatus s) { setState(() => widget.order.status = s); Get.snackbar('Update', 'Status: ${s.label}', snackPosition: SnackPosition.BOTTOM, backgroundColor: s.color, colorText: Colors.white); }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Scaffold(
      appBar: AppBar(title: Text('Order ${o.id}')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: LinearGradient(colors: [o.status.color.withOpacity(0.8), o.status.color]), borderRadius: BorderRadius.circular(18)), child: Row(children: [Icon(o.status.icon, color: Colors.white, size: 36), const SizedBox(width: 14), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Current Status', style: TextStyle(color: Colors.white70, fontSize: 12)), Text(o.status.label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))])])),
        const SizedBox(height: 16),
        _sec('Customer Details', Icons.person_outline, Column(children: [_row(Icons.person, 'Name', o.customerName), _row(Icons.location_on_outlined, 'Address', o.customerAddress), _row(Icons.phone_outlined, 'Phone', o.customerPhone), _row(Icons.checkroom_outlined, 'Items', '${o.totalItems} clothes'), _row(Icons.local_laundry_service_outlined, 'Service', o.service)])),
        const SizedBox(height: 14),
        _sec('Booking Token', Icons.confirmation_number_outlined, _row(Icons.confirmation_number_outlined, 'Token', o.token)),
        const SizedBox(height: 14),
        if (o.status == OrderStatus.pending) _sec('Verify Pickup OTP', Icons.lock_outline, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text('Ask customer for Pickup OTP and enter below.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 12), TextField(controller: _pickupCtrl, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'Enter Pickup OTP', hintText: 'e.g. 1234', prefixIcon: Icon(Icons.pin_outlined), counterText: '')), const SizedBox(height: 12), ElevatedButton.icon(onPressed: _verifyPickup, icon: const Icon(Icons.check_circle_outline), label: const Text('Verify & Pickup'), style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: kAccentBlue))])),
        if (o.status == OrderStatus.pickedUp) ...[const SizedBox(height: 14), ElevatedButton.icon(onPressed: () => _next(OrderStatus.inLaundry), icon: const Icon(Icons.local_laundry_service), label: const Text('Mark as In Laundry'), style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: Colors.purple))],
        if (o.status == OrderStatus.inLaundry) ...[const SizedBox(height: 14), ElevatedButton.icon(onPressed: () => _next(OrderStatus.outForDelivery), icon: const Icon(Icons.delivery_dining), label: const Text('Out for Delivery'), style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: Colors.teal))],
        if (o.status == OrderStatus.outForDelivery) ...[const SizedBox(height: 14), _sec('Verify Delivery OTP', Icons.lock_outline, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text('Ask customer for Delivery OTP and enter below.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 12), TextField(controller: _deliveryCtrl, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'Enter Delivery OTP', hintText: 'e.g. 1234', prefixIcon: Icon(Icons.pin_outlined), counterText: '')), const SizedBox(height: 12), ElevatedButton.icon(onPressed: _verifyDelivery, icon: const Icon(Icons.check_circle_outline), label: const Text('Verify & Complete Delivery'), style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: kAccentGreen))]))],
        if (o.status == OrderStatus.delivered) ...[const SizedBox(height: 14), Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kAccentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle, color: kAccentGreen), SizedBox(width: 8), Text('Order Delivered Successfully', style: TextStyle(color: kAccentGreen, fontWeight: FontWeight.bold))]))],
        const SizedBox(height: 16),
      ])),
    );
  }
  Widget _sec(String title, IconData icon, Widget child) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, size: 18, color: kAccentGreen), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPrimaryBlue))]), const SizedBox(height: 12), const Divider(height: 1), const SizedBox(height: 12), child]));
  Widget _row(IconData icon, String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 8), SizedBox(width: 70, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))), Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kPrimaryBlue)))]));
}
