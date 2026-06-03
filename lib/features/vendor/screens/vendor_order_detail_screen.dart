import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/enums.dart';
import '../../../core/models/delivery_order.dart';
import '../../../services/api_service.dart';

class VendorOrderDetailScreen extends StatefulWidget {
  final DeliveryOrder order;
  const VendorOrderDetailScreen({super.key, required this.order});
  @override State<VendorOrderDetailScreen> createState() => _VendorOrderDetailScreenState();
}
class _VendorOrderDetailScreenState extends State<VendorOrderDetailScreen> {
  bool _loading = false;

  Future<void> _updateStatus(OrderStatus target) async {
    setState(() => _loading = true);
    try {
      await ApiService.instance.advanceVendorOrderStatusTo(widget.order.id, target);
      setState(() {
        widget.order.status = target;
      });
      Get.snackbar('Update', 'Status advanced to ${target.label}', snackPosition: SnackPosition.BOTTOM, backgroundColor: target.color, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', 'Failed to update status: $e', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Scaffold(
      appBar: AppBar(title: Text('Order ${o.id}'), backgroundColor: kOrange),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: LinearGradient(colors: [o.status.color.withOpacity(0.8), o.status.color]), borderRadius: BorderRadius.circular(18)), child: Row(children: [Icon(o.status.icon, color: Colors.white, size: 36), const SizedBox(width: 14), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Current Status', style: TextStyle(color: Colors.white70, fontSize: 12)), Text(o.status.label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))])])),
        const SizedBox(height: 16),
        _sec('Order Details', Icons.receipt_outlined, Column(children: [_row(Icons.person, 'Customer', o.customerName), _row(Icons.confirmation_number_outlined, 'Token', o.token), _row(Icons.checkroom_outlined, 'Items', '${o.totalItems} clothes'), _row(Icons.local_laundry_service_outlined, 'Service', o.service), _row(Icons.phone_outlined, 'Phone', o.customerPhone)])),
        const SizedBox(height: 20),
        
        if (o.status == OrderStatus.pickedUp) ...[
          _otpBox('Driver Dropoff OTP', o.vendorDropoffOtp, 'Share this with driver when they bring clothes to your shop.', Colors.purple),
        ],
        
        if (o.status == OrderStatus.inLaundry) ...[
          ElevatedButton.icon(onPressed: _loading ? null : () => _updateStatus(OrderStatus.readyForDelivery), icon: const Icon(Icons.inventory_2_outlined), label: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Mark Ready for Delivery'), style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: Colors.indigo)),
        ],

        if (o.status == OrderStatus.readyForDelivery) ...[
          _otpBox('Driver Dispatch OTP', o.vendorDispatchOtp, 'Share this with driver when they pick up processed clothes.', Colors.teal),
        ],

        if (o.status == OrderStatus.outForDelivery || o.status == OrderStatus.delivered)
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kAccentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.check_circle, color: kAccentGreen), const SizedBox(width: 8), Text(o.status == OrderStatus.delivered ? 'Order Delivered' : 'Dispatched for Delivery', style: const TextStyle(color: kAccentGreen, fontWeight: FontWeight.bold))])),
        const SizedBox(height: 16),
      ])),
    );
  }

  Widget _otpBox(String title, String otp, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color.withOpacity(0.05), border: Border.all(color: color.withOpacity(0.3)), borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.lock_outline, color: color),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          ]),
          const SizedBox(height: 10),
          Text(otp, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8, color: color)),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      )
    );
  }

  Widget _sec(String title, IconData icon, Widget child) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, size: 18, color: kOrange), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPrimaryBlue))]), const SizedBox(height: 12), const Divider(height: 1), const SizedBox(height: 12), child]));
  Widget _row(IconData icon, String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 8), SizedBox(width: 70, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))), Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kPrimaryBlue)))]));
}
