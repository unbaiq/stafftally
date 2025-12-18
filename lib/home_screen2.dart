import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'ApplyLeaveScreen.dart';
import 'AttendanceScreen.dart';
import 'SelfieCameraScreen.dart';

class HomeScreen2 extends StatefulWidget {
  const HomeScreen2({super.key});

  @override
  State<HomeScreen2> createState() => _HomeScreen2State();
}

class _HomeScreen2State extends State<HomeScreen2> with WidgetsBindingObserver {
  Timer? _locationTimer;

  final String locationApiUrl =
      "https://stafftally.com/api/staff/location-store";
  final int trackingIntervalSeconds = 60;
  String finalImageUrl = "";
  String profileImage = "";
  bool loadingToday = true;
  bool loadingUser = true;
  bool isCheckingIn = false;
  bool isCheckingOut = false;
  bool isProcessing = false;
  Map<String, dynamic>? todayData;
  Map<String, dynamic>? userData;
  bool _isTrackingActive = false;
  bool autoCheckInActive = false;
  bool autoCheckOutActive = false;
  double officeLat = 0.0;
  double officeLng = 0.0;
  double geoRadius = 500; // 500 meter radius
  bool isInside = false;
  double userLat = 0.0;
  double userLng = 0.0;

  // MAP VARIABLES
  GoogleMapController? _mapController;
  LatLng? _currentLatLng;
  BitmapDescriptor? _personIcon;
  late List<CameraDescription> cameras;
  late File? img;
  BitmapDescriptor? personIcon;
  bool _mapReady = false;
  final CameraPosition _defaultCamera = const CameraPosition(
    target: LatLng(20.5937, 78.9629),
    zoom: 4,
  );
  int lateCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPersonMarker();
    fetchUserDetails();
    fetchTodayAttendance();
    _loadPersonMarker();
    loadLateCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    autoCheckInActive = false;
    autoCheckOutActive = false;

