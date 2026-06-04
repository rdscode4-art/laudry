import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/enums.dart';
import '../../../core/models/laundry_order.dart';
import '../../../services/api_service.dart';
import '../controllers/customer_controller.dart';
import 'customer_home_screen.dart';
import 'map_location_picker.dart';

// ── PLAN SELECTION ──────────────────────────────────────────────
class PlanSelectionScreen extends StatefulWidget {
  const PlanSelectionScreen({super.key});
  @override State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}
class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  Map<String, dynamic>? _sel;

  @override
  void initState() {
    super.initState();
    if (CustomerController.instance.availablePlans.isEmpty) {
      CustomerController.instance.fetchPlans();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Plan')),
      body: Obx(() {
        final plans = CustomerController.instance.availablePlans;
        if (plans.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        
        return Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Select a plan that suits you', style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 20),
          ...plans.map((plan) {
            final sel = _sel != null && _sel!['code'] == plan['code'];
            return GestureDetector(onTap: () => setState(() => _sel = plan), child: AnimatedContainer(
              duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: sel ? kPrimaryBlue : kCardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: sel ? kPrimaryBlue : Colors.grey.shade200, width: 2), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: sel ? Colors.white.withValues(alpha: 0.2) : kAccentBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.star, color: sel ? Colors.white : kAccentBlue, size: 26)),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(plan['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: sel ? Colors.white : kPrimaryBlue)),
                  const SizedBox(height: 4),
                  Text(plan['description'], style: TextStyle(fontSize: 12, color: sel ? Colors.white70 : Colors.grey.shade600)),
                ])),
                Icon(sel ? Icons.check_circle : Icons.radio_button_unchecked, color: sel ? Colors.white : Colors.grey.shade400),
              ]),
            ));
          }),
          const Spacer(),
          ElevatedButton(
            onPressed: () async {
              if (_sel == null) { Get.snackbar('Info', 'Select a plan to subscribe', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.orange, colorText: Colors.white); return; }
              Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
              CustomerController.instance.selectedPlan.value = _sel;
              await CustomerController.instance.purchasePlan(_sel!['code']);
              if (mounted) {
                Get.back();
                Get.off(() => const CustomerHomeScreen());
              }
            },
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Subscribe & Continue'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Get.off(() => const CustomerHomeScreen()),
          child: const Text('Skip for now', style: TextStyle(color: Colors.grey)),
        )
      ]));
      }),
    );
  }
}

// ── BOOK SCREEN ────────────────────────────────────────────────
class BookScreen extends StatefulWidget {
  const BookScreen({super.key});
  @override State<BookScreen> createState() => _BookScreenState();
}
class _BookScreenState extends State<BookScreen> {
  final _picker = ImagePicker();
  final _slots = ['8:00 AM – 10:00 AM', '10:00 AM – 12:00 PM', '12:00 PM – 2:00 PM', '2:00 PM – 4:00 PM', '4:00 PM – 6:00 PM', '6:00 PM – 8:00 PM'];
  String _pickupSlot = '';
  List<XFile> _uploadImages = [];
  bool _isBooking = false;

  void _change(String k, int d) => CustomerController.instance.cartItems[k]?.value = max(0, (CustomerController.instance.cartItems[k]?.value ?? 0) + d);
  Future<void> _pick() async { final imgs = await _picker.pickMultiImage(imageQuality: 70); if (imgs.isNotEmpty) setState(() => _uploadImages.addAll(imgs)); }

