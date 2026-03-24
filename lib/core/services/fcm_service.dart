// lib/core/services/fcm_service.dart
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../main.dart'; // 👈 IMPORTANT (for notificationStream)

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// 🔑 Initialize FCM
  static Future<void> init() async {
    await _requestPermission();
    await _setupTokenHandling();
    _setupListeners();
  }

  /// 🔔 Request permission
  static Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// 🔑 Token + Topic (production safe)
  static Future<void> _setupTokenHandling() async {
    String? token;
    int retry = 0;

    while (token == null && retry < 5) {
      try {
        token = await _messaging.getToken();
        if (token == null) {
          await Future.delayed(const Duration(seconds: 2));
        }
      } catch (e) {
        debugPrint("Token error: $e");
      }
      retry++;
    }

    if (token != null) {
      debugPrint("✅ FCM TOKEN: $token");
      await _safeSubscribeToTopic("meetings_app");
    } else {
      debugPrint("❌ Failed to get FCM token");
    }

    /// 🔄 Token refresh
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint("🔄 Token refreshed: $newToken");
      await _safeSubscribeToTopic("meetings_app");
    });
  }

  /// 🔥 Safe topic subscribe (retry)
  static Future<void> _safeSubscribeToTopic(String topic) async {
    int retry = 0;

    while (retry < 5) {
      try {
        await _messaging.subscribeToTopic(topic);
        debugPrint("✅ Subscribed to topic: $topic");
        return;
      } catch (e) {
        retry++;
        debugPrint("⚠️ Retry subscribe ($retry): $e");
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    debugPrint("❌ Failed to subscribe after retries");
  }

  /// 🎧 Listeners
  static void _setupListeners() {
    /// 🟢 Foreground
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint("📩 Foreground message received");
    });

    /// 🟡 Background click
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint("📲 Notification opened (background)");
      notificationStream.add(message);
    });

    /// 🔴 Terminated click
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint("📲 Notification opened (terminated)");
        notificationStream.add(message);
      }
    });
  }
}