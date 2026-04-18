import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/services/fcm_service.dart';
import 'features/meeting/screens/splash_screen.dart';
import 'features/notifications/screens/notification_detail_page.dart';

Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final StreamController<RemoteMessage> notificationStream =
    StreamController<RemoteMessage>.broadcast();

const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await runZonedGuarded(() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    await Hive.initFlutter();
    await Hive.openBox('offline_meetings');
    await Hive.openBox('session_box');

    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing Supabase config. Pass SUPABASE_URL and SUPABASE_ANON_KEY with --dart-define.',
      );
    }

    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );

    runApp(const MyApp());
  }, (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('Unhandled startup error: $error\n$stackTrace');
    }
    runApp(const _StartupErrorApp());
  });
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Unable to initialize the app. Please contact support.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
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

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        Future.delayed(const Duration(milliseconds: 800), () {
          _handleNavigation(message);
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sub = notificationStream.stream.listen(_handleNavigation);
    });
  }

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

  void _handleNavigation(RemoteMessage message) {
    final data = message.data;
    final screen = data['screen']?.toString();
    final id = data['id']?.toString();

    if (screen == 'notification_detail' && id != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        final nav = navigatorKey.currentState;
        if (nav == null) return;
        nav.push(
          MaterialPageRoute(builder: (_) => NotificationDetailPage(id: id)),
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
