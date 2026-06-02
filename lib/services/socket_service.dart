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

  void addOrderListener(OrderUpdateCallback cb)    => _orderListeners.add(cb);
  void removeOrderListener(OrderUpdateCallback cb) => _orderListeners.remove(cb);
  void addNotifListener(void Function(Map<String, dynamic>) cb) => _notifListeners.add(cb);
  void removeNotifListener(void Function(Map<String, dynamic>) cb) => _notifListeners.remove(cb);

  void connect(String jwtToken) {
    if (_socket != null && _socket!.connected) return;

    _socket = io.io(
      ApiService.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': jwtToken})
          .build(),
    );

    _socket!.on('connect', (_) {
      // ignore: avoid_print
      print('[Socket] connected');
    });

    _socket!.on('disconnect', (_) {
      // ignore: avoid_print
      print('[Socket] disconnected');
    });

    _socket!.on('order:updated', (data) {
      if (data is Map<String, dynamic>) {
        for (final cb in List.of(_orderListeners)) cb(data);
      }
    });

    _socket!.on('notification:new', (data) {
      if (data is Map<String, dynamic>) {
        for (final cb in List.of(_notifListeners)) cb(data);
      }
    });

    _socket!.connect();
  }

  void joinOrderRoom(String orderId) {
    _socket?.emit('join:order', orderId);
  }

  void leaveOrderRoom(String orderId) {
    _socket?.emit('leave:order', orderId);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
