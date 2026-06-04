import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/enums.dart';
import '../../../core/models/delivery_order.dart';
import '../../../services/api_service.dart';

class DeliveryOrderDetailScreen extends StatefulWidget {
  final DeliveryOrder order;
  const DeliveryOrderDetailScreen({super.key, required this.order});
  @override State<DeliveryOrderDetailScreen> createState() => _DeliveryOrderDetailScreenState();
}
class _DeliveryOrderDetailScreenState extends State<DeliveryOrderDetailScreen> {
  final _pickupCtrl = TextEditingController();
  final _vendorDropoffCtrl = TextEditingController();
  final _vendorDispatchCtrl = TextEditingController();
  final _deliveryCtrl = TextEditingController();

  bool _loading = false;

  @override void dispose() { 
    _pickupCtrl.dispose(); 
    _vendorDropoffCtrl.dispose(); 
    _vendorDispatchCtrl.dispose(); 
    _deliveryCtrl.dispose(); 
    super.dispose(); 
  }

  Future<void> _verifyPickup() async {
    if (_pickupCtrl.text.trim().isEmpty) { Get.snackbar('Error', 'Please enter OTP', backgroundColor: Colors.red, colorText: Colors.white); return; }
    setState(() => _loading = true);
    try {
      await ApiService.instance.verifyPickupOtp(widget.order.id, _pickupCtrl.text.trim());
      setState(() => widget.order.status = OrderStatus.pickedUp);
      _pickupCtrl.clear();
      Get.snackbar('Success', '✅ Pickup verified!', backgroundColor: kAccentGreen, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', '❌ ${e.toString()}', backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyVendorDropoff() async {
    if (_vendorDropoffCtrl.text.trim().isEmpty) { Get.snackbar('Error', 'Please enter OTP', backgroundColor: Colors.red, colorText: Colors.white); return; }
    setState(() => _loading = true);
    try {
      await ApiService.instance.verifyVendorDropoffOtp(widget.order.id, _vendorDropoffCtrl.text.trim());
      setState(() => widget.order.status = OrderStatus.inLaundry);
      _vendorDropoffCtrl.clear();
      Get.snackbar('Success', '✅ Dropped at Vendor!', backgroundColor: kAccentGreen, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', '❌ ${e.toString()}', backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyVendorDispatch() async {
    if (_vendorDispatchCtrl.text.trim().isEmpty) { Get.snackbar('Error', 'Please enter OTP', backgroundColor: Colors.red, colorText: Colors.white); return; }
    setState(() => _loading = true);
    try {
      await ApiService.instance.verifyVendorDispatchOtp(widget.order.id, _vendorDispatchCtrl.text.trim());
      setState(() => widget.order.status = OrderStatus.outForDelivery);
      _vendorDispatchCtrl.clear();
      Get.snackbar('Success', '✅ Picked up from Vendor!', backgroundColor: kAccentGreen, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', '❌ ${e.toString()}', backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyDelivery() async {
    if (_deliveryCtrl.text.trim().isEmpty) { Get.snackbar('Error', 'Please enter OTP', backgroundColor: Colors.red, colorText: Colors.white); return; }
    setState(() => _loading = true);
    try {
      await ApiService.instance.completeRide(widget.order.id, _deliveryCtrl.text.trim());
      setState(() => widget.order.status = OrderStatus.delivered);
      _deliveryCtrl.clear();
      Get.snackbar('Success', '✅ Delivered to Customer!', backgroundColor: kAccentGreen, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', '❌ ${e.toString()}', backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _openMap(double? lat, double? lng) async {
    if (lat == null || lng == null) {
      Get.snackbar('Error', 'Location not available for this address.', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar('Error', 'Could not open map', backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Scaffold(
      appBar: AppBar(title: Text('Order ${o.id}')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: LinearGradient(colors: [o.status.color.withOpacity(0.8), o.status.color]), borderRadius: BorderRadius.circular(18)), child: Row(children: [Icon(o.status.icon, color: Colors.white, size: 36), const SizedBox(width: 14), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Current Status', style: TextStyle(color: Colors.white70, fontSize: 12)), Text(o.status.label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))])])),
        if (o.status == OrderStatus.pending || o.status == OrderStatus.outForDelivery) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _openMap(o.customerLatitude, o.customerLongitude),
            icon: const Icon(Icons.navigation_outlined),
            label: const Text('Navigate to Customer'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: Colors.blueAccent),
          )
        ],
        if (o.status == OrderStatus.pickedUp || o.status == OrderStatus.readyForDelivery) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _openMap(o.vendorLatitude, o.vendorLongitude),
            icon: const Icon(Icons.store_mall_directory_outlined),
            label: const Text('Navigate to Vendor'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: Colors.orange),
          )
        ],
        const SizedBox(height: 16),
        _sec('Customer Details', Icons.person_outline, Column(children: [_row(Icons.person, 'Name', o.customerName), _row(Icons.location_on_outlined, 'Address', o.customerAddress), _row(Icons.phone_outlined, 'Phone', o.customerPhone), _row(Icons.checkroom_outlined, 'Items', '${o.totalItems} clothes'), _row(Icons.local_laundry_service_outlined, 'Service', o.service)])),
        const SizedBox(height: 14),
        _sec('Booking Token', Icons.confirmation_number_outlined, _row(Icons.confirmation_number_outlined, 'Token', o.token)),
        const SizedBox(height: 14),
        
        // Phase 1: Pickup from Customer
        if (o.status == OrderStatus.pending) 
          _sec('Verify Pickup OTP', Icons.lock_outline, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text('Ask customer for Pickup OTP and enter below.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 12), TextField(controller: _pickupCtrl, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'Enter Pickup OTP', hintText: 'e.g. 1234', prefixIcon: Icon(Icons.pin_outlined), counterText: '')), const SizedBox(height: 12), ElevatedButton.icon(onPressed: _loading ? null : _verifyPickup, icon: const Icon(Icons.check_circle_outline), label: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Verify & Pickup'), style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: kAccentBlue))])),
        
        // Phase 1: Dropoff to Vendor
        if (o.status == OrderStatus.pickedUp) 
          _sec('Verify Vendor Dropoff OTP', Icons.lock_outline, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text('Ask vendor for Dropoff OTP and enter below.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 12), TextField(controller: _vendorDropoffCtrl, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'Enter Dropoff OTP', hintText: 'e.g. 1234', prefixIcon: Icon(Icons.pin_outlined), counterText: '')), const SizedBox(height: 12), ElevatedButton.icon(onPressed: _loading ? null : _verifyVendorDropoff, icon: const Icon(Icons.check_circle_outline), label: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Verify & Dropoff'), style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: Colors.purple))])),
        
        // Vendor Processing Wait
        if (o.status == OrderStatus.inLaundry) 
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.hourglass_top, color: Colors.purple), SizedBox(width: 8), Expanded(child: Text('Order is being processed by the vendor. Waiting for it to be ready.', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)))])),
        
        // Phase 2: Pickup from Vendor
        if (o.status == OrderStatus.readyForDelivery)
          _sec('Verify Vendor Dispatch OTP', Icons.lock_outline, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text('Ask vendor for Dispatch OTP and enter below.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 12), TextField(controller: _vendorDispatchCtrl, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'Enter Dispatch OTP', hintText: 'e.g. 1234', prefixIcon: Icon(Icons.pin_outlined), counterText: '')), const SizedBox(height: 12), ElevatedButton.icon(onPressed: _loading ? null : _verifyVendorDispatch, icon: const Icon(Icons.check_circle_outline), label: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Verify & Dispatch'), style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: Colors.teal))])),

        // Phase 2: Delivery to Customer
        if (o.status == OrderStatus.outForDelivery)
          _sec('Verify Customer Delivery OTP', Icons.lock_outline, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text('Ask customer for Delivery OTP and enter below.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 12), TextField(controller: _deliveryCtrl, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'Enter Delivery OTP', hintText: 'e.g. 1234', prefixIcon: Icon(Icons.pin_outlined), counterText: '')), const SizedBox(height: 12), ElevatedButton.icon(onPressed: _loading ? null : _verifyDelivery, icon: const Icon(Icons.check_circle_outline), label: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Verify & Complete Delivery'), style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: kAccentGreen))])),
        
        if (o.status == OrderStatus.delivered) ...[const SizedBox(height: 14), Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kAccentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle, color: kAccentGreen), SizedBox(width: 8), Text('Order Delivered Successfully', style: TextStyle(color: kAccentGreen, fontWeight: FontWeight.bold))]))],
        const SizedBox(height: 16),
      ])),
    );
  }
  Widget _sec(String title, IconData icon, Widget child) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, size: 18, color: kAccentGreen), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPrimaryBlue))]), const SizedBox(height: 12), const Divider(height: 1), const SizedBox(height: 12), child]));
  Widget _row(IconData icon, String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 8), SizedBox(width: 70, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))), Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kPrimaryBlue)))]));
}