  Future<void> _submit() async {
    final ctrl = CustomerController.instance;
    if (ctrl.totalCartItems == 0) { Get.snackbar('Info', 'Select at least one item.', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.orange, colorText: Colors.white); return; }
    if (_pickupSlot.isEmpty) { Get.snackbar('Info', 'Please select a pickup time slot.', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.orange, colorText: Colors.white); return; }
    if (ctrl.currentLatitude.value == 0.0) { Get.snackbar('Location Required', 'Please fetch your current location for pickup.', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent, colorText: Colors.white); return; }

    setState(() => _isBooking = true);
    try {
      final addressToUse = ctrl.addresses.isNotEmpty ? ctrl.addresses.first['address'] as String : 'No saved address';
      final success = await ctrl.createOrder(addressToUse);
      if (!mounted) return;
      if (success) {
        Get.dialog(
          Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: kAccentGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle, color: kAccentGreen, size: 60),
                  ),
                  const SizedBox(height: 20),
                  const Text('Booking Confirmed!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimaryBlue)),
                  const SizedBox(height: 10),
                  const Text('Your laundry pickup has been successfully scheduled. Our delivery partner will arrive at the selected time slot.', 
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 14)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Get.back(); // close dialog
                      Get.back(); // close book screen
                    },
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: kAccentGreen),
                    child: const Text('Back to Home'),
                  )
                ],
              ),
            ),
          ),
          barrierDismissible: false,
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to book pickup: $e', backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = CustomerController.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Book Pickup')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: kAccentBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Obx(() => Row(children: [
              Icon(Icons.category, color: kAccentBlue, size: 18),
              const SizedBox(width: 8),
              Text('Service: ${ctrl.selectedService.value}', style: const TextStyle(fontWeight: FontWeight.w600, color: kAccentBlue)),
            ]))),
        const SizedBox(height: 20),
        const Text('Select Clothes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kPrimaryBlue)),
        const SizedBox(height: 10),
        Obx(() {
          if (ctrl.dynamicItems.isEmpty) {
            return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
          }
          final filteredItems = ctrl.dynamicItems.where((i) => i['service'] == ctrl.selectedService.value).toList();
          if (filteredItems.isEmpty) {
            return const Padding(padding: EdgeInsets.all(20), child: Text('No items available for this service.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)));
          }
          return Column(
            children: filteredItems.map((item) {
              final cat = item['name'] as String;
              final price = item['price'];
              final imageUrl = item['image_url'] as String?;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
                child: Row(children: [
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        '${ApiService.baseUrl}$imageUrl',
                        width: 32, height: 32, fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(Icons.checkroom_outlined, size: 24, color: Colors.grey),
                      )
                    )
                  else
                    const Icon(Icons.checkroom_outlined, size: 24, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cat, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    Text('₹$price', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ])),
                  IconButton(onPressed: () => _change(cat, -1), icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 22)),
                  Container(width: 36, alignment: Alignment.center,
                      child: Obx(() => Text('${ctrl.cartItems[cat]?.value ?? 0}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kPrimaryBlue)))),
                  IconButton(onPressed: () => _change(cat, 1), icon: const Icon(Icons.add_circle_outline, color: kAccentGreen, size: 22)),
                ]),
              );
            }).toList(),
          );
        }),
        Obx(() => ctrl.totalCartItems > 0 ?
          Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: kAccentGreen.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: Text('Total: ${ctrl.totalCartItems} items', style: const TextStyle(fontWeight: FontWeight.bold, color: kAccentGreen))) : const SizedBox()),
        const SizedBox(height: 20),
        
        // ── Location Section ──
        const Text('Pickup Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kPrimaryBlue)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() => Text(
                ctrl.currentAddress.value.isEmpty ? 'Location not fetched yet.' : ctrl.currentAddress.value,
                style: TextStyle(color: ctrl.currentAddress.value.isEmpty ? Colors.grey : Colors.black87, fontSize: 14),
              )),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Obx(() => ElevatedButton.icon(
                      onPressed: ctrl.isFetchingLocation.value ? null : () => ctrl.fetchCurrentLocation(),
                      icon: ctrl.isFetchingLocation.value 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location, size: 18),
                      label: const Text('Current'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentBlue.withValues(alpha: 0.1),
                        foregroundColor: kAccentBlue,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    )),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Get.to(() => const MapLocationPickerScreen());
                      },
                      icon: const Icon(Icons.map, size: 18),
                      label: const Text('Map'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentGreen.withValues(alpha: 0.1),
                        foregroundColor: kAccentGreen,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text('Pickup Time Slot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kPrimaryBlue)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: _slots.map((slot) {
          final sel = slot == _pickupSlot;
          return GestureDetector(
            onTap: () => setState(() => _pickupSlot = slot),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: sel ? kAccentBlue : kCardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? kAccentBlue : Colors.grey.shade300, width: sel ? 2 : 1),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.access_time, size: 14, color: sel ? Colors.white : Colors.grey),
                const SizedBox(width: 6),
                Text(slot, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : kPrimaryBlue)),
              ]),
            ),
          );
        }).toList()),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _pick,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text('Upload Photos (${_uploadImages.length})'),
          style: ElevatedButton.styleFrom(backgroundColor: kAccentGreen, minimumSize: const Size.fromHeight(44)),
        ),
        if (_uploadImages.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(height: 90, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _uploadImages.length,
              itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(borderRadius: BorderRadius.circular(10),
                      child: Image.file(File(_uploadImages[i].path), width: 90, height: 90, fit: BoxFit.cover))))),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isBooking ? null : _submit,
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: _isBooking ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Confirm Pickup Booking'),
        ),
        const SizedBox(height: 16),
      ])),
    );
  }
}

