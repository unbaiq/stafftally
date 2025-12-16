import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

class StaffTrackingMapScreen extends StatefulWidget {
  const StaffTrackingMapScreen({super.key});

  @override
  State<StaffTrackingMapScreen> createState() =>
      _StaffTrackingMapScreenState();
}

class _StaffTrackingMapScreenState extends State<StaffTrackingMapScreen> {
  GoogleMapController? mapController;

  List<LatLng> movementPoints = [];
  LatLng? staffPosition;

  Marker? startMarker;
  Marker? endMarker;

  String staffName = "Loading...";
  double distanceKm = 0;
  int totalTimeMin = 0;

  String startTime = "--:--"; // created_at
  String endTime = "--:--";   // updated_at

  bool isLoading = true;

  DateTime selectedDate = DateTime.now();
  String? selectedMonth;

  final List<String> months = const [
    "January","February","March","April","May","June",
    "July","August","September","October","November","December"
  ];

  @override
  void initState() {
    super.initState();
    fetchLocationData();
  }

  // ================= API =================
  Future<void> fetchLocationData() async {
    try {
      setState(() => isLoading = true);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      print("TOKEN => $token");

      final uri = Uri.parse("https://stafftally.com/api/location/latest")
          .replace(queryParameters: {
        "date": DateFormat("yyyy-MM-dd").format(selectedDate),
        if (selectedMonth != null) "month": selectedMonth!,
      });

      final response = await http.get(
        uri,
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        staffName = data["staff"]?.toString() ?? "Unknown";
        distanceKm = double.tryParse(
          data["distance_km"]?.toString() ?? "0",
        ) ?? 0;

        totalTimeMin = int.tryParse(
          data["total_time_min"]?.toString() ?? "0",
        ) ?? 0;

        final List locations = data["locations"] ?? [];

        movementPoints.clear();

        // 🔥 STEP 1: fill movement points
        for (final loc in locations) {
          final lat = double.tryParse(loc["lat"]?.toString() ?? "");
          final lng = double.tryParse(loc["lng"]?.toString() ?? "");
          if (lat != null && lng != null) {
            movementPoints.add(LatLng(lat, lng));
          }
        }

        if (movementPoints.isNotEmpty && locations.isNotEmpty) {
          // 🔥 STEP 2: START & END TIME (timestamp = IST)
          final startLoc = locations.last;  // oldest
          final endLoc = locations.first;   // latest

          startTime = startLoc["timestamp"] != null
              ? _formatTimestamp(startLoc["timestamp"])
              : "--:--";

          endTime = endLoc["timestamp"] != null
              ? _formatTimestamp(endLoc["timestamp"])
              : "--:--";

          staffPosition = movementPoints.first;

          startMarker = Marker(
            markerId: const MarkerId("start"),
            position: movementPoints.last,
            infoWindow: InfoWindow(title: "Start\n$startTime"),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
          );

          endMarker = Marker(
            markerId: const MarkerId("end"),
            position: movementPoints.first,
            infoWindow: InfoWindow(title: "End\n$endTime"),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("API ERROR => $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ================= TIME (UTC → IST) =================
  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateFormat("yyyy-MM-dd HH:mm:ss").parse(timestamp);
      return DateFormat("hh:mm a").format(dt); // ✅ 01:27 PM
    } catch (_) {
      return "--:--";
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEFF4FF),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Tracking: $staffName"),
            Text(
              "Date: ${DateFormat("dd MMM yyyy").format(selectedDate)}"
                  "${selectedMonth != null ? " | $selectedMonth" : ""}",
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: isLoading || staffPosition == null
          ? _shimmer()
          : Stack(
        children: [
          _buildMap(),
          _topBar(),
          _summaryCard(),
        ],
      ),
    );
  }

  // ================= MAP =================
  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: staffPosition!,
        zoom: 15,
      ),
      markers: {
        if (startMarker != null) startMarker!,
        if (endMarker != null) endMarker!,
      },
      polylines: {
        Polyline(
          polylineId: const PolylineId("route"),
          points: movementPoints,
          width: 5,
          color: Colors.blue,
        ),
      },
      myLocationEnabled: true,
    );
  }

  // ================= TOP BAR =================
  Widget _topBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              _filterChip(
                icon: Icons.calendar_today,
                label: DateFormat("dd MMM").format(selectedDate),
                onTap: _selectDate,
              ),

              const SizedBox(width: 8),

              _filterChip(
                icon: Icons.calendar_month,
                label: selectedMonth ?? "Month",
                onTap: _selectMonth,
              ),

              const Spacer(),

              ElevatedButton.icon(
                onPressed: fetchLocationData,
                label: const Text("Apply"),
                style: ElevatedButton.styleFrom(
                  backgroundColor:   Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F5FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF03396A)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= SUMMARY =================
  Widget _summaryCard() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 6),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _summaryItem("Time Start", startTime),
                  _summaryItem("Time End", endTime),
                ],
              ),
              const SizedBox(height: 8),
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //   children: [
              //     _summaryItem("Distance", "$distanceKm km"),
              //     _summaryItem("Duration", "$totalTimeMin min"),
              //   ],
              // ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryItem(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  // ================= PICKERS =================
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _selectMonth() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => ListView(
        children: months
            .map((m) => ListTile(
          title: Text(m),
          onTap: () => Navigator.pop(context, m),
        ))
            .toList(),
      ),
    );
    if (result != null) setState(() => selectedMonth = result);
  }

  // ================= SHIMMER =================
  Widget _shimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(color: Colors.white),
    );
  }
}
