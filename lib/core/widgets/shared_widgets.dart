import 'package:flutter/material.dart';
import '../constants/colors.dart';

Widget logoWidget({double size = 110}) => Container(
  width: size, height: size,
  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: kAccentBlue.withOpacity(0.18), blurRadius: 20, offset: const Offset(0, 6))]),
  child: ClipOval(child: Image.asset('assets/images/logo.jpeg', fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(Icons.local_laundry_service, size: size * 0.5, color: kAccentBlue))),
);
