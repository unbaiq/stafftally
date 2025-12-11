import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'model/UserStaffModel.dart';

class CreateActivityScreen extends StatefulWidget {
  const CreateActivityScreen({super.key});

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  final activityName = TextEditingController();
  final description = TextEditingController();
  final startDate = TextEditingController();
  final dueDate = TextEditingController();

  bool isLoading = false;

  // ------------------- DATE PICKER -------------------
  Future<void> pickDate(TextEditingController controller) async {
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D47A1),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0D47A1),
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      controller.text =
      "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    }
  }
  void showTopSnackbar(String message, Color bgColor) {
    final overlay = Overlay.of(context);

    OverlayEntry entry = OverlayEntry(
      builder:
          (context) => Positioned(
        top: 40,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    Future.delayed(Duration(seconds: 2)).then((value) => entry.remove());
  }
  // ------------------- SUBMIT API -------------------
  Future<void> submitActivity() async {
    if (activityName.text.trim().isEmpty) {
      showTopSnackbar("Please enter activity name", Colors.red);
      return;
    }
    if (startDate.text.trim().isEmpty || dueDate.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text("Please select start and due dates"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),

          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    final body = {
      "subadmin_id": 1,
      "staff_id": 1,
      "activity_name": activityName.text.trim(),
      "description": description.text.trim(),
      "start_date": startDate.text.trim(),
      "due_date": dueDate.text.trim(),
      "status": "pending"
    };

    try {
      UserStaffModel? response = await ActivityService.createActivity(body);
      setState(() => isLoading = false);
      if (response != null) {
        // 👇 ONLY SUCCESS MESSAGE PRINT
      showTopSnackbar("Activity created successfully!", Colors.green);

        // Go back after short delay
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) Navigator.pop(context);
        });

      } else {

        showTopSnackbar("Something went wrong!", Colors.red);
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEFF4FF),
        elevation: 0,
        automaticallyImplyLeading: true,
        iconTheme: IconThemeData(color: Colors.black),
        toolbarHeight: 65,

        title: const Text(
          "Create Activity",
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            letterSpacing: 0.6,
          ),
        ),

        centerTitle: true,


      ),


      // ---------------- CONTENT -----------------
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 22),
        child: Center(
          child: Container(
            width: 480,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 25,
                  spreadRadius: 2,
                  offset: const Offset(0, 12),
                ),
              ],
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ------- HEADER ICON -------
                Row(
                  children:  [
                    Icon(Icons.assignment_rounded,
                        size: 32, color: Colors.blue.shade700),
                    SizedBox(width: 12),
                    Text(
                      "New Activity",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                cleanField("Activity Name", activityName),
                const SizedBox(height: 22),

                cleanField("Description", description, maxLines: 3),
                const SizedBox(height: 22),

                cleanDateField("Start Date", startDate),
                const SizedBox(height: 22),

                cleanDateField("Due Date", dueDate),
                const SizedBox(height: 34),

                // ------------ SUBMIT BUTTON ----------
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: submitActivity,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                        backgroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      "Submit Activity",
                      style: TextStyle(
                        fontSize: 18,
                        letterSpacing: 0.4,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ----------- CLEAN TEXTFIELD ------------------
  Widget cleanField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 6),

        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: "Enter $label",
            hintStyle: const TextStyle(color: Colors.black45),
            filled: true,
            fillColor: const Color(0xFFF8FAFE),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  // ----------- CLEAN DATE FIELD ------------------
  Widget cleanDateField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        const SizedBox(height: 6),

        TextField(
          controller: controller,
          readOnly: true,
          onTap: () => pickDate(controller),
          decoration: InputDecoration(
            hintText: "Select $label",
            hintStyle: const TextStyle(color: Colors.black45),
            filled: true,
            fillColor: const Color(0xFFF8FAFE),
            suffixIcon:  Icon(Icons.calendar_month_rounded,
                color: Colors.blue.shade700),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

/// API SERVICE
class ActivityService {
  static Future<UserStaffModel?> createActivity(
      Map<String, dynamic> data) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");
    if (token == null || token.trim().isEmpty) {
      debugPrint("ActivityService.createActivity: token is null");
      return null;
    }
    const url = "https://stafftally.com/api/staff/activities/create";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
        body: jsonEncode(data),
      );

      debugPrint("STATUS CODE: ${response.statusCode}");
      debugPrint("RESPONSE BODY: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return userStaffModelFromJson(response.body);
      } else {
        return null;
      }
    } catch (e) {
      debugPrint("ActivityService.createActivity error: $e");
      rethrow; // let UI catch it
    }
  }
}
