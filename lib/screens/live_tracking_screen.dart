import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String orderId;
  final String token;

  const LiveTrackingScreen({
    super.key,
    required this.orderId,
    required this.token,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  OrderTimeline? _timeline;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    SocketService.instance.joinOrderRoom(widget.orderId);
    SocketService.instance.addOrderListener(_onOrderUpdate);
  }

  @override
  void dispose() {
    SocketService.instance.leaveOrderRoom(widget.orderId);
    SocketService.instance.removeOrderListener(_onOrderUpdate);
    super.dispose();
  }

  void _onOrderUpdate(Map<String, dynamic> payload) {
    final timelineData = payload['timeline'] as Map<String, dynamic>?;
    if (timelineData != null && mounted) {
      setState(() => _timeline = OrderTimeline.fromJson(timelineData));
    }
  }

  Future<void> _load() async {
    try {
      final t = await ApiService.instance.fetchOrderTimeline(widget.orderId);
      if (mounted) setState(() { _timeline = t; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live Tracking', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text('Order #${widget.orderId}  Token: ${widget.token}',
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildTimeline(),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );

  Widget _buildTimeline() {
    final t = _timeline!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status pill
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.currentLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                if (t.estimatedDeliveryAt != null) ...[
                  const SizedBox(height: 4),
                  Text('Est. delivery: ${_fmtDate(t.estimatedDeliveryAt!)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Delivery partner
          if (t.deliveryPartner != null) _buildPartnerCard(t.deliveryPartner!),

          const Text('Order Timeline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // Steps
          for (int i = 0; i < t.steps.length; i++) _buildStep(t.steps[i], i == t.steps.length - 1),

          // Event log
          if (t.events.isNotEmpty) ...[
            const SizedBox(height: 28),
            const Text('Activity Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...t.events.reversed.map((e) => _buildEvent(e)),
          ],
        ],
      ),
    );
  }

  Widget _buildStep(TrackingStep step, bool isLast) {
    final done    = step.completed;
    final current = step.current;
    final color   = done ? const Color(0xFF43A047) : current ? const Color(0xFF1E88E5) : Colors.grey.shade300;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: color,
              child: done
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : current
                      ? const Icon(Icons.radio_button_checked, size: 14, color: Colors.white)
                      : Icon(Icons.circle_outlined, size: 14, color: Colors.grey.shade400),
            ),
            if (!isLast)
              Container(width: 2, height: 32, color: done ? const Color(0xFF43A047) : Colors.grey.shade300),
          ],
        ),
        const SizedBox(width: 14),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            step.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: current ? FontWeight.bold : FontWeight.normal,
              color: done || current ? Colors.black87 : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPartnerCard(Map<String, dynamic> partner) => Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF1E88E5).withOpacity(0.12),
              child: const Icon(Icons.delivery_dining, color: Color(0xFF1E88E5)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(partner['name'] as String? ?? 'Delivery Partner',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (partner['phone'] != null)
                    Text(partner['phone'] as String,
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF43A047).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                (partner['status'] as String? ?? 'online').toUpperCase(),
                style: const TextStyle(fontSize: 11, color: Color(0xFF43A047), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

  Widget _buildEvent(Map<String, dynamic> e) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.circle, size: 8, color: Color(0xFF1E88E5)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e['label'] as String? ?? e['status'] as String,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  if ((e['message'] as String? ?? '').isNotEmpty)
                    Text(e['message'] as String,
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(_fmtDate(e['createdAt'] as String),
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      );

  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
