import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../services/api_service.dart';
import 'delivery_kyc_pending_screen.dart';
import 'delivery_home_screen.dart';

class DeliveryKycScreen extends StatefulWidget {
  final String boyName;
  const DeliveryKycScreen({super.key, required this.boyName});
  @override State<DeliveryKycScreen> createState() => _DeliveryKycScreenState();
}

class _DeliveryKycScreenState extends State<DeliveryKycScreen> {
  final ImagePicker _picker = ImagePicker();
  
  XFile? _aadharFront;
  XFile? _aadharBack;
  XFile? _selfie;

  final TextEditingController _aadharCtrl = TextEditingController();

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      await ApiService.fetchDriverProfile();
      final auth = ApiService.instance.currentDeliveryAuth;
      if (auth != null) {
        if (auth.kycStatus == 'submitted') {
          Get.offAll(() => const DeliveryKycPendingScreen());
        } else if (auth.kycStatus != 'pending' && auth.kycStatus != 'submitted') {
          Get.offAll(() => DeliveryHomeScreen(boyName: auth.name));
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch profile: $e');
    }
  }

  @override
  void dispose() {
    _aadharCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() {
        if (type == 'aadhar_front') _aadharFront = image;
        if (type == 'aadhar_back') _aadharBack = image;
        if (type == 'selfie') _selfie = image;
      });
    }
  }

  Future<String> _toBase64(XFile file) async {
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  Future<void> _submitKyc() async {
    if (_aadharFront == null || _aadharBack == null || _selfie == null) {
      Get.snackbar('Error', 'Please upload Aadhar Front, Back, and Selfie', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    if (_aadharCtrl.text.trim().isEmpty) {
      Get.snackbar('Error', 'Please enter your Aadhar number', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    setState(() => _loading = true);
    try {
      final aadharFrontB64 = await _toBase64(_aadharFront!);
      final aadharBackB64 = await _toBase64(_aadharBack!);
      final selfieB64 = await _toBase64(_selfie!);

      await ApiService.uploadDriverKyc(
        aadharFrontBase64: aadharFrontB64,
        aadharBackBase64: aadharBackB64,
        selfieBase64: selfieB64,
        aadharNumber: _aadharCtrl.text.trim(),
      );

      Get.offAll(() => const DeliveryKycPendingScreen());
    } catch (e) {
      Get.snackbar('Error', e.toString(), backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildUploadCard(String title, XFile? file, String type, IconData icon) {
    return GestureDetector(
      onTap: () => _pickImage(type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: file != null ? kAccentGreen : Colors.grey.shade300),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (file != null ? kAccentGreen : kPrimaryBlue).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(file != null ? Icons.check_circle : icon, color: file != null ? kAccentGreen : kPrimaryBlue, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(file != null ? 'Uploaded' : 'Tap to upload', style: TextStyle(color: file != null ? kAccentGreen : Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
            if (file != null) const Icon(Icons.check, color: kAccentGreen),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0, top: 4.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryBlue)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightBg,
      appBar: AppBar(title: const Text('Driver KYC Setup'), automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.verified_user_outlined, size: 64, color: kPrimaryBlue),
            const SizedBox(height: 16),
            const Text(
              'Complete your KYC',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kPrimaryBlue),
            ),
            const SizedBox(height: 8),
            const Text(
              'You must upload these documents before you can start accepting rides.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            _buildUploadCard('Aadhar Card (Front)', _aadharFront, 'aadhar_front', Icons.credit_card),
            _buildUploadCard('Aadhar Card (Back)', _aadharBack, 'aadhar_back', Icons.credit_card_outlined),
            _buildTextField('Aadhar Number', _aadharCtrl),
            _buildUploadCard('Selfie', _selfie, 'selfie', Icons.face),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _submitKyc,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: kPrimaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _loading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('Submit KYC Documents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
