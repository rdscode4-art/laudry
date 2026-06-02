import 'dart:math';
import 'package:image_picker/image_picker.dart';
import '../constants/enums.dart';

class LaundryOrder {
  String name = ''; String email = ''; String phone = '';
  String address = ''; String city = ''; String pincode = '';
  Map<String, dynamic>? plan; ServiceType? service;
  String nearestLaundry = 'Quick Clean Laundry';
  String id = '';
  String pickupOtp = ''; String deliveryOtp = ''; String token = '';
  String pickupSlot = '';
  Map<String, int> items = {'Shirt': 0, 'Pant': 0, 'Saree': 0, 'Shorts': 0, 'T-Shirt': 0, 'Kurta': 0, 'Blazer': 0, 'Suit': 0};
  List<XFile> uploadImages = []; List<XFile> pickupImages = [];
  bool pickupConfirmed = false; bool delivered = false;

  // Wallet
  double walletBalance = 250.0;
  List<Map<String, dynamic>> walletHistory = [
    {'type': 'credit', 'amount': 100.0, 'desc': 'Referral Bonus', 'date': '20 May'},
    {'type': 'credit', 'amount': 200.0, 'desc': 'Wallet Recharge', 'date': '18 May'},
    {'type': 'debit',  'amount': 50.0,  'desc': 'Order ORD003',    'date': '15 May'},
  ];

  // Referral
  String referralCode = 'RIDEAL${Random().nextInt(9000) + 1000}';
  int referralCount = 2;
  double referralEarned = 100.0;

  // Complaints
  List<Map<String, dynamic>> complaints = [];

  // Ratings given
  Map<String, int> orderRatings = {};

  int get totalItems => items.values.fold(0, (v, q) => v + q);
  void generateToken() {
    if (token.isEmpty) {
      token = (Random().nextInt(9000) + 1000).toString();
    }
    pickupOtp = (Random().nextInt(9000) + 1000).toString();
    deliveryOtp = (Random().nextInt(9000) + 1000).toString();
  }
}
