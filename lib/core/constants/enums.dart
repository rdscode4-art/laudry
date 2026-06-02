import 'package:flutter/material.dart';
import 'colors.dart';

enum ServiceType { laundry, dryCleaner }

extension ServiceTypeExt on ServiceType {
  String get label { switch (this) { case ServiceType.laundry: return 'Laundry'; case ServiceType.dryCleaner: return 'Dry Cleaner'; } }
  IconData get icon { switch (this) { case ServiceType.laundry: return Icons.local_laundry_service; case ServiceType.dryCleaner: return Icons.cleaning_services; } }
}

enum OrderStatus { pending, pickedUp, inLaundry, outForDelivery, delivered }
extension OrderStatusExt on OrderStatus {
  String get label { switch (this) { case OrderStatus.pending: return 'Pending Pickup'; case OrderStatus.pickedUp: return 'Picked Up'; case OrderStatus.inLaundry: return 'In Laundry'; case OrderStatus.outForDelivery: return 'Out for Delivery'; case OrderStatus.delivered: return 'Delivered'; } }
  Color get color { switch (this) { case OrderStatus.pending: return kOrange; case OrderStatus.pickedUp: return kAccentBlue; case OrderStatus.inLaundry: return Colors.purple; case OrderStatus.outForDelivery: return Colors.teal; case OrderStatus.delivered: return kAccentGreen; } }
  IconData get icon { switch (this) { case OrderStatus.pending: return Icons.schedule; case OrderStatus.pickedUp: return Icons.shopping_bag_outlined; case OrderStatus.inLaundry: return Icons.local_laundry_service; case OrderStatus.outForDelivery: return Icons.delivery_dining; case OrderStatus.delivered: return Icons.check_circle; } }
}