// ── PICKUP SCREEN ──────────────────────────────────────────────
class PickupScreen extends StatefulWidget {
  final LaundryOrder order;
  const PickupScreen({super.key, required this.order});
  @override State<PickupScreen> createState() => _PickupScreenState();
}
class _PickupScreenState extends State<PickupScreen> {
  final _picker = ImagePicker();
  Future<void> _capture() async { final img = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70); if (img != null) setState(() => widget.order.pickupImages.add(img)); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pickup & Submit')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [kPrimaryBlue, kAccentBlue]), borderRadius: BorderRadius.circular(16)), child: Column(children: [const Text('Your Booking Token', style: TextStyle(color: Colors.white70, fontSize: 13)), const SizedBox(height: 6), Text(widget.order.token, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 6))])),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]), child: Row(children: [const Icon(Icons.lock_outline, color: kAccentBlue), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Pickup OTP', style: TextStyle(fontSize: 12, color: Colors.grey)), Text(widget.order.pickupOtp, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimaryBlue, letterSpacing: 4))])])),
        const SizedBox(height: 16),
        const Text('Pickup boy is on the way to your address.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: _capture, icon: const Icon(Icons.camera_alt_outlined), label: Text('Capture Image (${widget.order.pickupImages.length})'), style: ElevatedButton.styleFrom(backgroundColor: kAccentGreen)),
        if (widget.order.pickupImages.isNotEmpty) ...[const SizedBox(height: 10), SizedBox(height: 90, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: widget.order.pickupImages.length, itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(right: 8), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(widget.order.pickupImages[i].path), width: 90, height: 90, fit: BoxFit.cover)))))],
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () { setState(() => widget.order.pickupConfirmed = true); Get.to(() => CustomerDeliveryScreen(order: widget.order)); }, style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: const Text('Confirm Pickup')),
      ])),
    );
  }
}

// ── CUSTOMER DELIVERY SCREEN ───────────────────────────────────
class CustomerDeliveryScreen extends StatefulWidget {
  final LaundryOrder order;
  const CustomerDeliveryScreen({super.key, required this.order});
  @override State<CustomerDeliveryScreen> createState() => _CustomerDeliveryScreenState();
}
class _CustomerDeliveryScreenState extends State<CustomerDeliveryScreen> {
  bool _done = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive Clothes')),
      body: Padding(padding: const EdgeInsets.all(16), child: _done ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: kAccentGreen.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.check_circle_rounded, size: 90, color: kAccentGreen)),
        const SizedBox(height: 24), const Text('Delivery Complete!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: kPrimaryBlue)),
        const SizedBox(height: 8), const Text('Your clothes are fresh and clean.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)]), child: Column(children: [
          _row('Token', widget.order.token), const Divider(height: 20), _row('Total Items', '${widget.order.totalItems}'), const Divider(height: 20), _row('Service', widget.order.service ?? '-'),
        ])),
      ])) : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [kAccentGreen, Color(0xFF2E7D32)]), borderRadius: BorderRadius.circular(16)), child: const Column(children: [Icon(Icons.local_shipping_outlined, color: Colors.white, size: 40), SizedBox(height: 8), Text('Your clothes are ready!', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), SizedBox(height: 4), Text('Tap below to confirm delivery.', style: TextStyle(color: Colors.white70, fontSize: 12))])),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: kAccentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.lock_outline, color: kAccentGreen, size: 24)), const SizedBox(width: 14), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Delivery OTP', style: TextStyle(fontSize: 12, color: Colors.grey)), Text(widget.order.deliveryOtp, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kPrimaryBlue, letterSpacing: 6))])])),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: kAccentBlue.withOpacity(0.07), borderRadius: BorderRadius.circular(12)), child: const Row(children: [Icon(Icons.info_outline, color: kAccentBlue, size: 18), SizedBox(width: 8), Expanded(child: Text('Share this OTP with the delivery person.', style: TextStyle(fontSize: 12, color: kAccentBlue)))])),
        const Spacer(),
        ElevatedButton(onPressed: () => setState(() { _done = true; widget.order.delivered = true; }), style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: kAccentGreen), child: const Text('Confirm Delivery Received')),
      ]),
    ),
    );
  }
  Widget _row(String l, String v) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey, fontSize: 14)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryBlue, fontSize: 14))]);
}
