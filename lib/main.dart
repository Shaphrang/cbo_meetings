// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/services/fcm_service.dart';
import 'features/meeting/screens/splash_screen.dart';
import 'features/notifications/screens/notification_detail_page.dart';

/// 🔔 Background handler
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Background notification received");
}

/// 🔑 Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 🔄 Notification stream (used across app)
final StreamController<RemoteMessage> notificationStream =
    StreamController<RemoteMessage>.broadcast();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    /// 🔥 Firebase
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    /// 🔥 Hive
    await Hive.initFlutter();
    await Hive.openBox('offline_meetings');
    await Hive.openBox('session_box');

    /// 🔥 Supabase
    await Supabase.initialize(
      url: 'https://bygfityympgtscogjjgd.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ5Z2ZpdHl5bXBndHNjb2dqamdkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI1MjgxODksImV4cCI6MjA4ODEwNDE4OX0.9wSX4Dbs2Jcni3OQvW2yMQJke-Bl0LyJvn3ERKspBBk',
    );
  } catch (e) {
    debugPrint("Startup error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription<RemoteMessage> _notificationSub;

  @override
  void initState() {
    super.initState();

    /// 🔥 Init FCM (production safe)
    FCMService.init();

    /// 🔥 Safe navigation listener (after UI ready)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationSub = notificationStream.stream.listen((message) {
        _handleNavigation(message);
      });
    });
  }

  @override
  void dispose() {
    _notificationSub.cancel();
    super.dispose();
  }

  /// 🚀 MAIN NAVIGATION HANDLER
  void _handleNavigation(RemoteMessage message) {
    if (!mounted) return;

    final data = message.data;

    debugPrint("🔥 NAVIGATION DATA: $data");

    final String? screen = data['screen'];
    final String? id = data['id'];

    if (screen == 'notification_detail' && id != null) {
      if (navigatorKey.currentState == null) {
        debugPrint("❌ Navigator not ready");
        return;
      }

      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => NotificationDetailPage(id: id),
        ),
      );
    } else {
      debugPrint("⚠️ Unknown notification payload: $data");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: const SplashScreen(),
    );
  }
}