//lib\features\meeting\screens\meeting_capture_screen.dart
import 'dart:async';

import 'package:hive/hive.dart';
import 'dart:io';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/image_service.dart';
import '../../../core/services/offline_meeting_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../features/meeting/screens/camera_screen.dart';
import '../../notifications/screens/notification_list_page.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'meeting_form_screen.dart';

class MeetingCaptureScreen extends StatefulWidget {
  final String meetingType;
  final String district;
  final String block;
  final String? village;
  final String? voName;
  final String? clfName;
  final String districtId;
  final String blockId;

  const MeetingCaptureScreen({
    super.key,
    required this.meetingType,
    required this.district,
    required this.block,
    required this.districtId,   // ✅ NEW
    required this.blockId,  
    this.village,
    this.voName,
    this.clfName,
  });

  @override
  State<MeetingCaptureScreen> createState() => _MeetingCaptureScreenState();
}

class _MeetingCaptureScreenState extends State<MeetingCaptureScreen> {
  int pendingSyncCount = 0;
  final ScrollController _scrollController = ScrollController();
  final phoneController = TextEditingController();
  final membersController = TextEditingController();
  final savingsAmountController = TextEditingController();
  final loanAmountController = TextEditingController();
  final repaymentAmountController = TextEditingController();
  final remarksController = TextEditingController();
  final nameController = TextEditingController();
  final agendaController = TextEditingController();

  String selectedRole = "Member"; // default

  final LocationService locationService = LocationService();
  final ImageService imageService = ImageService();

  static const Color primaryBlue = Color(0xFF1A73E8);
  static const Color background = Color(0xFFF2F5F9);

  final FocusNode savingsFocus = FocusNode();
  final FocusNode loanFocus = FocusNode();
  final FocusNode repaymentFocus = FocusNode();
  final FocusNode submitFocus = FocusNode(); // for later use

  bool isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool savingsCollected = false;
  bool internalLoan = false;
  bool loanRepayment = false;
  String minutesBookkeeping = "YES"; // default

  bool loading = false;
  bool photoLoading = false;

  File? meetingPhoto;

  double? latitude;
  double? longitude;

  DateTime? capturedAt;

