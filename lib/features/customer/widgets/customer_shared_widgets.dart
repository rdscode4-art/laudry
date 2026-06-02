import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

Widget customerCard({required Widget child, EdgeInsets? padding}) => Container(
  margin: const EdgeInsets.only(bottom: 14),
  padding: padding ?? const EdgeInsets.all(16),
  decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
  child: child,
);

Widget customerInfoRow(IconData icon, String label, String value) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 8),
    SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
    Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kPrimaryBlue))),
  ]),
);
