import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:staff/CreateActivityScreen.dart';
import 'model/StaffListModel.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final ScrollController scrollController = ScrollController();

  DateTime? selectedDate;
  List<TaksModel> taskList = [];
  bool isLoading = false;
  bool isUpdating = false;

  // Add near other fields
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  bool notificationsInitialized = false;

  @override
  void initState() {
    super.initState();

    // Initialize local notifications (for Android & iOS)

    _initLocalNotifications();
    // Load task list
    fetchTaskData();

    // Scroll listener
    scrollController.addListener(() {
      if (scrollController.position.pixels ==
          scrollController.position.maxScrollExtent) {
        print("Reached bottom!");
        fetchTaskData();
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("New Push: ${message.notification?.title}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.notification?.body ?? "New Task Added"),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      fetchTaskData();
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("🔗 Notification Clicked");
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TaskListScreen()),
      );
    });

    Timer.periodic(Duration(minutes: 1), (_) {
      fetchTaskData();
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  Map<String, int> getMonthlyCompletedCount() {
    Map<String, int> data = {};

    for (var t in taskList) {
      if (t.status.toLowerCase() == "completed") {
        String key = DateFormat("MMM yyyy").format(t.startDate);

        if (data.containsKey(key)) {
          data[key] = data[key]! + 1;
        } else {
          data[key] = 1;
        }
      }
    }
    return data;
  }

  void _initLocalNotifications() async {
    if (notificationsInitialized) return;

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('icon');

    final DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initSettings =
    InitializationSettings(android: androidSettings, iOS: iosSettings);

    await flutterLocalNotificationsPlugin.initialize(initSettings);
    notificationsInitialized = true;
  }

  // 4) fetchTasksRaw
  static Future<String> fetchTasksRaw() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");
    final url = Uri.parse("https://stafftally.com/api/staff/activities");
    final response = await http.get(
      url,
      headers: {"Authorization": "Bearer $token", "Accept": "application/json"},
    );
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception("Failed to load tasks");
    }
  }

  // 5) new fetchTaskData using raw fetch
  Future<void> fetchTaskData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // Fetch raw JSON
      String raw = await fetchTasksRaw();
      final decoded = jsonDecode(raw);

      // NEW LIST LENGTH
      int newLength = decoded.length;

      // OLD LIST LENGTH
      int? oldLength = prefs.getInt("task_length");

      bool changed = false;

      // Compare list length
      if (oldLength != null && oldLength != newLength) {
        changed = true;
      }

      // Update UI list
      taskList = taksModelFromJson(jsonEncode(decoded));

      // If changed => Notification
      if (changed) {
        await showLocalNotification(
          id: 1,
          title: "New Task Added",
          body: "A new task has been added in the dashboard.",
          payload: "task_update",
        );
        print("🔔 NEW DATA DETECTED");
      }

      // Save new length
      await prefs.setInt("task_length", newLength);

    } catch (e) {
      print("Error: $e");
    }

    if (!mounted) return;
    setState(() => isLoading = false);
  }


  // 6) showLocalNotification function (same as earlier)
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'task_channel',
      'Task Updates',
      channelDescription: 'Notifications for task updates',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
      icon: 'icon', // ← IMPORTANT
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }


  static Future<List<TaksModel>> fetchTasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");
    print("Token: $token");
    final url = Uri.parse("https://stafftally.com/api/staff/activities");

    final response = await http.get(
      url,
      headers: {"Authorization": "Bearer $token", "Accept": "application/json"},
    );

    if (response.statusCode == 200) {
      print("API RESPONSE: ${response.body}");
      return taksModelFromJson(response.body);
    } else {
      print("Failed with status: ${response.statusCode}");
      throw Exception("Failed to load tasks");
    }
  }

  static List<TaksModel> taksModelFromJson(String str) =>
      List<TaksModel>.from(json.decode(str).map((x) => TaksModel.fromJson(x)));

  Future<void> refreshTasks() async {
    await fetchTaskData();
    setState(() {});
  }

  List<TaksModel> get filteredTasks {
    if (selectedDate == null) return taskList;

    return taskList.where((t) {
      final d = t.startDate.toLocal();
      return d.year == selectedDate!.year &&
          d.month == selectedDate!.month &&
          d.day == selectedDate!.day;
    }).toList();
  }

  Future<void> updateTaskStatus(
    int taskId,
    String status,
    String remark,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");
    print("Token: $token");
    final url = Uri.parse(
      "https://stafftally.com/api/staff/activities/$taskId",
    );

    try {
      final response = await http.put(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"status": status, "remark": remark}),
      );

      if (response.statusCode == 200) {
        print("✔ Updated Successfully");
        print(response.body);

        // Optional: Refresh Task List
        fetchTasks();
      } else {
        print(" Failed: ${response.body}");
      }
    } catch (e) {
      print(" Error: $e");
    }
  }

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

  bool isSameDate(DateTime d1, DateTime d2) =>
      d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xffEDF0F8),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(15),
            ),
            child: Container(
              decoration: const BoxDecoration(color: Color(0xFFEFF4FF)),
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Center(
                  child: Text(
                    "Staff Daily To-Do",
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: const Icon(Icons.add, color: Colors.black, size: 28),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateActivityScreen(),
                    ),
                  ).then((_) {
                    setState(() => isLoading = true);
                    fetchTaskData();
                  });
                },
              ),
            ),
          ],
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 15),
                  child: InkWell(
                    onTap: showTaskReportDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.bar_chart_rounded,
                            color: Colors.blue,
                            size: 20,
                          ),
                          SizedBox(width: 6),
                          Text(
                            "Task Report",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 3),

                // ---------------------- PICK DATE BUTTON ----------------------
                InkWell(
                  onTap: pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.date_range, color: Colors.white, size: 20),
                        SizedBox(width: 6),
                        Text(
                          "Pick Date",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (selectedDate != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Selected: ${DateFormat("dd MMM yyyy").format(selectedDate!)}",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.red),
                      onPressed: () => setState(() => selectedDate = null),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 18),
            Expanded(
              child:
                  isLoading || isUpdating
                      ? taskListShimmer() // FULL SCREEN shimmer while loading or updating
                      : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: filteredTasks.length,
                        itemBuilder: (context, i) {
                          final task = filteredTasks[i];
                          return taskCard(
                            task.id,
                            task.activityName,
                            task.description,
                            DateFormat("dd MMM yyyy").format(task.startDate),
                            DateFormat("dd MMM yyyy").format(task.dueDate),
                            task.status ?? "N/A",
                            task.remark ?? "No remarks",
                            task.startDate,
                          );
                        },
                      ),
            ),

            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  void showTaskReportDialog() {
    final monthlyData = getMonthlyCompletedCount();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 30,
            vertical: 40,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------- TITLE ----------
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.bar_chart_rounded,
                        color: Colors.blue,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Monthly Task Report",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ---------- EMPTY CASE ----------
                if (monthlyData.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        "No completed tasks available.",
                        style: TextStyle(fontSize: 15, color: Colors.black54),
                      ),
                    ),
                  ),

                // ---------- MONTH LIST ----------
                ...monthlyData.entries.map(
                  (e) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          offset: const Offset(0, 2),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // MONTH
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              e.key,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                        // COUNT BADGE
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "${e.value} Completed",
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),
                const Divider(height: 1),

                // ---------- CLOSE BUTTON ----------
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Close",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget taskListShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: [
          // fake header shimmer
          Container(
            height: 50,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: 6,
              padding: const EdgeInsets.only(bottom: 16),
              itemBuilder: (_, i) {
                return Container(
                  height: 110,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget taskCard(
    int taskId,
    String staffName,
    String description,
    String start,
    String end,
    String status,
    String remarks,
    DateTime date,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),

        title: Row(
          children: [
            Expanded(
              child: Text(
                staffName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            SizedBox(width: 5),

            Text(
              DateFormat("dd MMM yyyy").format(date),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey,
              ),
            ),

            SizedBox(width: 10),

            SizedBox(width: 10),

            GestureDetector(
              onTap: () => showEditDialog(taskId),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, size: 18, color: Colors.blue),
              ),
            ),
          ],
        ),

        // ------------------ SUBTITLE ------------------
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // DESCRIPTION
              Text(
                description,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),

              const SizedBox(height: 10),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 95,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  void showEditDialog(int taskId) {
    String selectedStatus = "Pending";
    final TextEditingController remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ---------------- HEADER ----------------
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    gradient: LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Text(
                    "Update Task",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ---------------- LABEL ----------------
                      const Text(
                        "Select Status",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ---------------- PREMIUM DROPDOWN ----------------
                      StatefulBuilder(
                        builder: (context, setDropState) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F4F8),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedStatus,
                                isExpanded: true,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: "Pending",
                                    child: Text("Pending"),
                                  ),
                                  DropdownMenuItem(
                                    value: "Hold",
                                    child: Text("Hold"),
                                  ),
                                  DropdownMenuItem(
                                    value: "Completed",
                                    child: Text("Completed"),
                                  ),
                                ],
                                onChanged: (value) {
                                  setDropState(() => selectedStatus = value!);
                                },
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // ---------------- REMARK LABEL ----------------
                      const Text(
                        "Remarks",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ---------------- REMARK INPUT ----------------
                      TextField(
                        controller: remarksController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: "Enter remarks...",
                          filled: true,
                          fillColor: const Color(0xFFF2F4F8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(height: 1),
                // ---------------- FOOTER BUTTONS ----------------
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // CANCEL BUTTON
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // SAVE BUTTON
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          setState(() => isUpdating = true); // 🔥 Show shimmer
                          await updateTaskStatus(
                            taskId,
                            selectedStatus.toLowerCase(),
                            remarksController.text,
                          );
                          await fetchTaskData(); // Reload updated tasks
                          setState(
                            () => isUpdating = false,
                          ); // 🔥 Remove shimmer
                        },

                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 12,
                          ),
                          backgroundColor: const Color(0xFF1565C0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                        ),
                        child: const Text(
                          "Save",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "pending":
        return Colors.orange;
      case "hold":
        return Colors.blue;
      case "completed":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