  @override
  void initState() {
    super.initState();
    checkInternet();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      setState(() => isOnline = !results.contains(ConnectivityResult.none));
    });
    loadPendingSyncCount();
  }

  bool validateRequiredFields() {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final members = membersController.text.trim();

    if (name.isEmpty) {
      _showError("Member name is required");
      return false;
    }

    if (phone.isEmpty || phone.length != 10) {
      _showError("Enter valid 10-digit mobile number");
      return false;
    }

    if (members.isEmpty) {
      _showError("Members attended is required");
      return false;
    }

    return true;
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> loadPendingSyncCount() async {
    final offline = OfflineMeetingService();
    final count = await offline.getPendingCount();

    if (!mounted) return;

    setState(() {
      pendingSyncCount = count;
    });
  }

  Future<void> checkInternet() async {
    final result = await Connectivity().checkConnectivity();
    if (!mounted) return;

    setState(() {
      isOnline = result != ConnectivityResult.none;
    });
  }

  Future<void> capturePhoto() async {
    try {
      FocusScope.of(context).unfocus();

      setState(() => photoLoading = true);

      final file = await Navigator.push<File>(
        context,
        MaterialPageRoute(
          builder: (_) => const CameraScreen(),
        ),
      );

      if (!mounted) return;

      if (file == null) {
        setState(() => photoLoading = false);
        return;
      }

      final compressed = await imageService.compress(file);

      if (!mounted) return;

      final location = await locationService.getLocation();

      if (!mounted) return;

      setState(() {
        meetingPhoto = compressed;
        latitude = location["latitude"];
        longitude = location["longitude"];
        capturedAt = location["timestamp"];
        photoLoading = false;
      });

      /// SAFE CONTEXT USAGE
      FocusScope.of(context).unfocus();

      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        FocusScope.of(context).requestFocus(submitFocus);
      });

    } catch (e) {
      if (!mounted) return;

      setState(() => photoLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Camera error: $e")),
      );
    }
  }
  
  void clearFormFields() {
    phoneController.clear();
    membersController.clear();
    savingsAmountController.clear();
    loanAmountController.clear();
    repaymentAmountController.clear();
    remarksController.clear();
    nameController.clear();
    agendaController.clear();

    selectedRole = "Member";

    setState(() {
      savingsCollected = false;
      internalLoan = false;
      loanRepayment = false;
      minutesBookkeeping = "YES";

      meetingPhoto = null;
      latitude = null;
      longitude = null;
      capturedAt = null; // ✅ FIX
    });

    FocusScope.of(context).unfocus(); // ✅ CLOSE KEYBOARD
  }

  Future<void> handleRefresh() async {
    await Future.delayed(const Duration(milliseconds: 400));

    clearFormFields();

    setState(() {
      loading = false;
      photoLoading = false;
    });

    await checkInternet();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Form reset")),
    );
  }

  Future<void> saveOfflineOnly() async {
    if (!validateRequiredFields()) return;

    if (meetingPhoto == null) {
      _showError("Please capture meeting photo");
      return;
    }

    if (widget.districtId.isEmpty || widget.blockId.isEmpty) {
      _showError("Missing district/block ID");
      return;
    }

    final offline = OfflineMeetingService();

    final meeting = {
      "meeting_type": widget.meetingType,
      "district": widget.district,
      "block": widget.block,

      "district_id": widget.districtId,
      "block_id": widget.blockId,
      "village": widget.village,
      "vo_name": widget.voName,
      "clf_name": widget.clfName,

      "member_name": nameController.text,
      "member_role": selectedRole,

      "mobile_number": phoneController.text,
      "members_attended": int.tryParse(membersController.text),

      "savings_collected": savingsCollected,
      "savings_amount": double.tryParse(savingsAmountController.text) ?? 0,

      "internal_loan_given": internalLoan,
      "internal_loan_amount": double.tryParse(loanAmountController.text) ?? 0,

      "internal_loan_repayment": loanRepayment,
      "repayment_amount": double.tryParse(repaymentAmountController.text) ?? 0,

      "minutes_bookeeping_maintained": minutesBookkeeping == "YES",

      "agenda_discussed": agendaController.text,
      "remarks": remarksController.text,

      "photo_path": meetingPhoto?.path,
      "latitude": latitude,
      "longitude": longitude,

      "created_at": DateTime.now().toIso8601String(),
    };

    /// 🔥 SAVE
    await offline.saveOffline(meeting);

    await loadPendingSyncCount();

    if (!mounted) return;

    /// 🔥 SHOW DIALOG AFTER EVERYTHING IS READY
    await showSuccessDialog(isOnline: false);
  }

  Future<void> submitMeeting() async {
    if (loading) return;

    if (!validateRequiredFields()) return;

    if (meetingPhoto == null) {
      _showError("Please capture meeting photo");
      return;
    }

    if (widget.districtId.isEmpty || widget.blockId.isEmpty) {
      _showError("Missing district/block ID");
      return;
    }

    setState(() => loading = true);

    final offline = OfflineMeetingService();
    final sync = SyncService(offlineMeetingService: offline);

    final meeting = {
      "meeting_type": widget.meetingType,
      "district": widget.district,
      "block": widget.block,

      "district_id": widget.districtId,
      "block_id": widget.blockId,
      "village": widget.village,
      "vo_name": widget.voName,
      "clf_name": widget.clfName,

      "member_name": nameController.text.isEmpty ? null : nameController.text,
      "member_role": selectedRole,
      "mobile_number": phoneController.text.isEmpty ? null : phoneController.text,
      "members_attended": int.tryParse(membersController.text),

      "savings_collected": savingsCollected,
      "savings_amount": double.tryParse(savingsAmountController.text) ?? 0,

      "internal_loan_given": internalLoan,
      "internal_loan_amount": double.tryParse(loanAmountController.text) ?? 0,

      "internal_loan_repayment": loanRepayment,
      "repayment_amount": double.tryParse(repaymentAmountController.text) ?? 0,

      "minutes_bookeeping_maintained": minutesBookkeeping == "YES",

      "agenda_discussed":
          agendaController.text.isEmpty ? null : agendaController.text,

      "remarks":
          remarksController.text.isEmpty ? null : remarksController.text,

      "photo_path": meetingPhoto?.path,
      "photo_url": null,
      "latitude": latitude,
      "longitude": longitude,
      "created_at":
          capturedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };

    final localId = await offline.saveOffline(meeting);

    try {
      await sync.syncSingleMeeting(meeting, localId: localId);
      await offline.clearSynced();

      if (!mounted) return;
      await loadPendingSyncCount();
      await showSuccessDialog(isOnline: true);
    } catch (_) {
      await loadPendingSyncCount();

      if (!mounted) return;
      await showSuccessDialog(isOnline: false);
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> openDashboard() async {
  final Uri url = Uri.parse("https://msrls-one.vercel.app/admin/institution_tracking/meetings_dashboard");

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open dashboard")),
      );
    }
  }

  Future<void> clearSessionData() async {
    final box = Hive.box('session_box');
    await box.delete('meeting_session');

    if (!mounted) return;

    Navigator.pop(context); // close drawer

    /// 🔥 GO BACK TO FORM SCREEN (RESET FLOW)
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MeetingFormScreen()),
      (route) => false,
    );
  }

  Future<void> syncNow() async {
    final connectivity = await Connectivity().checkConnectivity();

    if (!mounted) return;

    if (connectivity == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No internet connection")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final result = await SyncService().syncMeetings();

      if (!mounted) return;

      if (result["busy"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sync already in progress")),
        );
      } else if (result["total"] == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No pending data")),
        );
      } else if (result["failed"] == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Synced ${result["uploaded"]} meeting")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Uploaded: ${result["uploaded"]}, Failed: ${result["failed"]}",
            ),
          ),
        );
      }

      await loadPendingSyncCount();

    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Sync failed. Try again")),
      );

    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }
    
  Widget syncBanner() {
    if (pendingSyncCount == 0) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE0B2), Color(0xFFFFCC80)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: Colors.deepOrange),
          const SizedBox(width: 10),

          Expanded(
            child: Text(
              pendingSyncCount == 1
                ? "1 meeting pending sync"
                : "$pendingSyncCount meetings pending sync",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),

          InkWell(
            onTap: () async {
              await syncNow();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.deepOrange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "SYNC",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
    
  Future<void> showSuccessDialog({required bool isOnline}) async {
    final now = DateTime.now();

    final formatted =
        "${now.day.toString().padLeft(2, '0')}-"
        "${now.month.toString().padLeft(2, '0')}-"
        "${now.year}  "
        "${(now.hour % 12 == 0 ? 12 : now.hour % 12).toString().padLeft(2, '0')}:"
        "${now.minute.toString().padLeft(2, '0')} "
        "${now.hour >= 12 ? 'PM' : 'AM'}";

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Success",
      barrierColor: Colors.black.withValues(alpha: 0.6), // 🔥 stronger dark overlay
      transitionDuration: const Duration(milliseconds: 250),

      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [

            /// 🔥 BLUR BACKGROUND
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(color: Colors.transparent),
            ),

            /// 🔥 CENTER DIALOG
            Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      /// ICON
                      Icon(
                        isOnline ? Icons.check_circle : Icons.cloud_done,
                        color: isOnline ? Colors.green : Colors.orange,
                        size: 50,
                      ),

                      const SizedBox(height: 14),

                      /// TITLE
                      Text(
                        isOnline ? "Meeting Submitted" : "Saved Offline",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 10),

                      /// MESSAGE
                      Text(
                        isOnline
                            ? "Your meeting has been successfully submitted."
                            : "Meeting saved offline.\nPlease sync within a day.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                      ),

                      const SizedBox(height: 12),

                      /// DATE TIME
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F7FB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          formatted,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      /// BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            "THANK YOU",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },

      /// 🔥 NICE ANIMATION
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
    );

    /// 🔥 AFTER CLOSE
    clearFormFields();

    if (mounted && _scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }
   
    /// SECTION CARD
  Widget modernSectionCard(
    String title,
    Widget child, {
    IconData? icon,
    Gradient? gradient,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [

          /// HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              gradient: gradient ??
                  const LinearGradient(
                    colors: [Color(0xFF2F6FED), Color(0xFF1A73E8)],
                  ),
            ),
            child: Row(
              children: [
                if (icon != null)
                  Icon(icon, color: Colors.white, size: 18),
                if (icon != null) const SizedBox(width: 8),

                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFAFBFF), // soft background
                  ),
                ),
              ],
            ),
          ),

          /// BODY
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget financialBlock({required Widget child}) {
  return Container(
    padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.only(top: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF7FAFF),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: const Color(0xFFE3ECFF),
      ),
    ),
    child: child,
  );
}
  Widget amountFieldContainer({required Widget child}) {
  return Container(
    margin: const EdgeInsets.only(top: 8, bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F6FF),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: const Color(0xFFD6E4FF),
      ),
    ),
    child: child,
  );
}

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.black87,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// MODERN INPUT FIELD
  Widget inputField({
    required TextEditingController controller,
    required String label,
    TextInputType? type,
    List<TextInputFormatter>? formatters,
    FocusNode? focusNode,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: type,
      inputFormatters: formatters,

      /// 🔥 KEY FIXES
      autofocus: false,
      enableSuggestions: false,
      autocorrect: false,

      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white, // cleaner

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300), // 👈 ADD
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300), // 👈 ADD
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
      ),
    );
  }

  Widget locationTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "$label: $value",
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget financeItem({
    required String title,
    required bool value,
    required Function(bool?) onChanged,
    required TextEditingController controller,
    required String label,
  }) {
    return Column(
      children: [
        CheckboxListTile(
          title: Text(title),
          value: value,
          onChanged: onChanged,
          activeColor: primaryBlue,
          controlAffinity: ListTileControlAffinity.leading,
        ),

        if (value)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: inputField(
              controller: controller,
              label: label,
              type: TextInputType.number,
              formatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
  phoneController.dispose();
  membersController.dispose();
  savingsAmountController.dispose();
  loanAmountController.dispose();
  repaymentAmountController.dispose();
  remarksController.dispose();
  nameController.dispose();
  agendaController.dispose();
  savingsFocus.dispose();
  loanFocus.dispose();
  repaymentFocus.dispose();
  submitFocus.dispose();
  _scrollController.dispose();
  _connectivitySubscription?.cancel();
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    return PopScope(
    canPop: false,

    onPopInvokedWithResult: (didPop, result) async {
      if (didPop) return;

      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Exit App"),
          content: const Text("Do you want to close the app?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("No"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("Yes"),
            ),
          ],
        ),
      );

      if (shouldExit == true) {
        SystemNavigator.pop(); // ✅ FIXED (no crash)
      }
    },
    child: Scaffold(
      drawer: Drawer(
        width: 220, // 🔥 makes it small & sleek
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            right: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [

              /// 🔹 SMALL HEADER
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: const [
                    Icon(Icons.settings, size: 26, color: Colors.black87),
                    SizedBox(height: 6),
                    Text(
                      "Menu",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              const SizedBox(height: 10),

              /// 🔹 MENU ITEMS
              _drawerItem(
                icon: Icons.delete_outline,
                title: "Clear CBO Data",
                color: Colors.red,
                onTap: clearSessionData,
              ),

              _drawerItem(
                icon: Icons.sync,
                title: "Sync Data",
                color: primaryBlue,
                onTap: () async {
                  Navigator.pop(context);
                  await syncNow();
                },
              ),
              _drawerItem(
                icon: Icons.notifications_active_outlined,
                title: "Notifications",
                color: const Color.fromARGB(255, 66, 248, 11),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationListPage(),
                    ),
                  );
                },
              ),

              const Spacer(),

              /// 🔹 FOOTER (optional branding)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  "CBO meeting app: MSRLS",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "Meeting Details",
          style: TextStyle(
              fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              /// 🔥 IMPORTANT: Wrap with Stack
            child: Stack(
              children: [
              RefreshIndicator(
                onRefresh: handleRefresh,
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                      child: ListView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(), // ✅ REQUIRED
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        children: [
                        syncBanner(),
                        /// LOCATION CARD
                        modernSectionCard(
                          "CBO Details",
                          Column(
                            children: [
                              locationTile(Icons.location_city, "District", widget.district),
                              locationTile(Icons.map, "Block", widget.block),
                              if (widget.village != null)
                                locationTile(Icons.home, "Village", widget.village!),
                              if (widget.voName != null)
                                locationTile(Icons.groups, "VO", widget.voName!),
                              if (widget.clfName != null)
                                locationTile(Icons.account_balance, "CLF", widget.clfName!),
                            ],
                          ),
                          icon: Icons.location_on,
                        ),

                        /// MEETING INFO
                      modernSectionCard(
                        "Meeting Information",
                        icon: Icons.description,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            inputField(
                              controller: nameController,
                              label: "Member Name *",
                            ),
                            const SizedBox(height: 14),

                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedRole,
                                  isExpanded: true,
                                  items: ["President", "Secretary", "Treasurer", "Member"]
                                      .map((role) => DropdownMenuItem(
                                            value: role,
                                            child: Text(role),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedRole = value!;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            /// PHONE NUMBER
                            inputField(
                              controller: phoneController,
                              label: "Mobile Number *",
                              type: TextInputType.phone,
                              formatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                            ),

                            const SizedBox(height: 18),

                            /// MEMBERS ATTENDED
                            inputField(
                              controller: membersController,
                              label: "Members Attended *",
                              type: TextInputType.number,
                              formatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(2),
                              ],
                            ),

                            const SizedBox(height: 18),

                            /// SAVINGS SECTION
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F8FF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.blue.shade100),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  /// 🔹 SUB HEADING
                                  const Text(
                                    "Financial Activities (Optional)",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                financeItem(
                                  title: "Savings Collected",
                                  value: savingsCollected,
                                  controller: savingsAmountController,
                                  label: "Savings Amount (₹)",
                                  onChanged: (v) {
                                    setState(() {
                                      savingsCollected = v ?? false;
                                      if (!savingsCollected) savingsAmountController.clear();
                                    });
                                  },
                                ),

                                financeItem(
                                  title: "Internal Loan Given",
                                  value: internalLoan,
                                  controller: loanAmountController,
                                  label: "Loan Amount (₹)",
                                  onChanged: (v) {
                                    setState(() {
                                      internalLoan = v ?? false;
                                      if (!internalLoan) loanAmountController.clear();
                                    });
                                  },
                                ),

                                financeItem(
                                  title: "Loan Repayment",
                                  value: loanRepayment,
                                  controller: repaymentAmountController,
                                  label: "Repayment Amount (₹)",
                                  onChanged: (v) {
                                    setState(() {
                                      loanRepayment = v ?? false;
                                      if (!loanRepayment) repaymentAmountController.clear();
                                    });
                                  },
                                ),

                              ],
                            ),
                            ),
                            const SizedBox(height: 12),
                            /// BOOKKEEPING SWITCH
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFD6E4FF)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [

                                  /// 🔹 TITLE
                                  const Text(
                                    "Minutes & Bookkeeping Maintained ?",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  /// 🔹 OPTIONS
                                  Row(
                                    children: [

                                      /// YES BUTTON
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() => minutesBookkeeping = "YES");
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            decoration: BoxDecoration(
                                              color: minutesBookkeeping == "YES"
                                                  ? primaryBlue
                                                  : Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: minutesBookkeeping == "YES"
                                                    ? primaryBlue
                                                    : Colors.grey.shade300,
                                                width: 1.2,
                                              ),
                                              boxShadow: minutesBookkeeping == "YES"
                                                  ? [
                                                      BoxShadow(
                                                        color: primaryBlue.withValues(alpha: 0.2),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 3),
                                                      )
                                                    ]
                                                  : [],
                                            ),
                                            child: Column(
                                              children: [
                                                Icon(
                                                  Icons.check_circle,
                                                  size: 20,
                                                  color: minutesBookkeeping == "YES"
                                                      ? Colors.white
                                                      : Colors.grey,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  "YES",
                                                  style: TextStyle(
                                                    color: minutesBookkeeping == "YES"
                                                        ? Colors.white
                                                        : Colors.black54,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      /// NO BUTTON
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() => minutesBookkeeping = "NO");
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            decoration: BoxDecoration(
                                              color: minutesBookkeeping == "NO"
                                                  ? Colors.red
                                                  : Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: minutesBookkeeping == "NO"
                                                    ? Colors.red
                                                    : Colors.grey.shade300,
                                                width: 1.2,
                                              ),
                                              boxShadow: minutesBookkeeping == "NO"
                                                  ? [
                                                      BoxShadow(
                                                        color: Colors.red.withValues(alpha: 0.2),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 3),
                                                      )
                                                    ]
                                                  : [],
                                            ),
                                            child: Column(
                                              children: [
                                                Icon(
                                                  Icons.cancel,
                                                  size: 20,
                                                  color: minutesBookkeeping == "NO"
                                                      ? Colors.white
                                                      : Colors.grey,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  "NO",
                                                  style: TextStyle(
                                                    color: minutesBookkeeping == "NO"
                                                        ? Colors.white
                                                        : Colors.black54,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            /// AGENDA DISCUSSED (DISTINCT STYLE)
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E1), // light warm color
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  const Text(
                                    "Agenda Discussed",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  TextField(
                                    controller: agendaController,
                                    minLines: 3,
                                    maxLines: 5,
                                    decoration: InputDecoration(
                                      hintText: "Enter agenda discussed...",
                                      filled: true,
                                      fillColor: Colors.white,

                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: Colors.orange.shade200),
                                      ),

                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: Colors.orange.shade200),
                                      ),

                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                          color: Colors.orange,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            /// REMARKS (TEXTAREA)
                            TextField(
                              controller: remarksController,
                              minLines: 3,
                              maxLines: 5,
                              decoration: InputDecoration(
                                labelText: "Remarks/Appeal (Optional)",
                                alignLabelWithHint: true,
                                filled: true,
                                fillColor: Colors.white, // cleaner look

                                /// 👇 DEFAULT BORDER
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),

                                /// 👇 WHEN NOT FOCUSED
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),

                                /// 👇 WHEN FOCUSED
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: primaryBlue,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        gradient: const LinearGradient(
                        colors: [
                          Color(0xFF11998E),
                          Color(0xFF38EF7D),
                        ],
                      ),
                      ),
                      

                      /// PHOTO CARD
                      modernSectionCard(
                        "Meeting Photo",
                        icon: Icons.camera_alt,
                        Column(
                          children: [

                            Stack(
                              children: [

                                /// CAPTURE BUTTON
                                if (meetingPhoto == null)
                                  GestureDetector(
                                    onTap: capturePhoto,
                                    child: Container(
                                      height: 140,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFEAF3FF),
                                            Color(0xFFDCEBFF),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.blue.shade200),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [

                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: .1),
                                                  blurRadius: 6,
                                                )
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt,
                                              size: 26,
                                              color: primaryBlue,
                                            ),
                                          ),

                                          const SizedBox(height: 10),

                                          const Text(
                                            "Tap to Capture Photo",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),

                                          const SizedBox(height: 4),

                                          const Text(
                                            "Required for submission",
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                /// LOADER
                                if (photoLoading)
                                  Positioned.fill(
                                    child: Container(
                                      height: 110,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: .2),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            /// PHOTO DISPLAY
                            if (meetingPhoto != null) ...[
                              const SizedBox(height: 16),

                              Stack(
                                children: [

                                  /// IMAGE
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      meetingPhoto!,
                                      height: 220,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),

                                  /// ❌ DELETE BUTTON
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          meetingPhoto = null;
                                          latitude = null;
                                          longitude = null;
                                          capturedAt = null;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.6),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              /// DATE TIME
                              if (capturedAt != null)
                                Text(
                                  "Captured at: ${capturedAt!.day.toString().padLeft(2,'0')}-${capturedAt!.month.toString().padLeft(2,'0')}-${capturedAt!.year} "
                                  "${(capturedAt!.hour % 12 == 0 ? 12 : capturedAt!.hour % 12).toString().padLeft(2,'0')}:${capturedAt!.minute.toString().padLeft(2,'0')} "
                                  "${capturedAt!.hour >= 12 ? 'PM' : 'AM'}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),

                              const SizedBox(height: 6),

                              /// LOCATION
                              if (latitude != null)
                                Text(
                                  "Lat: ${latitude!.toStringAsFixed(5)}   Lng: ${longitude!.toStringAsFixed(5)}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                            ]
                                ],
                              ),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF4FACFE),
                                  Color(0xFF00F2FE),
                                ],
                              ),
                          ),
                

                      const SizedBox(height: 10),

                      /// SUBMIT BUTTON
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isOnline
                                ? [
                                    Color(0xFFFF6F00), // strong amber
                                    Color(0xFFFF8F00), // rich orange
                                    Color(0xFFFFA000), // warm highlight
                                  ]
                                : [
                                    Colors.orange,
                                    Colors.deepOrange,
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ElevatedButton(
                          onPressed: loading
                              ? null
                              : () async {
                                  if (isOnline) {
                                    await submitMeeting();
                                  } else {
                                    await saveOfflineOnly();
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: loading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  isOnline ? "Submit Meeting" : "Save Offline",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Divider(height: 24),

                      /// DASHBOARD LINK (Secondary action)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Center(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: openDashboard,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [

                                  Icon(
                                    Icons.dashboard_outlined,
                                    size: 18,
                                    color: primaryBlue,
                                  ),

                                  SizedBox(width: 6),

                                  Text(
                                    "Open Monitoring Dashboard",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (loading)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ],
            ),
        ),
      ),
  ),
    );
  }
}