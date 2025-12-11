import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  final _formKey = GlobalKey<FormState>();

  String? leaveType;
  DateTime? startDate;
  DateTime? endDate;
  final TextEditingController reasonCtrl = TextEditingController();

  bool isSubmitting = false;

  Future<void> pickDate({required bool isStart}) async {
    DateTime now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }
  void showTopSnackbar(String message, Color bgColor) {
    final overlay = Overlay.of(context);

    OverlayEntry entry = OverlayEntry(
      builder: (context) => Positioned(
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
                )
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

  Future<void> applyLeave() async {
    if (!_formKey.currentState!.validate()) return;

    if (startDate == null || endDate == null) {
      showTopSnackbar("Please select both dates", Colors.red);

      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text("Please select both dates")),
      // );
      return;
    }

    if (startDate!.isAfter(endDate!)) {
      showTopSnackbar("Start date cannot be after end date", Colors.red);

      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text("Start date cannot be after end date")),
      // );
      return;
    }

    setState(() => isSubmitting = true);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    final url = Uri.parse("https://stafftally.com/api/leave/apply");

    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "leave_type": leaveType,
        "start_date": startDate.toString().substring(0, 10),
        "end_date": endDate.toString().substring(0, 10),
        "reason": reasonCtrl.text.trim(),
      }),
    );

    setState(() => isSubmitting = false);

    if (response.statusCode == 200) {
      showTopSnackbar("Leave Applied Successfully", Colors.green);

      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text("Leave Applied Successfully")),
      // );
      Navigator.pop(context);
    } else {
      showTopSnackbar("Failed: ${response.body}", Colors.green);

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text("Failed: ${response.body}")),
      // );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F8),

      appBar: AppBar(
        backgroundColor: const Color(0xFFEFF4FF),
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          "Apply Leave",
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
        ),
        elevation: 3,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // FORM TITLE
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.description,
                          color: Colors.blue, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Leave Request Form",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ---------------- LEAVE TYPE -------------------
                const Text(
                  "Leave Type",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  decoration: _inputDecoration("Select leave type"),
                  value: leaveType,
                  items: const [
                    DropdownMenuItem(value: "sick", child: Text("Sick Leave")),
                    DropdownMenuItem(
                        value: "casual", child: Text("Casual Leave")),
                    DropdownMenuItem(value: "paid", child: Text("Paid Leave")),
                  ],
                  onChanged: (v) => setState(() => leaveType = v),
                  validator: (v) =>
                  v == null ? "Please select leave type" : null,
                ),

                const SizedBox(height: 20),

                // ---------------- START DATE -------------------
                _datePickerTile(
                  title: "Start Date",
                  value: startDate,
                  onTap: () => pickDate(isStart: true),
                ),

                const SizedBox(height: 20),

                // ---------------- END DATE ---------------------
                _datePickerTile(
                  title: "End Date",
                  value: endDate,
                  onTap: () => pickDate(isStart: false),
                ),

                const SizedBox(height: 20),

                // ---------------- REASON -----------------------
                const Text(
                  "Reason",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: reasonCtrl,
                  maxLines: 4,
                  decoration: _inputDecoration("Describe your reason"),
                  validator: (v) =>
                  v!.isEmpty ? "Reason is required" : null,
                ),

                const SizedBox(height: 30),

                // ---------------- SUBMIT BUTTON ----------------
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : applyLeave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      "Submit Leave Request",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
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

  /// ------------------- Input Decoration -----------------
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.blue.shade700, width: 1.8),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    );
  }

  /// ------------------- Date Picker Tile -----------------
  Widget _datePickerTile({
    required String title,
    required DateTime? value,
    required Function() onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),

        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month,
                    size: 22, color: Colors.blueGrey),
                const SizedBox(width: 12),
                Text(
                  value == null
                      ? "Select Date"
                      : value.toString().substring(0, 10),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}