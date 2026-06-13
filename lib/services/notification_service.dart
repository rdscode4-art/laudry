import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

// ── Background handler (top-level, required by FCM) ────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class NotificationService {
  NotificationService._privateConstructor();
  static final NotificationService instance =
      NotificationService._privateConstructor();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  // Local notifications only on mobile
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();
  // Audio only on non-web
  AudioPlayer? _audioPlayer;

  static const _kChannelId = 'order_channel';
  static const _kChannelName = 'New Orders';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Init audio player (skip on web — audioplayers web has no asset support)
    if (!kIsWeb) {
      _audioPlayer = AudioPlayer();
    }

    // ── FCM permissions ──────────────────────────────────────────
    try {
      await _fcm.requestPermission(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('[NotificationService] FCM permission error: $e');
    }

    // ── Local notifications (mobile only) ────────────────────────
    if (!kIsWeb) {
      const androidInit =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const iosInit = DarwinInitializationSettings();
      await _localNotif.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
      );

      const channel = AndroidNotificationChannel(
        _kChannelId,
        _kChannelName,
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('order_sound'),
        playSound: true,
        enableVibration: true,
      );
      await _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // ── FCM background handler ───────────────────────────────────
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
    }

    // ── Foreground FCM messages ──────────────────────────────────
    // App is FOREGROUND → cancel OS notification sound + show snackbar only
    // (AudioPlayer loop is handled by vendor/delivery home screens via socket)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Foreground message: ${message.messageId}');
      // Cancel any OS notification that might have slipped through
      if (!kIsWeb) {
        _localNotif.cancelAll();
      }
      final notif = message.notification;
      if (notif != null) {
        _showSnackbar(notif.title ?? 'New Order', notif.body ?? '');
      }
    });

    // ── Register FCM token ───────────────────────────────────────
    await _registerTokenIfLoggedIn();
  }

  // ── Called from SocketService when notification:new arrives ───
  // Socket = app is FOREGROUND → only snackbar + sound, NO local notification
  // (Local notification is for FCM background case only)
  void handleSocketNotification(Map<String, dynamic> notif) {
    final title = notif['title'] as String? ?? 'New Order';
    final body = notif['body'] as String? ?? '';
    final eventType = notif['eventType'] as String? ?? '';

    final isOrderEvent = eventType.contains('order') ||
        eventType.contains('new') ||
        eventType.contains('broadcast') ||
        eventType.contains('placed');

    if (isOrderEvent && !kIsWeb) {
      _playSound(); // in-app sound only
    }
    _showSnackbar(title, body); // snackbar only, no local notification
  }

  Future<void> _playSound() async {
    if (kIsWeb || _audioPlayer == null) return;
    try {
      await _audioPlayer!.stop();
      await _audioPlayer!.play(AssetSource('order_sound.mp3'));
    } catch (e) {
      debugPrint('[NotificationService] Sound play error: $e');
    }
  }

  Future<void> stopSound() async {
    // 1. Stop in-app AudioPlayer
    if (!kIsWeb && _audioPlayer != null) {
      try {
        await _audioPlayer!.stop();
      } catch (_) {}
    }
    // 2. Cancel ALL OS notifications (stops notification sound on Android)
    if (!kIsWeb) {
      try {
        await _localNotif.cancelAll();
      } catch (_) {}
    }
  }

  void _showSnackbar(String title, String body) {
    if (Get.context == null) return;
    Get.snackbar(
      title,
      body,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 5),
      backgroundColor: Colors.white,
      colorText: Colors.black87,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      icon: const Icon(Icons.notifications_active, color: Colors.orange),
      boxShadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 10,
        )
      ],
    );
  }

  Future<void> registerToken(String userType, String userId) async {
    try {
      debugPrint('[FCM] Getting token for $userType:$userId ...');
      
      // Force token refresh
      String? token;
      try {
        token = await _fcm.getToken();
      } catch (e) {
        debugPrint('[FCM] getToken() error: $e');
      }

      if (token == null || token.isEmpty) {
        debugPrint('[FCM] Token is null/empty — FCM not available on this device/build');
        return;
      }

      debugPrint('[FCM] Got token (${token.length} chars): ${token.substring(0, 20)}...');

      // Direct HTTP call — bypass ApiService._request to avoid silent failures
      try {
        final uri = Uri.parse('${ApiService.baseUrl}/api/notifications/device-token');
        final res = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'userType': userType,
            'userId': userId,
            'token': token,
            'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          }),
        );
        debugPrint('[FCM] Register token response: ${res.statusCode} ${res.body}');
      } catch (e) {
        debugPrint('[FCM] Register token HTTP error: $e');
      }
    } catch (e) {
      debugPrint('[FCM] registerToken outer error: $e');
    }
  }

  Future<void> _registerTokenIfLoggedIn() async {
    try {
      if (ApiService.instance.isLoggedIn &&
          ApiService.instance.currentCustomer != null) {
        await registerToken(
            'customer', ApiService.instance.currentCustomer!.id);
      } else if (ApiService.instance.isVendorLoggedIn &&
          ApiService.instance.currentVendorAuth != null) {
        await registerToken(
            'vendor', ApiService.instance.currentVendorAuth!.vendorId);
      } else if (ApiService.instance.isDeliveryLoggedIn &&
          ApiService.instance.currentDeliveryAuth != null) {
        await registerToken(
            'delivery', ApiService.instance.currentDeliveryAuth!.deliveryId);
      }
    } catch (e) {
      debugPrint('[NotificationService] _registerTokenIfLoggedIn error: $e');
    }
  }
}
