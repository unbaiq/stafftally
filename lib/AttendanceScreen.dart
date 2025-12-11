import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool isLoading = true;
  List attendanceList = [];
  List filteredList = [];
  Map<String, dynamic>? userData;
  String selectedFilter = "Month";
  final List<String> filterOptions = ["Week", "Month", "Year", "Date"];
  double monthlySalary = 5000;
  DateTime? selectedDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    fetchAttendanceList();
    fetchUser();
  }

  @override
  void dispose() {
    super.dispose();
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

        // finalImageUrl =
        // "https://stafftally.com/storage/${userData?["profile_photo"]}";
        // finalAadharUrl =
        // "https://stafftally.com/storage/${userData?["aadhar_image"]}";
      }

      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
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
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
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
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2)).then((_) {
      try {
        entry.remove();
      } catch (_) {}
    });
  }

  // modern single-date bottom sheet picker
  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),

      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue, // Header color
              onPrimary: Colors.white, // Header text
              onSurface: Colors.black, // Body text
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue, // Buttons color
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              headerHeadlineStyle: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              dayStyle: const TextStyle(fontSize: 16),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  // ---------- Days in Month ----------
  int _daysInMonth(int year, int month) {
    DateTime first = DateTime(year, month, 1);
    DateTime next =
        (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    return next.difference(first).inDays;
  }

  // ---------- Count Sundays in a Month ----------
  int countSundaysInMonth(int year, int month) {
    int count = 0;
    DateTime date = DateTime(year, month, 1);
    while (date.month == month) {
      if (date.weekday == DateTime.sunday) count++;
      date = date.add(const Duration(days: 1));
    }
    return count;
  }

  // ---------- Working Days in Month (totalDays - Sundays) ----------
  int getWorkingDays(int year, int month) {
    final int totalDays = _daysInMonth(year, month);
    final int sundays = countSundaysInMonth(year, month);
    final int working = totalDays - sundays;
    return working > 0 ? working : totalDays;
  }

  // ---------- Count Sundays Between Dates ----------
  int countSundaysBetween(DateTime start, DateTime end) {
    if (end.isBefore(start)) return 0;
    int cnt = 0;
    DateTime d = DateTime(start.year, start.month, start.day);
    while (!d.isAfter(end)) {
      if (d.weekday == DateTime.sunday) cnt++;
      d = d.add(const Duration(days: 1));
    }
    return cnt;
  }
  int getWorkingDaysBetween(DateTime start, DateTime end) {
    if (end.isBefore(start)) return 0;
    final int total = end.difference(start).inDays + 1;
    final int sundays = countSundaysBetween(start, end);
    final int working = total - sundays;
    return working > 0 ? working : total;
  }

  // ---------- Paid Leave Rule ----------
  Map<String, int> applyPaidLeaveRule(Map<String, int> summary) {
    final s = {
      "full": summary["full"] ?? 0,
      "late": summary["late"] ?? 0,
      "half": summary["half"] ?? 0,
      "absent": summary["absent"] ?? 0,
      "leave": summary["leave"] ?? 0,
    };

    int leave = s["leave"]!;

    if (leave <= 1) return s;

    // more than 1 leave → extra leaves become ABSENT
    int extra = leave - 1;
    s["leave"] = 1;
    s["absent"] = s["absent"]! + extra;

    return s;
  }


  double calculateSalaryForFiltered() {
    // Determine start & end for selected period
    DateTime now = DateTime.now();
    DateTime periodStart;
    DateTime periodEnd;

    if (selectedFilter == "Week") {
      periodEnd = now;
      periodStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6));
    } else if (selectedFilter == "Month") {
      // use selectedDate's month if chosen else current month
      final DateTime base = selectedDate ?? now;
      periodStart = DateTime(base.year, base.month, 1);
      periodEnd = DateTime(
        base.year,
        base.month,
        _daysInMonth(base.year, base.month),
      );
    } else if (selectedFilter == "Year") {
      final DateTime base = selectedDate ?? now;
      periodStart = DateTime(base.year, 1, 1);
      periodEnd = DateTime(base.year, 12, 31);
    } else if (selectedFilter == "Date" && selectedDate != null) {
      periodStart = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
      );
      periodEnd = periodStart;
    } else {

      periodStart = DateTime(now.year, now.month, 1);
      periodEnd = DateTime(
        now.year,
        now.month,
        _daysInMonth(now.year, now.month),
      );
    }

    // Get working days for the period
    final int workingDaysInPeriod = getWorkingDaysBetween(
      periodStart,
      periodEnd,
    );
    final int workingDaysInStartMonth = getWorkingDays(
      periodStart.year,
      periodStart.month,
    );
    final summaryRaw = getAttendanceSummaryForFiltered();
    final summary = applyPaidLeaveRule(
      summaryRaw,
    );


    final double perDay =
        (workingDaysInStartMonth > 0)
            ? (monthlySalary / workingDaysInStartMonth)
            : (monthlySalary /
                (workingDaysInPeriod > 0 ? workingDaysInPeriod : 1));

    double totalPay = 0;
    totalPay += summary["full"]! * perDay;
    totalPay += summary["late"]! * perDay; // late considered full pay here
    totalPay += summary["half"]! * (perDay * 0.5);
    totalPay += summary["leave"]! * perDay; // paid leaves counted
    totalPay -= summary["absent"]! * perDay;

    if (totalPay < 0) totalPay = 0;
    return totalPay;
  }

  // ---------- Paid-leave rule (if not present already) ----------

  Future<void> fetchAttendanceList() async {
    setState(() => isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final url = Uri.parse("https://stafftally.com/api/attendance/list");

    try {
      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        attendanceList = jsonData["data"] ?? [];
        applyFilters();
      } else {
        attendanceList = [];
        filteredList = [];
      }
    } catch (e) {
      attendanceList = [];
      filteredList = [];
    } finally {
      setState(() => isLoading = false);
    }
  }

  DateTime? getRecordDate(Map item) {
    // try item['date']
    String? raw = item['date']?.toString();
    if (raw != null && raw.isNotEmpty) {
      DateTime? dt = _tryParseDate(raw);
      if (dt != null) return dt;
    }

    // try check_in_time (may include full datetime or time-only)
    String? ci = item['check_in_time']?.toString();
    if (ci != null && ci.isNotEmpty) {
      DateTime? dt = _tryParseDate(ci);
      if (dt != null) return dt;
      // if time-only like "10:18:28" construct today with that time
      if (RegExp(r'^\d{2}:\d{2}(:\d{2})?$').hasMatch(ci.trim())) {
        final parts = ci.split(':');
        int h = int.parse(parts[0]);
        int m = parts.length > 1 ? int.parse(parts[1]) : 0;
        DateTime now = DateTime.now();
        return DateTime(now.year, now.month, now.day, h, m);
      }
    }

    String? co = item['check_out_time']?.toString();
    if (co != null && co.isNotEmpty) {
      DateTime? dt = _tryParseDate(co);
      if (dt != null) return dt;
    }

    // try created_at
    String? created = item['created_at']?.toString();
    if (created != null && created.isNotEmpty) {
      DateTime? dt = _tryParseDate(created);
      if (dt != null) return dt;
    }

    return null;
  }

  DateTime? _tryParseDate(String raw) {
    try {
      return DateTime.parse(raw);
    } catch (_) {
      try {
        return DateTime.parse(raw.split(' ').first);
      } catch (_) {
        return null;
      }
    }
  }

  void applyFilters() {
    DateTime now = DateTime.now();

    filteredList =
        attendanceList.where((item) {
          if (item == null) return false;
          // ensure Map
          if (item is! Map) return false;

          DateTime? recordDate = getRecordDate(item);

          if (recordDate == null) {
            return true;
          }

          if (selectedFilter == "Week") {
            DateTime now = DateTime.now();

            // Week: Monday → Sunday
            DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));
            DateTime weekEnd = weekStart.add(const Duration(days: 6));

            return recordDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
                recordDate.isBefore(weekEnd.add(const Duration(days: 1)));
          }

          else if (selectedFilter == "Month") {
            return recordDate.month == now.month && recordDate.year == now.year;
          } else if (selectedFilter == "Year") {
            return recordDate.year == now.year;
          } else if (selectedFilter == "Date") {
            if (selectedDate == null) return false;
            DateTime dClean = DateTime(
              recordDate.year,
              recordDate.month,
              recordDate.day,
            );
            DateTime sClean = DateTime(
              selectedDate!.year,
              selectedDate!.month,
              selectedDate!.day,
            );
            return dClean.isAtSameMomentAs(sClean);
          }

          return false;
        }).toList();

    filteredList.sort((a, b) {
      DateTime da = getRecordDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      DateTime db = getRecordDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });

    setState(() {});
  }

  String calculateDayType(String? checkInTime) {
    if (checkInTime == null) return "ABSENT";

    final s = checkInTime.toString().trim();
    if (s.isEmpty || s == "00:00:00" || s.toLowerCase() == "null") {
      return "ABSENT";
    }

    try {
      DateTime checkIn;

      if (RegExp(r'^\d{2}:\d{2}(:\d{2})?$').hasMatch(s)) {
        final parts = s.split(':');
        int h = int.parse(parts[0]);
        int m = int.parse(parts[1]);
        DateTime now = DateTime.now();
        checkIn = DateTime(now.year, now.month, now.day, h, m);
      } else {
        checkIn = DateTime.parse(s);
      }

      DateTime grace = DateTime(checkIn.year, checkIn.month, checkIn.day, 10, 15);
      DateTime halfLimit =
      DateTime(checkIn.year, checkIn.month, checkIn.day, 10, 30);

      if (checkIn.isAfter(halfLimit)) return "HALF DAY PRESENT";
      if (checkIn.isAfter(grace)) return "LATE PRESENT";
      return "PRESENT";
    } catch (_) {
      return "ABSENT";
    }
  }


  Map<String, int> getAttendanceSummaryForFiltered() {
    int full = 0, late = 0, half = 0, absent = 0, leave = 0;

    for (var item in filteredList) {
      if (item == null || item is! Map) continue;

      String status = (item['status'] ?? "").toString().toLowerCase();
      String type = calculateDayType(item['check_in_time']);
      DateTime? recordDate = getRecordDate(item);

      // LEAVE
      if (status == "leave") {
        leave++;
        continue;
      }

      // API Absent
      if (status == "absent") {
        absent++;
        continue;
      }

      // No check-in = Absent
      if (item['check_in_time'] == null ||
          item['check_in_time'].toString().trim().isEmpty ||
          item['check_in_time'] == "00:00:00" ||
          item['check_in_time'].toString().toLowerCase() == "null") {
        absent++;
        continue;
      }

      if (recordDate == null) {
        absent++;
        continue;
      }

      // Count attendance
      if (type == "PRESENT")
        full++;
      else if (type == "LATE PRESENT")
        late++;
      else if (type == "HALF DAY PRESENT")
        half++;
      else
        absent++;
    }

    // Apply paid leave rule
    int paidLeave = (leave >= 1) ? 1 : leave;
    int unpaidLeave = (leave > 1) ? leave - 1 : 0;
    absent += unpaidLeave;
    int totalAttendance = full + late + half + paidLeave;
    return {
      "full": full,
      "late": late,
      "half": half,
      "leave": leave,
      "paidLeave": paidLeave,
      "absent": absent,
      "totalAttendance": totalAttendance,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFEFF4FF),
        automaticallyImplyLeading: false,
        title: const Text(
          "Attendance Records",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        actions: [
          InkWell(
            onTap: showAttendanceReport,
            child: Row(
              children:  [
                Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: Text(
                    "Report",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Image.asset("assets/icons8-report-24.png"),
                // Icon(Icons.report_problem, color: Colors.black, size: 24),
                SizedBox(width: 12),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: isLoading
                ? _filterShimmerUI()   // 🔥 Show shimmer when loading
                : Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Filter dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: DropdownButton<String>(
                        value: selectedFilter,
                        underline: const SizedBox(),
                        items: filterOptions
                            .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e),
                        ))
                            .toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() {
                            selectedFilter = val;
                          });
                        },
                      ),
                    ),

                    const SizedBox(width: 12),

                    // APPLY BUTTON
                    ElevatedButton(
                      onPressed: () async {
                        setState(() => isLoading = true);

                        await Future.delayed(const Duration(milliseconds: 500));

                        if (selectedFilter != "Date") {
                          selectedDate = null;
                        }

                        applyFilters();

                        setState(() => isLoading = false);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Apply",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),


                    const SizedBox(width: 12),
                    // REFRESH
                    InkWell(
                      onTap: () {
                        selectedDate = null;
                        selectedFilter = "Month";
                        fetchAttendanceList();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.refresh),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // DATE PICKER (only for Date filter)
                if (selectedFilter == "Date")
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: InkWell(
                      onTap: pickDate,
                      child: Container(
                        width: 250,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 8),
                            Text(
                              selectedDate == null
                                  ? "Select Date Attendance"
                                  : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child:
                isLoading
                    ? _loadingUI()
                    : filteredList.isEmpty
                    ? _emptyUI()
                    : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        18,
                        18,
                        18,
                        MediaQuery.of(context).padding.bottom + 100,
                      ),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        return _attendanceCard(
                          filteredList[index] as Map<String, dynamic>,
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _filterShimmerUI() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(width: 120, height: 48, decoration: _shimmerBox()),
              Container(width: 90, height: 48, decoration: _shimmerBox()),
              Container(width: 48, height: 48, decoration: _shimmerBox()),
            ],
          ),
          const SizedBox(height: 12),
          Container(width: 250, height: 48, decoration: _shimmerBox()),
        ],
      ),
    );
  }

  BoxDecoration _shimmerBox() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    );
  }

  Widget _loadingUI() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        itemCount: 8, // number of shimmer cards
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // title bar
                Container(
                  height: 18,
                  width: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),

                // subtitle line
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),

                // subtitle line 2
                Container(
                  height: 14,
                  width: MediaQuery.of(context).size.width * 0.6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),

                // status button shimmer
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 80,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  // CARD
  Widget _attendanceCard(Map item) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item['date'] ?? _formatDateFromCheckIn(item['check_in_time']),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.blue.shade900,
                  ),
                ),
                buildStatusBadge(item as Map<String, dynamic>),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xffeef3f9),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_filled,
                    color: Colors.blue.shade700,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Check-In",
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          item['check_in_time'] ?? "--",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1.5,
                    height: 34,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Check-Out",
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          item['check_out_time'] ?? "--",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            attendanceImageRow(item['check_in_image'], item['check_out_image']),
          ],
        ),
      ),
    );
  }

  Widget buildStatusBadge(Map<String, dynamic> item) {
    String type = calculateDayType(item['check_in_time']);
    Color color = Colors.blue;

    if (type == "PRESENT") color = Colors.green;
    if (type == "LATE PRESENT") color = Colors.orange;
    if (type == "HALF DAY PRESENT") color = Colors.red;
    if (type == "ABSENT") color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        type.replaceAll("_", " "),
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatDateFromCheckIn(String? checkIn) {
    if (checkIn == null) return "";
    try {
      DateTime dt = DateTime.parse(checkIn);
      return "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    } catch (e) {
      return checkIn.split(' ').first;
    }
  }

  // IMAGE ROW
  Widget attendanceImageRow(String? checkInImg, String? checkOutImg) {
    String? checkInUrl =
        checkInImg != null && checkInImg.isNotEmpty
            ? "https://stafftally.com/storage/$checkInImg"
            : null;
    String? checkOutUrl =
        checkOutImg != null && checkOutImg.isNotEmpty
            ? "https://stafftally.com/storage/$checkOutImg"
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              "Check-In",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            Text(
              "Check-Out",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _imageBox(checkInUrl)),
            const SizedBox(width: 14),
            Expanded(child: _imageBox(checkOutUrl)),
          ],
        ),
      ],
    );
  }

  Widget _imageBox(String? url) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child:
            url == null
                ? Container(
                  color: Colors.grey.shade300,
                  alignment: Alignment.center,
                  child: const Text("No Image"),
                )
                : GestureDetector(
                  onTap: () => _openImagePreview(url),
                  child: Image.network(url, fit: BoxFit.cover),
                ),
      ),
    );
  }

  void _openImagePreview(String url) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          backgroundColor: Colors.transparent,
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 80, color: Colors.blue.shade400),
          const SizedBox(height: 15),
          const Text(
            "No Attendance Found",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            "Your attendance records will appear here.",
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // REPORT
  void showAttendanceReport() {
    final s = getAttendanceSummaryForFiltered();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.45,
          maxChildSize: 0.90,
          builder: (_, controller) {
            return Container(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
              child: Column(
                children: [
                  // TOP HANDLE
                  Container(
                    width: 50,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),

                  Text(
                    "$selectedFilter Attendance Report",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff0D47A1),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Expanded(
                    child: ListView(
                      controller: controller,
                      children: [

                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade50,
                                Colors.blue.shade100.withOpacity(0.4),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade100.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _dashStat("PRESENT", s["full"]!, Colors.green, ),
                                  _dashStat("LATE PRESENT", s["late"]!, Colors.orange, ),
                                  _dashStat("HALF DAY", s["half"]!, Colors.red, ),
                                  _dashStat("PAID LEAVE", s["paidLeave"]!, Colors.blue),
                                  _dashStat("ABSENT", s["absent"]!, Colors.redAccent,),
                                ],
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade50,
                                Colors.blue.shade100.withOpacity(0.4),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade100.withOpacity(0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Summary",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // TOTAL ATTENDANCE ROW
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Total Attendance Count",
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    "${s["totalAttendance"]}",
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // TOTAL LEAVE REQUESTED ROW
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Total Leave Requested",
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    "${s["leave"]}",
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        // BUTTON ROW
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade300,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text(
                                  "Close",
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: ElevatedButton(
                                onPressed: _downloadPDF,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text(
                                  "Download PDF",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  Widget _dashStat(String title, int value, Color color,) {
  return Container(
  width: (MediaQuery.of(context).size.width / 2) - 50,
  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
  decoration: BoxDecoration(
  color: color.withOpacity(0.10),
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: color.withOpacity(0.25), width: 1),
  ),
  child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  const SizedBox(height: 8),
  Text(
  value.toString(),
  style: TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.bold,
  color: color,
  ),
  ),
  const SizedBox(height: 4),
  Text(
  title,
  style: const TextStyle(
  fontSize: 14,
  color: Colors.black87,
  fontWeight: FontWeight.w600,
  ),
  ),
  ],
  ),
  );
  }

  Future<void> _downloadPDF() async {
    try {
      final s = getAttendanceSummaryForFiltered();


      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [

                // ---------------- HEADER -----------------
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        "StaffTally Attendance Slip",
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "($selectedFilter Report)",
                        style: pw.TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // ---------------- BASIC DETAILS BOX -----------------
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey600),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Employee Name: ${ userData?["name"] ?? "Not Available Staff" }"),
                      pw.SizedBox(height: 6),
                      pw.Text("Generated On: ${DateTime.now().toString().split('.')[0]}"),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // ---------------- TABLE STYLE SUMMARY -----------------
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey600),
                  columnWidths: {
                    0: pw.FlexColumnWidth(2),
                    1: pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            "Attendance Type",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            "Count",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    _tableRow("Present", s["full"]!),
                    _tableRow("Late Present", s["late"]!),
                    _tableRow("Half Day", s["half"]!),
                    _tableRow("Paid Leave", s["paidLeave"]!),
                    _tableRow("Absent", s["absent"]!),
                  ],
                ),

                pw.SizedBox(height: 20),

                // ---------------- SUMMARY TABLE -----------------
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey600),
                  columnWidths: {
                    0: pw.FlexColumnWidth(2),
                    1: pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            "Summary",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text("Value"),
                        ),
                      ],
                    ),

                    _tableRow("Total Attendance", s["totalAttendance"]!),
                    _tableRow("Total Leave Requested", s["leave"]!),
                  ],
                ),

                pw.SizedBox(height: 40),

                // ---------------- SIGNATURE AREA -----------------
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text("${ userData?["name"] ?? "Not Available Staff" }"),
                        pw.Text("Employee Signature"),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text("__________________"),
                        pw.Text("Verifier Signature"),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      // SAVE & SHARE
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: "attendance_slip.pdf",
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("PDF failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// ---------------- TABLE ROW HELPER -----------------
  pw.TableRow _tableRow(String title, int value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(title),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value.toString()),
        ),
      ],
    );
  }



}
