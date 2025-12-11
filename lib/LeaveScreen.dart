import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen>
    with SingleTickerProviderStateMixin {
  bool isLoading = true;
  List leaves = [];

  @override
  void initState() {
    super.initState();
    fetchLeaves();
  }

  Future<void> fetchLeaves() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");

      final url = Uri.parse("https://stafftally.com/api/leave/list");

      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          leaves = body;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return Colors.green;
      case "rejected":
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return Icons.check_circle_rounded;
      case "rejected":
        return Icons.cancel_rounded;
      default:
        return Icons.access_time_filled_rounded;
    }
  }

  String formatDate(String date) {
    try {
      final d = DateTime.parse(date);
      return "${d.day.toString().padLeft(2, '0')} "
          "${_monthNames[d.month]} ${d.year}";
    } catch (e) {
      return date;
    }
  }

  final List<String> _monthNames = [
    "",
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffeef2f7),

      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          "My Leaves",
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
        ),
        backgroundColor: const Color(0xFFEFF4FF),
      ),

      body:
          isLoading
              ? _leaveShimmerUI()
              : leaves.isEmpty
              ? _emptyStateUI()
              : SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ListView.builder(
                        padding: const EdgeInsets.all(18),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: leaves.length,
                        itemBuilder: (context, index) {
                          return _buildLeaveCard(leaves[index]);
                        },
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _leaveShimmerUI() {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: EdgeInsets.all(width * 0.04),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            margin: EdgeInsets.only(bottom: height * 0.02),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                // Header shimmer
                Container(
                  height: height * 0.08,
                  width: width,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.all(width * 0.05),
                  child: Column(
                    children: [
                      // Duration box
                      Container(
                        height: height * 0.10,
                        width: width,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      SizedBox(height: height * 0.02),

                      // Reason box
                      Container(
                        height: height * 0.12,
                        width: width,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeaveCard(Map leave) {
    final status = leave['status']?.toString().toLowerCase() ?? '';

    Color statusColor;
    switch (status) {
      case 'approved':
        statusColor = Colors.green.shade600;
        break;
      case 'rejected':
        statusColor = Colors.red.shade600;
        break;
      default:
        statusColor = Colors.amber.shade700;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ---------------- HEADER ------------------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Color(0xFFEFF4FF),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // LEFT: ICON + TITLE
                Row(
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.event_note_rounded,
                        color: Colors.black,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      "${leave['leave_type']?.toUpperCase() ?? 'UNKNOWN'} LEAVE",
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),

                SizedBox(width: 20,),
                Container(
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),

                  child: Row(
                    children: [
                      Icon(
                        getStatusIcon(status),
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 22,
                      color: statusColor,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "Duration",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Container(
                  padding: EdgeInsets.all(
                    MediaQuery.of(context).size.width * 0.04,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xfff1f5f9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.35,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(formatDate(leave['start_date'])),
                            Text("Start Date", style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),

                      Icon(Icons.arrow_forward_rounded, color: Colors.grey),

                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.30,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(formatDate(leave['end_date'])),
                            Text("End Date", style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // REASON
                Row(
                  children: [
                    Icon(Icons.notes_rounded, size: 22, color: statusColor),
                    const SizedBox(width: 10),
                    const Text(
                      "Reason",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xfff8fafc),
                    borderRadius: BorderRadius.circular(14),
                    border: Border(
                      left: BorderSide(color: statusColor, width: 4),
                    ),
                  ),
                  child: Text(
                    leave['reason'] ?? "No reason provided",
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyStateUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 90, color: Colors.blue.shade300),
          const SizedBox(height: 20),
          const Text(
            "No Leaves Found",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xff1e293b),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "You haven’t applied for any leaves yet.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
