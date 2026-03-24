// lib/features/meeting/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../core/services/master_data_service.dart';
import 'meeting_form_screen.dart';
import 'meeting_capture_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    initializeApp();
  }

  Future<void> initializeApp() async {
    try {
      /// 🔥 Load master data with timeout (VERY IMPORTANT)
      await MasterDataService()
          .syncMasterData()
          .timeout(const Duration(seconds: 8));

    } catch (e) {
      debugPrint("Master data error: $e");
      /// Continue anyway (don't block app)
    }

    try {
      /// 🔥 Check session
      final box = Hive.box('session_box');
      final session = box.get('meeting_session');

      /// Small delay (UX only)
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      /// 🔥 Navigate safely
      if (session != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MeetingCaptureScreen(
              meetingType: session["meetingType"],
              district: session["district"],
              block: session["block"],
              village: session["village"],
              voName: session["voName"],
              clfName: session["clfName"],
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MeetingFormScreen(),
          ),
        );
      }

    } catch (e) {
      debugPrint("Navigation error: $e");

      if (!mounted) return;

      /// 🔥 FINAL FALLBACK (never stuck)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const MeetingFormScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            Image.asset(
              "assets/images/msrls_logo.png",
              height: 150,
            ),

            const SizedBox(height: 24),

            const Text(
              "Capture. Monitor.",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              "Empower Rural Communities",
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 30),

            const CircularProgressIndicator(
              color: Color(0xFF2E7D32),
            ),
          ],
        ),
      ),
    );
  }
}