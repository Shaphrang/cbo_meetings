//lib\features\meeting\screens\meeting_form_screen.dart
import 'package:flutter/material.dart';
import '../controller/master_controller.dart';
import 'meeting_capture_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';

class MeetingFormScreen extends StatefulWidget {
  const MeetingFormScreen({super.key});

  @override
  State<MeetingFormScreen> createState() => _MeetingFormScreenState();
}

class _MeetingFormScreenState extends State<MeetingFormScreen> {
  final MasterController controller = MasterController();

  static const Color primaryBlue = Color(0xFF1A73E8);

  String meetingType = "VO";

  /// ✅ DISPLAY VALUES
  String? selectedDistrict;
  String? selectedBlock;
  String? selectedVillage;
  String? selectedVO;
  String? selectedCLF;

  /// ✅ NEW: ID VALUES (CRITICAL)
  String? selectedDistrictId;
  String? selectedBlockId;

  List<String> districts = [];
  List<String> blocks = [];
  List<String> villages = [];
  List<String> vos = [];
  List<String> clfs = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      await controller.loadMasterData();

      if (!mounted) return;

      setState(() {
        districts = controller.getDistricts(meetingType);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load data: $e")),
      );
    }
  }

  void clearForm() {
    setState(() {
      meetingType = "VO";

      selectedDistrict = null;
      selectedBlock = null;
      selectedVillage = null;
      selectedVO = null;
      selectedCLF = null;

      selectedDistrictId = null;
      selectedBlockId = null;

      blocks.clear();
      villages.clear();
      vos.clear();
      clfs.clear();

      districts = controller.getDistricts(meetingType);
    });
  }

  void resetAll() {
    selectedDistrict = null;
    selectedBlock = null;
    selectedVillage = null;
    selectedVO = null;
    selectedCLF = null;

    selectedDistrictId = null;
    selectedBlockId = null;

    blocks.clear();
    villages.clear();
    vos.clear();
    clfs.clear();
  }

  void changeMeetingType(String value) {
    setState(() {
      meetingType = value;
      resetAll();
      districts = controller.getDistricts(meetingType);
    });
  }

  /// ------------------------------------------------------------
  /// VALIDATION + CONTINUE
  /// ------------------------------------------------------------
  Future<void> validateAndContinue() async {
    /// 🔴 VALIDATIONS (NO ASYNC → SAFE)
    if (selectedDistrict == null || selectedBlock == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select district and block")),
      );
      return;
    }

    if (selectedDistrictId == null || selectedBlockId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Internal error: Missing IDs")),
      );
      return;
    }

    if (meetingType == "VO" && selectedVillage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select village")),
      );
      return;
    }

    if (meetingType == "VO" && selectedVO == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select VO")),
      );
      return;
    }

    if (meetingType == "CLF" && selectedCLF == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select CLF")),
      );
      return;
    }

    /// 🔐 AUTH CHECK
    String? correctCode;

    if (meetingType == "VO") {
      correctCode = controller.getVOAuthCode(
        selectedDistrict!,
        selectedBlock!,
        selectedVillage!,
        selectedVO!,
      );
    } else {
      correctCode = controller.getCLFAuthCode(
        selectedDistrict!,
        selectedBlock!,
        selectedCLF!,
      );
    }

    if (correctCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Auth code not found")),
      );
      return;
    }

    /// 🔥 SHOW AUTH DIALOG
    final isVerified = await showAuthDialog(correctCode);

    if (!isVerified) return;

    /// 🔥 SAVE SESSION
    final box = Hive.box('session_box');

    await box.put('meeting_session', {
      "meetingType": meetingType,

      /// DISPLAY
      "district": selectedDistrict,
      "block": selectedBlock,
      "village": selectedVillage,
      "voName": selectedVO,
      "clfName": selectedCLF,

      /// IDS
      "district_id": selectedDistrictId,
      "block_id": selectedBlockId,
    });

    /// 🔥 CONTEXT SAFETY AFTER ASYNC
    if (!mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeetingCaptureScreen(
          meetingType: meetingType,

          /// DISPLAY
          district: selectedDistrict!,
          block: selectedBlock!,
          village: selectedVillage,
          voName: selectedVO,
          clfName: selectedCLF,

          /// IDS
          districtId: selectedDistrictId!,
          blockId: selectedBlockId!,
        ),
      ),
    );

    /// 🔥 AGAIN CONTEXT SAFETY
    if (!mounted) return;

    if (result == true) {
      clearForm();
      await box.delete('meeting_session');
    }
  }

  /// ------------------------------------------------------------
  /// UI COMPONENTS
  /// ------------------------------------------------------------

  Widget modernCard(String title, Widget child, {IconData? icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: primaryBlue),
                ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget meetingTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => changeMeetingType("VO"),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: meetingType == "VO"
                    ? const LinearGradient(
                        colors: [Color(0xFF2F6FED), Color(0xFF1A73E8)],
                      )
                    : null,
                color: meetingType == "VO"
                    ? null
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  "VO Meeting",
                  style: TextStyle(
                    color: meetingType == "VO"
                        ? Colors.white
                        : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => changeMeetingType("CLF"),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: meetingType == "CLF"
                    ? const LinearGradient(
                        colors: [Color(0xFF2F6FED), Color(0xFF1A73E8)],
                      )
                    : null,
                color: meetingType == "CLF"
                    ? null
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  "CLF Meeting",
                  style: TextStyle(
                    color: meetingType == "CLF"
                        ? Colors.white
                        : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget modernDropdown({
    required String label,
    required List<String> items,
    required String? value,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: items.contains(value) ? value : null,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          prefixIcon: Icon(icon, color: primaryBlue),
        ),
        items: items
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: items.isEmpty ? null : onChanged,
      ),
    );
  }

  Widget continueButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2F6FED), Color(0xFF38EF7D)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ElevatedButton(
        onPressed: validateAndContinue,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        child: const Text(
          "Continue",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<bool> showAuthDialog(String correctCode) async {
    final TextEditingController controller = TextEditingController();

    void showTopPopup(String message) {
      final overlay = Overlay.of(context);
      late OverlayEntry entry;

      entry = OverlayEntry(
        builder: (_) => Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () => entry.remove(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF5F6D), Color(0xFFFF8A65)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: const [
                    Icon(Icons.error_outline, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Incorrect code. Please try again.",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      overlay.insert(entry);

      Future.delayed(const Duration(seconds: 2), () {
        if (entry.mounted) entry.remove();
      });
    }

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    /// 🔵 HEADER
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        gradient: LinearGradient(
                          colors: [Color(0xFF2F6FED), Color(0xFF1A73E8)],
                        ),
                      ),
                      child: Column(
                        children: const [
                          Icon(Icons.lock, color: Colors.white, size: 26),
                          SizedBox(height: 6),
                          Text(
                            "Secure Access",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    /// BODY
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                      child: Column(
                        children: [

                          const Text(
                            "Enter the authentication code to continue",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Colors.black87,
                            ),
                          ),

                          const SizedBox(height: 16),

                          /// INPUT
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F7FB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: controller,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                hintText: "Enter Code",
                                border: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          /// BUTTONS
                          Row(
                            children: [

                              /// CANCEL
                              Expanded(
                                child: TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text(
                                    "Cancel",
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 10),

                              /// VERIFY (RED/ORANGE GRADIENT)
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFF512F),
                                        Color(0xFFFF9966),
                                      ],
                                    ),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (controller.text.trim() ==
                                          correctCode) {
                                        Navigator.pop(context, true);
                                      } else {
                                        showTopPopup(
                                            "Incorrect code. Please try again.");
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                    ),
                                    child: const Text(
                                      "Verify",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 6),
                  ],
                ),
              ),
            );
          },
        ) ??
        false;
  }

  /// ------------------------------------------------------------
  /// BUILD
  /// ------------------------------------------------------------
  @override
  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      centerTitle: true,
      title: Column(
        children: const [
          Text(
            "Government of Meghalaya",
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          SizedBox(height: 2),
          Text(
            "Meeting Capture",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.black87),
          onPressed: clearForm,
        )
      ],
    ),

    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFEAF3FF),
            Color(0xFFF7FAFF),
            Color(0xFFFFFFFF),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                child: ListView(
                  children: [

                    /// 🔹 MEETING TYPE
                    modernCard(
                      "Meeting Type",
                      meetingTypeSelector(),
                      icon: Icons.groups,
                    ),

                    /// 🔹 LOCATION
                    modernCard(
                      "Location Details",
                      Column(
                        children: [

                          /// DISTRICT
                          modernDropdown(
                            label: "District",
                            items: districts,
                            value: selectedDistrict,
                            icon: Icons.location_city,
                            onChanged: (value) {
                              if (value == null) return;

                              setState(() {
                                selectedDistrict = value;
                                selectedDistrictId =
                                    controller.getDistrictId(value);

                                selectedBlock = null;
                                selectedBlockId = null;

                                blocks =
                                    controller.getBlocks(meetingType, value);

                                villages.clear();
                                vos.clear();
                                clfs.clear();
                              });
                            },
                          ),

                          /// BLOCK
                          modernDropdown(
                            label: "Block",
                            items: blocks,
                            value: selectedBlock,
                            icon: Icons.map,
                            onChanged: (value) {
                              if (value == null) return;

                              setState(() {
                                selectedBlock = value;
                                selectedBlockId = controller.getBlockId(
                                    selectedDistrict!, value);

                                if (meetingType == "VO") {
                                  villages = controller.getVillages(
                                      selectedDistrict!, value);
                                } else {
                                  clfs = controller.getCLFs(
                                      selectedDistrict!, value);
                                }
                              });
                            },
                          ),

                          /// VO FLOW
                          if (meetingType == "VO") ...[
                            modernDropdown(
                              label: "Village",
                              items: villages,
                              value: selectedVillage,
                              icon: Icons.home,
                              onChanged: (value) {
                                if (value == null) return;

                                setState(() {
                                  selectedVillage = value;
                                  vos = controller.getVOs(
                                    selectedDistrict!,
                                    selectedBlock!,
                                    value,
                                  );
                                });
                              },
                            ),

                            modernDropdown(
                              label: "VO Name",
                              items: vos,
                              value: selectedVO,
                              icon: Icons.groups,
                              onChanged: (value) {
                                setState(() => selectedVO = value);
                              },
                            ),
                          ],

                          /// CLF FLOW
                          if (meetingType == "CLF")
                            modernDropdown(
                              label: "CLF Name",
                              items: clfs,
                              value: selectedCLF,
                              icon: Icons.account_balance,
                              onChanged: (value) {
                                setState(() => selectedCLF = value);
                              },
                            ),
                        ],
                      ),
                      icon: Icons.location_on,
                    ),

                    const SizedBox(height: 10),

                    /// 🔹 CONTINUE BUTTON
                    continueButton(),

                    const SizedBox(height: 30),

                    /// 🔹 LOGO (UNCHANGED - SAFE)
                    Center(
                      child: Column(
                        children: [
                          Image.asset(
                            "assets/images/msrls_logo.png",
                            height: 90,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Meghalaya State Rural Livelihoods Society",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    ),
  );
}
}