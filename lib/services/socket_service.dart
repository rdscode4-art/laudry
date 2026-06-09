import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_service.dart';

typedef OrderUpdateCallback = void Function(Map<String, dynamic> payload);

class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  io.Socket? _socket;
  bool get connected => _socket?.connected ?? false;

  final List<OrderUpdateCallback> _orderListeners = [];
  final List<void Function(Map<String, dynamic>)> _notifListeners = [];

  void addOrderListener(OrderUpdateCallback cb) {
    if (!_orderListeners.contains(cb)) _orderListeners.add(cb);
  }
  void removeOrderListener(OrderUpdateCallback cb) =>
      _orderListeners.remove(cb);
  void addNotifListener(void Function(Map<String, dynamic>) cb) {
    if (!_notifListeners.contains(cb)) _notifListeners.add(cb);
  }
  void removeNotifListener(void Function(Map<String, dynamic>) cb) =>
      _notifListeners.remove(cb);

  void connect(String jwtToken) {
    // Already connected — skip
    if (_socket != null && _socket!.connected) {
      debugPrint('[Socket] Already connected, skipping reconnect');
      return;
    }

    // Dispose old socket if exists but disconnected
    if (_socket != null) {
      _socket!.dispose();
      _socket = null;
    }

    debugPrint('[Socket] Connecting to ${ApiService.baseUrl}');

    _socket = io.io(
      ApiService.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling']) // allow polling fallback
          .disableAutoConnect()
          .setAuth({'token': jwtToken})
          .setTimeout(10000)
          .setReconnectionAttempts(5)
          .build(),
    );

    _socket!.on('connect', (_) {
      debugPrint('[Socket] ✅ Connected! id=${_socket?.id}');
    });

    _socket!.on('connect_error', (err) {
      debugPrint('[Socket] ❌ Connect error: $err');
    });

    _socket!.on('disconnect', (reason) {
      debugPrint('[Socket] Disconnected: $reason');
    });

    _socket!.on('order:updated', (data) {
      debugPrint('[Socket] order:updated received: $data');
      if (data is Map<String, dynamic>) {
        for (final cb in List.of(_orderListeners)) {
          cb(data);
        }
      }
    });

    _socket!.on('notification:new', (data) {
      debugPrint('[Socket] notification:new received');
      if (data is Map<String, dynamic>) {
        for (final cb in List.of(_notifListeners)) {
          cb(data);
        }
      }
    });

    _socket!.connect();
    debugPrint('[Socket] connect() called');
  }

  void joinOrderRoom(String orderId) {
    debugPrint('[Socket] joining order room: $orderId');
    _socket?.emit('join:order', orderId);
  }

  void leaveOrderRoom(String orderId) {
    _socket?.emit('leave:order', orderId);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    debugPrint('[Socket] Disconnected and disposed');
  }
}
