// lib/core/services/fcm_service.dart
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../main.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static bool _initialized = false;
  static Timer? _retryTimer;
  static DateTime? _lastRetry;

  /// 🔑 INIT (CALL ONCE)
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _requestPermission();

    /// small delay → improves token success rate
    await Future.delayed(const Duration(seconds: 1));

    await _initToken();

    _setupListeners();
  }

  /// 🔔 Permission
  static Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    /// 🔥 REQUIRED FOR FOREGROUND NOTIFICATIONS
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// 🔑 TOKEN INIT
  static Future<void> _initToken() async {
    final token = await _getToken();

    if (token != null) {
      _log("FCM Token ready");
      await _subscribeTopic();
    } else {
      _log("Token not available → starting retry");
      _startRetry();
    }

    /// 🔄 Token refresh
    _messaging.onTokenRefresh.listen((_) async {
      _log("Token refreshed");
      await _subscribeTopic();
    });
  }

  /// 🔁 GET TOKEN (stable)
  static Future<String?> _getToken() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();

      if (connectivity == ConnectivityResult.none) return null;

      final token = await _messaging.getToken();

      if (token != null && token.isNotEmpty) return token;

    } catch (_) {}

    return null;
  }

  /// 🔁 RETRY (controlled, no spam)
  static void _startRetry() {
    _retryTimer?.cancel();

    _retryTimer = Timer.periodic(const Duration(minutes: 3), (timer) async {
      final token = await _getToken();

      if (token != null) {
        _log("Token recovered");
        await _subscribeTopic();
        timer.cancel();
      }
    });
  }

  /// 🔁 RETRY ON RESUME (rate limited)
  static void retryOnResume() {
    final now = DateTime.now();

    if (_lastRetry != null &&
        now.difference(_lastRetry!) < const Duration(minutes: 2)) {
      return;
    }

    _lastRetry = now;

    _startRetry();
  }

  /// 🔥 TOPIC SUBSCRIBE
  static Future<void> _subscribeTopic() async {
    try {
      await _messaging.subscribeToTopic("meetings_app");
      _log("Subscribed to topic");
    } catch (_) {
      _log("Topic subscription failed");
    }
  }

  /// 🎧 LISTENERS
  static void _setupListeners() {
    /// FOREGROUND
    FirebaseMessaging.onMessage.listen((message) {
      _log("Foreground message");
    });

    /// BACKGROUND TAP
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      notificationStream.add(message);
    });

    /// TERMINATED TAP
  }

  /// 🔇 SAFE LOG (no spam in release)
  static void _log(String msg) {
    if (kDebugMode) {
      debugPrint("[FCM] $msg");
    }
  }
}