    _stopLocationTracking();
    super.dispose();
  }

  // ----------------- SAFE LOCATION FETCH -----------------
  Future<Position?> _safeGetPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint("Location error => $e");
      return null;
    }
  }

  Future<BitmapDescriptor> _resizeImage(String imagePath, int width) async {
    final ByteData data = await rootBundle.load(imagePath);
    final Uint8List bytes = data.buffer.asUint8List();

    final ui.Codec codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: width,
    );
    final ui.FrameInfo fi = await codec.getNextFrame();

    final Uint8List resizedBytes =
        (await fi.image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(resizedBytes);
  }

  Future<void> _loadPersonMarker() async {
    try {
      _personIcon = await _resizeImage("assets/person.png", 220);
    } catch (e) {
      debugPrint("Marker load error: $e");
      _personIcon = BitmapDescriptor.defaultMarker;
    }
  }

  // ----------------- assets marker -----------------

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<void> _getCurrentLocation() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    Position? pos = await _safeGetPosition();
    if (pos == null) return;

    setState(() {
      _currentLatLng = LatLng(pos.latitude, pos.longitude);
      userLat = pos.latitude;
      userLng = pos.longitude;
    });

    if (_mapReady && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLatLng!, 13),
      );
    }
  }

  // ---------------- AUTO CHECK-IN ---------------- //
  void startAutoCheckIn() async {
    if (!autoCheckInActive || !mounted) return;

    await Future.delayed(const Duration(seconds: 60));

    if (!mounted) return;

    await _captureAndSendLocation();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Auto Check-In executed")));
    }

    startAutoCheckIn();
  }

  // ---------------- AUTO CHECK-OUT ---------------- //
  void startAutoCheckOut() async {
    if (!autoCheckOutActive || !mounted) return;

    await Future.delayed(const Duration(seconds: 20));
    autoCheckOutActive = false;
  }

  // ---------------- LIFE CYCLE ---------------- //
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fetchTodayAttendance();
      if (isCheckInDone && !isCheckOutDone) {
        _ensureLocationAndStartTracking();
      }
    } else {
      _stopLocationTracking();
    }
  }

  bool get isCheckInDone =>
      todayData != null &&
      todayData!["check_in_time"] != null &&
      todayData!["check_in_time"].toString().isNotEmpty;

  bool get isCheckOutDone =>
      todayData != null &&
      todayData!["check_out_time"] != null &&
      todayData!["check_out_time"].toString().isNotEmpty;

  Map<String, dynamic> _map(dynamic m) {
    if (m is Map<String, dynamic>) return m;
    if (m is Map) return Map<String, dynamic>.from(m);
    return {};
  }

  String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    if (path.startsWith("http")) return path;
    return "https://stafftally.com/storage/$path";
  }

  double _calculateDistance(lat1, lon1, lat2, lon2) {
    const p = 0.017453292519943295;
    final a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000; // return meters
  }

  Future<void> fetchUserDetails() async {
    setState(() => loadingUser = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");

      final url = Uri.parse("https://stafftally.com/api/staff/me");

      final res = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);

        // 🔥 API response
        userData = body["user"];

        // ---------------------------------------------
        //  ✔✔ GEOFENCE COORDINATES MUST BE EXTRACTED HERE
        // ---------------------------------------------
        if (userData?["latitude"] != null && userData?["longitude"] != null) {
          officeLat = double.tryParse(userData!["latitude"].toString()) ?? 0.0;
          officeLng = double.tryParse(userData!["longitude"].toString()) ?? 0.0;

          print("Office LAT = $officeLat");
          print("Office LNG = $officeLng");
        }
        // ---------------------------------------------

        // Profile Image
        String? img = userData?["profile_photo"];
        if (img != null && img.isNotEmpty) {
          profileImage = "https://stafftally.com/storage/$img";
        }

        // 🔥 Map ko office location par zoom karao
        if (officeLat != 0.0 && officeLng != 0.0 && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(officeLat, officeLng), 5),
          );
        }
      }
    } catch (e) {
      print("ERROR fetchUser: $e");
    }

    if (!mounted) return;
    setState(() => loadingUser = false);
  }

  Future<void> fetchTodayAttendance() async {
    if (!mounted) return;
    setState(() => loadingToday = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");
      final url = Uri.parse("https://stafftally.com/api/attendance/today");
      final res = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        todayData = _map(body["data"] ?? body);

        if (isCheckInDone && !isCheckOutDone) {
          _ensureLocationAndStartTracking();
        } else {
          _stopLocationTracking();
        }
      } else {
        todayData = null;
      }
    } catch (_) {
      todayData = null;
    }

    if (!mounted) return;
    setState(() => loadingToday = false);
  }

  Future<void> _ensureLocationAndStartTracking() async {
    if (_isTrackingActive) return;

    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return;
    }
    if (perm == LocationPermission.deniedForever) return;

    _startLocationTimer();
  }

  void _startLocationTimer() {
    print('_startLocationTimer');
    _locationTimer?.cancel();

    _locationTimer = Timer.periodic(
      Duration(seconds: trackingIntervalSeconds),
      (_) async {
        if (!mounted) return;
        await _captureAndSendLocation();
      },
    );
    _captureAndSendLocation();
    _isTrackingActive = true;
  }

  void _stopLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _isTrackingActive = false;
  }

  Future<void> _captureAndSendLocation() async {
    print('calling_captureAndSendLocation');
    try {
      Position? pos = await _safeGetPosition();
      if (pos == null || !mounted) return;

      final newLatLng = LatLng(pos.latitude, pos.longitude);

      bool changed =
          _currentLatLng == null ||
          (_currentLatLng!.latitude - newLatLng.latitude).abs() > 0.00001 ||
          (_currentLatLng!.longitude - newLatLng.longitude).abs() > 0.00001;

      if (changed) {
        setState(() {
          _currentLatLng = newLatLng;
        });

        if (_mapReady && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(_currentLatLng!),
          );
        }
      }
      // ---------------- GEOFENCE CHECK ----------------
      double distance = _calculateDistance(
        pos.latitude,
        pos.longitude,
        officeLat,
        officeLng,
      );

      print('distance_$distance');
      // bool newInside = 350.00 <= geoRadius;
      bool newInside = distance <= geoRadius;

      if (newInside != isInside) {
        setState(() {
          isInside = newInside;
        });

        if (isInside) {
          print("User entered 500m circle");
        } else {
          print("User exited 500m circle");
        }
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");

      final body = {
        "lat": pos.latitude.toString(),
        "lng": pos.longitude.toString(),
        "timestamp": DateTime.now().toIso8601String(),
      };

      await http.post(
        Uri.parse(locationApiUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },

        body: jsonEncode(body),
      );
    } catch (e) {
      debugPrint("Location error : $e");
    }
  }

  Future<File?> captureSelfie() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SelfieCameraScreen()),
    );

    if (result != null && result is File) {
      return result;
    }

    return null;
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

  void startTracking() async {
    final service = FlutterBackgroundService();
    await service.startService();
  }

  void stopTracking() async {
    final service = FlutterBackgroundService();
    service.invoke("stopService");
  }

  Future<String> fileToBase64(File file) async {
    final bytes = await file.readAsBytes();
    print("fileToBase64: length ${bytes.length}");
    return base64Encode(bytes);
  }

  Future<String> imageUrlToBase64(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));

    if (response.statusCode == 200) {
      String base64String = base64Encode(response.bodyBytes);
      return base64String;
    } else {
      throw Exception('Failed to load image from URL');
    }
  }

  Future<String?> fetchProfileImageBytes() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");

      final response = await http.get(
        Uri.parse("https://stafftally.com/api/staff/me"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        userData = body["user"];
        String? img = userData?["profile_photo"];
        if (img == null || img.isEmpty) return null;

        final String finalImageUrl = "https://stafftally.com/storage/$img";
        return imageUrlToBase64(finalImageUrl);
      }
    } catch (e) {
      print("fetchProfileImageBytes ERROR: $e");
    }
    return null;
  }

  Future<bool> _uploadSelfieAsProfile(File imageFile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://stafftally.com/api/staff/update'),
      );

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
        request.headers['Accept'] = 'application/json';
      }

      request.files.add(
        await http.MultipartFile.fromPath('profile_photo', imageFile.path),
      );
      final response = await request.send();
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("uploadSelfieAsProfile error: $e");
      return false;
    }
  }

  Future<double?> compareFaces(String base64Img1, String base64Img2) async {
    final url = Uri.parse("https://faceapi.mxface.ai/api/v3/face/verify");
    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Subscriptionkey": "ge3p5UYeRo3Ns3R6y0-40VXDzbMpI4961",
      },
      body: jsonEncode({
        "encoded_image1": base64Img1,
        "encoded_image2": base64Img2,
      }),
    );

    print("FACE API RESPONSE: (${response.statusCode}) ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data["matchedFaces"] != null && data["matchedFaces"].isNotEmpty) {
        final confidence = data["matchedFaces"][0]["confidence"];
        return (confidence is num)
            ? confidence.toDouble()
            : double.tryParse(confidence.toString());
      }
    } else {
      print("Face API Error: ${response.body}");
    }
    return null;
  }

  Future<void> checkIn() async {
    if (isCheckingIn) return; // Prevent double tap
    setState(() => isCheckingIn = true);
    img = await captureSelfie();
    if (img == null) {
      setState(() => isCheckingIn = false);
      return;
    }

    try {
      String selfieBase64 = await fileToBase64(img!);
      String? profileBase64 = await fetchProfileImageBytes();
      double? confidence;

      if (profileBase64 == null) {
        bool uploaded = await _uploadSelfieAsProfile(img!);
        if (!uploaded) {
          showTopSnackbar("Unable to save profile photo!", Colors.red);
          setState(() => isCheckingIn = false);
          return;
        }
        await fetchUserDetails();
        confidence = 100.0;
      } else {
        confidence = await compareFaces(profileBase64, selfieBase64);
        if (confidence == null || confidence < 50) {
          showTopSnackbar("Face Not Matched! Score: $confidence%", Colors.red);
          setState(() => isCheckingIn = false);
          return;
        }
      }

      // ------------------------------------------------------------------
      //                ⭐ LATE CHECK-IN FEATURE ADDED HERE ⭐
      // ------------------------------------------------------------------

      DateTime now = DateTime.now();
      DateTime lateTime = DateTime(now.year, now.month, now.day, 10, 15);

      bool isLate = now.isAfter(lateTime);

      if (isLate) {
        await addLateNotification();
        await loadLateCount();

        if (isLate) {
          await addLateNotification();
          await loadLateCount();
          Fluttertoast.showToast(
            msg: "You checked in late today.\nPlease ensure timely attendance.",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.CENTER,
            timeInSecForIosWeb: 10,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        }
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");

      var request = http.MultipartRequest(
        "POST",
        Uri.parse("https://stafftally.com/api/attendance/check-in"),
      );

      request.headers["Authorization"] = "Bearer $token";
      request.headers["Accept"] = "application/json";

      request.files.add(
        await http.MultipartFile.fromPath("check_in_image", img!.path),
      );

      var response = await request.send();

      setState(() => isCheckingIn = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchTodayAttendance();

        showTopSnackbar(
          "Check-In Successful (Match: ${confidence.toStringAsFixed(2)}%)",
          Colors.green,
        );
      } else {
        showTopSnackbar("Check-In Failed", Colors.red);
      }
    } catch (e) {
      print("check-in error: $e");
      setState(() => isCheckingIn = false);
    }
  }

  Future<void> checkOut() async {
    if (isCheckingOut) return; // Prevent double tap
    setState(() => isCheckingOut = true);
    img = await captureSelfie();
    if (img == null) {
      setState(() => isCheckingOut = false);
      return;
    }

    // File? img = await captureSelfie();
    // if (img == null) return;

    setState(() => isCheckingOut = true);

    try {
      String selfieBase64 = await fileToBase64(img!);

      String? profileBase64 = await fetchProfileImageBytes();

      if (profileBase64 == null) {
        showTopSnackbar("Profile image not found!", Colors.red);
        setState(() => isCheckingOut = false);
        return;
      }
      double? confidence = await compareFaces(profileBase64, selfieBase64);
      print("CONFIDENCE SCORE = $confidence");

      if (confidence == null || confidence < 50) {
        showTopSnackbar("Face Not Matched! Score: $confidence%", Colors.red);
        setState(() => isCheckingOut = false);
        return;
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");

      var request = http.MultipartRequest(
        "POST",
        Uri.parse("https://stafftally.com/api/attendance/check-out"),
      );

      request.headers["Authorization"] = "Bearer $token";
      request.headers["Accept"] = "application/json";

      request.files.add(
        await http.MultipartFile.fromPath("check_out_image", img!.path),
      );

      var response = await request.send();

      setState(() => isCheckingOut = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchTodayAttendance();
        stopTracking();
        showTopSnackbar(
          "Check-Out Successful (Match: $confidence%)",
          Colors.green,
        );
      } else {
        showTopSnackbar("Check-Out Failed", Colors.red);
      }
    } catch (e, st) {
      print("check-Out error: $e\n$st");
      setState(() => isCheckingOut = false);
      showTopSnackbar("Unexpected Error!", Colors.red);
    }
  }

  Future<void> addLateNotification() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String today = DateFormat("yyyy-MM-dd").format(DateTime.now());
    String currentMonth = DateFormat("yyyy-MM").format(DateTime.now());

    String? lastLateDay = prefs.getString("last_late_date");
    String? lastResetMonth = prefs.getString("last_reset_month");

    // Reset every month
    if (lastResetMonth != currentMonth) {
      await prefs.setInt("late_count", 0);
      await prefs.setString("last_reset_month", currentMonth);
    }

    // Prevent adding late again for same day
    if (lastLateDay == today) return;

    // Increase count
    int count = prefs.getInt("late_count") ?? 0;
    count++;

    await prefs.setInt("late_count", count);
    await prefs.setString("last_late_date", today);
  }

  Future<void> loadLateCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      lateCount = prefs.getInt("late_count") ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(95),
        child: Container(
          height: 110,
          decoration: const BoxDecoration(
            color: Color(0xFFE6EEFF),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ---------------- LEFT SIDE (Profile + Text) ----------------
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.black.withOpacity(0.4),
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              spreadRadius: 1,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.grey[300],
                          backgroundImage:
                              !loadingUser && profileImage.isNotEmpty
                                  ? NetworkImage(profileImage)
                                  : const NetworkImage(
                                    "https://i.postimg.cc/8P5YzG1L/user-placeholder.png",
                                  ),
                        ),
                      ),

                      const SizedBox(width: 15),

                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Welcome to Staff",
                            style: TextStyle(
                              color: Colors.black45,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            loadingUser
                                ? "Loading..."
                                : (userData?["name"] ?? "User"),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // ---------------- RIGHT SIDE (Notification Icon) ----------------
                  InkWell(
                    onTap: () {
                      // Navigate to notification screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AttendanceScreen()),
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          Icons.notifications_none,
                          size: 30,
                          color: Colors.black87,
                        ),
                        Positioned(
                          right: -2,
                          top: -2,
                          child:
                              lateCount > 0
                                  ? Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.red,
                                    ),
                                    child: Text(
                                      "$lateCount",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                  : SizedBox(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      body:
          (loadingUser || loadingToday)
              ? _fullScreenShimmer()
              : _mapSection(),
    );
  }

  // ---------------- UI COMPONENTS ---------------- //
  Widget _mapSection() {
    return SafeArea(
      child: Column(
        children: [
          // 🔹 MAP (Fixed Height)
          SizedBox(
            height: 290,
            width: double.infinity,
            child: GoogleMap(
              initialCameraPosition: _currentLatLng == null
                  ? _defaultCamera
                  : CameraPosition(
                target: _currentLatLng!,
                zoom: 14, // better UX
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                _mapReady = true;
                _getCurrentLocation();
                _captureAndSendLocation();
              },
              myLocationEnabled: true,
              circles: {
                Circle(
                  circleId: const CircleId("office"),
                  center: LatLng(userLat, userLng),
                  radius: geoRadius,
                  fillColor: isInside
                      ? Colors.green.withOpacity(0.15)
                      : Colors.red.withOpacity(0.15),
                  strokeColor: isInside ? Colors.green : Colors.red,
                  strokeWidth: 3,
                ),
              },
              markers: {
                if (_currentLatLng != null)
                  Marker(
                    markerId: const MarkerId("me"),
                    position: _currentLatLng!,
                    icon:
                    _personIcon ?? BitmapDescriptor.defaultMarker,
                  ),
              },
            ),
          ),

          // 🔹 SCROLLABLE CONTENT
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  _attendanceCard(),
                  const SizedBox(height: 8),
                  _quickActions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _fullScreenShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // MAP SHIMMER
            Container(height: 260, width: double.infinity, color: Colors.white),

            const SizedBox(height: 20),

            // ATTENDANCE CARD SHIMMER
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    height: 25,
                    width: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // two image boxes shimmer
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // BUTTON SHIMMERS
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attendanceCard() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 👈 very important
          children: [
            const Text(
              "Today's Attendance",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 20),

            loadingToday
                ? const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            )
                : _attendanceDetails(),
          ],
        ),
      ),
    );
  }


  Widget _emptyImageBox(String label) {
    return Column(
      children: [
        Container(
          height: 160,
          width: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey.shade100,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "--:--",
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _attendanceImageWithTime(
      String img,
      String time,
      Color color,
      ) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            _openImagePreview(getFullImageUrl(img));
          },
          child: DottedBorder(
            color: Colors.grey,
            strokeWidth: 1,
            dashPattern: const [5, 4],
            borderType: BorderType.RRect,
            radius: const Radius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                getFullImageUrl(img),
                height: 160,
                width: 140,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          time,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }


  Widget _attendanceImagesRow() {
    return Row(
      children: [
        // CHECK-IN IMAGE + TIME
        Expanded(
          child:
              todayData?["check_in_image"] != null
                  ? _attendanceImageWithTime(
                    todayData!["check_in_image"],
                    todayData?["check_in_time"] ?? "--",
                    Colors.green,
                  )
                  : _emptyImageBox("No Check-In"),
        ),

        const SizedBox(width: 12),

        // CHECK-OUT IMAGE + TIME
        Expanded(
          child:
              todayData?["check_out_image"] != null
                  ? _attendanceImageWithTime(
                    todayData!["check_out_image"],
                    todayData?["check_out_time"] ?? "--",
                    Colors.red,
                  )
                  : _emptyImageBox("No Check-Out"),
        ),
      ],
    );
  }

  Widget _attendanceDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 🔹 Images Row
        _attendanceImagesRow(),

        const SizedBox(height: 20),

        // 🔹 Buttons Row
        Row(
          children: [
            Expanded(
              child: _button(
                label: "Check-In",
                loading: isCheckingIn,
                color: Colors.green,
                onTap: (isCheckingIn || isCheckInDone) ? null : checkIn,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _button(
                label: "Check-Out",
                loading: isCheckingOut,
                color: Colors.red,
                onTap: (!isCheckInDone || isCheckOutDone) ? null : checkOut,
              ),
            ),
          ],
        ),
      ],
    );
  }



  Widget _button({
    required String label,
    required bool loading,
    required Color color,
    required Function()? onTap,
  }) {
    return SizedBox(
      width: 144,
      height: 41,
      child: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: onTap == null ? color.withOpacity(0.3) : color,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child:
              loading
                  ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 17,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
        ),
      ),
    );
  }

  Widget _quickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ApplyLeaveScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // 🔹 LEFT ICON
              Container(
                height: 48,
                width: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFEFF4FF),
                ),
                child: Icon(
                  Icons.note_add_rounded,
                  color: Colors.blue.shade700,
                  size: 26,
                ),
              ),

              const SizedBox(width: 16),

              // 🔹 TEXT
              const Expanded(
                child: Text(
                  "Apply for Leave",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // 🔹 RIGHT ARROW
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.blue.shade700,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openImagePreview(String url) {
    if (url.isEmpty) return;

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          backgroundColor: Colors.transparent,
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder:
                    (c, e, s) => Container(
                      color: Colors.grey.shade100,
                      child: const Center(child: Icon(Icons.broken_image)),
                    ),
              ),
            ),
          ),
        );
      },
    );
  }
}
