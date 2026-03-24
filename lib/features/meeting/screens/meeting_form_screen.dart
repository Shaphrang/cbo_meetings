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

  /// Modern Government Style Colors
  static const Color primaryBlue = Color(0xFF1A73E8);

  String meetingType = "VO";

  String? selectedDistrict;
  String? selectedBlock;
  String? selectedVillage;
  String? selectedVO;
  String? selectedCLF;

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

  /// SECTION CARD
  Widget modernCard(String title, Widget child, {IconData? icon}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.05),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// HEADER ROW
        Row(
          children: [
            if (icon != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(.1),
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

  /// MEETING TYPE SELECTOR
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

  /// MODERN DROPDOWN
  
  Future<void> validateAndContinue() async {
  if (selectedDistrict == null || selectedBlock == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please select district and block")),
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

  /// 🔥 SAVE SESSION
  final box = Hive.box('session_box');

  await box.put('meeting_session', {
    "meetingType": meetingType,
    "district": selectedDistrict,
    "block": selectedBlock,
    "village": selectedVillage,
    "voName": selectedVO,
    "clfName": selectedCLF,
  });

  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => MeetingCaptureScreen(
        meetingType: meetingType,
        district: selectedDistrict!,
        block: selectedBlock!,
        village: selectedVillage,
        voName: selectedVO,
        clfName: selectedCLF,
      ),
    ),
  );

    if (result == true) {
      clearForm();

      /// 🧹 CLEAR SESSION AFTER SUCCESS
      await box.delete('meeting_session');
    }
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
        value: items.contains(value) ? value : null,
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
      boxShadow: [
        BoxShadow(
          color: Colors.blue.withOpacity(.3),
          blurRadius: 10,
          offset: const Offset(0, 6),
        )
      ],
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

  @override
Widget build(BuildContext context) {
  return Scaffold(

    /// ✅ FIXED APPBAR POSITION
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

    /// ✅ ONLY ONE BODY
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),

          child: ListView(
            children: [

              /// ✅ MEETING TYPE
              modernCard(
                "Meeting Type",
                meetingTypeSelector(),
                icon: Icons.groups,
              ),

              /// ✅ LOCATION
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
                          selectedBlock = null;
                          selectedVillage = null;
                          selectedVO = null;
                          selectedCLF = null;

                          blocks = controller.getBlocks(meetingType, value);
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
                          selectedVillage = null;
                          selectedVO = null;
                          selectedCLF = null;

                          if (meetingType == "VO") {
                            villages = controller.getVillages(selectedDistrict!, value);
                          } else {
                            clfs = controller.getCLFs(selectedDistrict!, value);
                          }
                        });
                      },
                    ),

                    /// ✅ VILLAGE + VO
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
                        icon: Icons.groups_2,
                        onChanged: (value) {
                          setState(() => selectedVO = value);
                        },
                      ),
                    ],

                    /// ✅ CLF
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

              /// ✅ BUTTON
              continueButton(),

              const SizedBox(height: 30),

              /// ✅ LOGO
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