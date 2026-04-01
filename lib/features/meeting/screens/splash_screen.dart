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
    debugPrint("🚀 Splash started");

    try {
      await MasterDataService()
          .syncMasterData()
          .timeout(const Duration(seconds: 6));

      debugPrint("✅ Master sync done");
    } catch (e) {
      debugPrint("⚠️ Master sync failed: $e");
    }

    try {
      final box = Hive.box('session_box');
      final session = box.get('meeting_session');

      debugPrint("📦 Session: $session");

      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      /// 🔥 ALWAYS NAVIGATE (NO STUCK STATE)
      if (session != null) {
        final districtId = session["district_id"];
        final blockId = session["block_id"];

        if (districtId != null && blockId != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MeetingCaptureScreen(
                meetingType: session["meetingType"],
                district: session["district"] ?? "",
                block: session["block"] ?? "",
                districtId: districtId,
                blockId: blockId,
                village: session["village"],
                voName: session["voName"],
                clfName: session["clfName"],
              ),
            ),
          );
          return;
        } else {
          /// Old session → clear
          await box.delete('meeting_session');
        }
      }

      /// ✅ DEFAULT FLOW
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const MeetingFormScreen(),
      ),
    );

    } catch (e) {
      debugPrint("❌ Navigation error: $e");

      if (!mounted) return;

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