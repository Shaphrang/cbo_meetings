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

/// 🔔 BACKGROUND HANDLER
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// 🔑 NAVIGATOR
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 🔄 NOTIFICATION STREAM
final StreamController<RemoteMessage> notificationStream =
    StreamController<RemoteMessage>.broadcast();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// 🔥 FIREBASE
  await Firebase.initializeApp();

  /// 🔥 BACKGROUND HANDLER
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  /// 🔥 HIVE
  await Hive.initFlutter();
  await Hive.openBox('offline_meetings');
  await Hive.openBox('session_box');

  /// 🔥 SUPABASE
  await Supabase.initialize(
    url: 'https://bygfityympgtscogjjgd.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ5Z2ZpdHl5bXBndHNjb2dqamdkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI1MjgxODksImV4cCI6MjA4ODEwNDE4OX0.9wSX4Dbs2Jcni3OQvW2yMQJke-Bl0LyJvn3ERKspBBk',
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription<RemoteMessage>? _sub;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    FCMService.init();

    /// 🔥 HANDLE TERMINATED STATE DIRECTLY
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        Future.delayed(const Duration(milliseconds: 800), () {
          _handleNavigation(message);
        });
      }
    });

    /// 🔥 STREAM LISTENER
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sub = notificationStream.stream.listen(_handleNavigation);
    });
  }

  /// 🔁 RETRY ON RESUME
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      FCMService.retryOnResume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  /// 🚀 HANDLE NAVIGATION
  void _handleNavigation(RemoteMessage message) {
    final data = message.data;

    final String? screen = data['screen'];
    final String? id = data['id'];

    if (screen == 'notification_detail' && id != null) {
      /// 🔥 DELAY NAVIGATION UNTIL UI READY
      Future.delayed(const Duration(milliseconds: 500), () {
        final nav = navigatorKey.currentState;
        if (nav == null) return;

        nav.push(
          MaterialPageRoute(
            builder: (_) => NotificationDetailPage(id: id),
          ),
        );
      });
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