// ---- NO CHANGES ON IMPORTS ----
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'LoginScreen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with SingleTickerProviderStateMixin {
  bool isLoading = true;
  Map<String, dynamic>? userData;
  String finalImageUrl = "";
  String finalAadharUrl = "";

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    fetchUser();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String safeDate(dynamic value) {
    if (value == null) return "";
    String d = value.toString();
    return (d.length >= 10) ? d.substring(0, 10) : d;
  }

  Future<void> fetchUser() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");

      final url = Uri.parse("https://stafftally.com/api/staff/me");
      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        userData = body["user"];

        finalImageUrl =
        "https://stafftally.com/storage/${userData?["profile_photo"]}";
        finalAadharUrl =
        "https://stafftally.com/storage/${userData?["aadhar_image"]}";
      }

      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    try {
      await http.post(
        Uri.parse("https://stafftally.com/api/staff/logout"),
        headers: {"Authorization": "Bearer $token"},
      );
    } catch (_) {}

    await prefs.remove("token");

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
    );
  }

  // ------------------ UI HELPERS ---------------------

  Widget sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Color(0xFF1565C0), size: 22),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1565C0),
          ),
        ),
      ],
    );
  }

  Widget infoTile(String label, String value, {IconData? icon}) {
    if (value.isEmpty || value == "null") return SizedBox();

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.09),
            blurRadius: 10,
            offset: Offset(1, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          if (icon != null)
            Icon(icon, color: Color(0xFF1976D2), size: 20),
          if (icon != null) SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    )),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      margin: EdgeInsets.only(bottom: 25),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.12),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [sectionHeader(title, icon), SizedBox(height: 12), ...children],
      ),
    );
  }

  // ------------------ MAIN BUILD ---------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF4F6FA),

      appBar: AppBar(
        backgroundColor: Color(0xFFEFF4FF),
        elevation: 0,
        title: Text(
          "My Profile",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),

      body: isLoading
          ? _leaveShimmerUI()
          : userData == null
          ? Center(child: Text("Unable to load profile"))
          : SingleChildScrollView(
        padding: EdgeInsets.all(18),
        child: Column(
          children: [
            // ----------- PROFILE CARD -----------
            AnimatedContainer(
              duration: Duration(milliseconds: 400),
              padding: EdgeInsets.all(25),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFEFF4FF),
                    Color(0xFFE7F0FF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade100.withOpacity(0.4),
                    blurRadius: 25,
                    offset: Offset(0, 10),
                  ),
                ],
              ),

              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) {
                      return Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.withOpacity(0.12),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF1E88E5)
                                  .withOpacity(0.25 + (_controller.value * 0.15)),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 55,
                          backgroundColor: Colors.white,
                          backgroundImage: NetworkImage(
                            finalImageUrl.isNotEmpty
                                ? finalImageUrl
                                : "https://i.postimg.cc/8P5YzG1L/user-placeholder.png",
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 15),

                  Text(
                    userData?["name"] ?? "",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  SizedBox(height: 6),

                  Text(
                    userData?["email"] ?? "",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 25),

            // ------------ SECTIONS ------------
            buildSection("Personal Information", Icons.person_outline, [
              infoTile("Full Name", userData?["name"] ?? "", icon: Icons.person),
              infoTile("Email", userData?["email"] ?? "", icon: Icons.email),
              infoTile("Mobile Number", userData?["mobile_number"] ?? "",
                  icon: Icons.phone),
              infoTile("Home Address", userData?["home_address"] ?? "",
                  icon: Icons.home),
              infoTile("Working Address", userData?["working_address"] ?? "",
                  icon: Icons.work),
            ]),

            buildSection("Job Details", Icons.assignment, [
              infoTile("Job Title", userData?["job_title"] ?? "",
                  icon: Icons.assignment),
              infoTile("Department", userData?["department"] ?? "",
                  icon: Icons.account_tree),
              infoTile("Joining Date", safeDate(userData?["joining_date"]),
                  icon: Icons.calendar_month),
              infoTile("End Date", safeDate(userData?["end_date"]),
                  icon: Icons.event_busy),
            ]),

            buildSection("Payroll Information", Icons.payments, [
              infoTile("Pay Rate", "₹${userData?["pay_rate"] ?? ""}",
                  icon: Icons.currency_rupee),
              infoTile("Last Increase Amount",
                  "₹${userData?["last_increase_amount"] ?? ""}",
                  icon: Icons.trending_up),
              infoTile("Last Increase Date",
                  safeDate(userData?["last_increase_date"]),
                  icon: Icons.date_range),
            ]),

            buildSection("Shift & Education", Icons.access_time, [
              infoTile("Shift Start Time",
                  userData?["shift_start_time"] ?? "",
                  icon: Icons.schedule),
              infoTile("Shift End Time",
                  userData?["shift_end_time"] ?? "",
                  icon: Icons.access_time),
              infoTile("Education Details",
                  userData?["education_details"] ?? "",
                  icon: Icons.school),  infoTile("Education Details",
                  userData?["education_details"] ?? "",
                  icon: Icons.school),
            ]),
            if (finalAadharUrl.isNotEmpty)
              buildSection("Aadhar Document", Icons.credit_card, [
                // ClipRRect(
                //   borderRadius: BorderRadius.circular(12),
                //   child: Image.network(
                //     finalAadharUrl,
                //     height: 180,
                //     fit: BoxFit.cover,
                //   ),
                // ),
              ]),

            // Add space before bottom button
            SizedBox(
                height:
                MediaQuery.of(context).padding.bottom + 100),
          ],
        ),
      ),

      // ------- LOGOUT BUTTON -------
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    "Logout",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _leaveShimmerUI() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: 6, // number of shimmer cards
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                // Header shimmer
                Container(
                  height: 70,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                ),

                // Body shimmer
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Duration Box shimmer
                      Container(
                        height: 80,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Reason shimmer
                      Container(
                        height: 90,
                        width: double.infinity,
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
}
