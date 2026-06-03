import '../constants/enums.dart';

class DeliveryOrder {
  final String id, customerName, customerAddress, customerPhone, token, pickupOtp, deliveryOtp, vendorDropoffOtp, vendorDispatchOtp, service;
  final int totalItems;
  OrderStatus status;
  List<String> pickupPhotos; List<String> deliveryPhotos;
  DeliveryOrder({required this.id, required this.customerName, required this.customerAddress, required this.customerPhone, required this.token, required this.pickupOtp, required this.deliveryOtp, required this.vendorDropoffOtp, required this.vendorDispatchOtp, required this.totalItems, required this.service, this.status = OrderStatus.pending, List<String>? pickupPhotos, List<String>? deliveryPhotos})
      : pickupPhotos = pickupPhotos ?? [], deliveryPhotos = deliveryPhotos ?? [];
}

final List<DeliveryOrder> sharedOrders = [
  DeliveryOrder(id: 'ORD001', customerName: 'Rahul Sharma',  customerAddress: '12, MG Road, Sector 5, Delhi',  customerPhone: '9876543210', token: '4821', pickupOtp: '1234', deliveryOtp: '1234', vendorDropoffOtp: '1234', vendorDispatchOtp: '1234', totalItems: 8,  service: 'Laundry',      status: OrderStatus.pickedUp),
  DeliveryOrder(id: 'ORD002', customerName: 'Priya Singh',   customerAddress: '45, Park Street, Noida, UP',    customerPhone: '9812345678', token: '3317', pickupOtp: '1234', deliveryOtp: '1234', vendorDropoffOtp: '1234', vendorDispatchOtp: '1234', totalItems: 5,  service: 'Dry Cleaner',  status: OrderStatus.pickedUp),
  DeliveryOrder(id: 'ORD003', customerName: 'Amit Verma',    customerAddress: '7, Lajpat Nagar, New Delhi',    customerPhone: '9988776655', token: '6604', pickupOtp: '1234', deliveryOtp: '1234', vendorDropoffOtp: '1234', vendorDispatchOtp: '1234', totalItems: 12, service: 'Laundry',      status: OrderStatus.inLaundry),
  DeliveryOrder(id: 'ORD004', customerName: 'Sneha Patel',   customerAddress: '88, Andheri West, Mumbai',      customerPhone: '9123456789', token: '9102', pickupOtp: '1234', deliveryOtp: '1234', vendorDropoffOtp: '1234', vendorDispatchOtp: '1234', totalItems: 3,  service: 'Dry Cleaner',  status: OrderStatus.outForDelivery),
  DeliveryOrder(id: 'ORD005', customerName: 'Vikram Joshi',  customerAddress: '23, Koramangala, Bangalore',    customerPhone: '9001234567', token: '5538', pickupOtp: '1234', deliveryOtp: '1234', vendorDropoffOtp: '1234', vendorDispatchOtp: '1234', totalItems: 7,  service: 'Laundry',      status: OrderStatus.delivered),
  DeliveryOrder(id: 'ORD006', customerName: 'Neha Gupta',    customerAddress: '34, Sector 18, Gurgaon',        customerPhone: '9765432100', token: '7723', pickupOtp: '1234', deliveryOtp: '1234', vendorDropoffOtp: '1234', vendorDispatchOtp: '1234', totalItems: 4,  service: 'Dry Cleaner',  status: OrderStatus.inLaundry),
  DeliveryOrder(id: 'ORD007', customerName: 'Suresh Yadav',  customerAddress: '56, Civil Lines, Allahabad',    customerPhone: '9654321098', token: '2290', pickupOtp: '1234', deliveryOtp: '1234', vendorDropoffOtp: '1234', vendorDispatchOtp: '1234', totalItems: 9,  service: 'Laundry',      status: OrderStatus.pending),
];
