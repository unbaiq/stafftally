import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground',
    'MY FOREGROUND SERVICE',
    description: 'This channel is used for important notifications.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  if (Platform.isIOS || Platform.isAndroid) {
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        iOS: DarwinInitializationSettings(),
        android: AndroidInitializationSettings('ic_bg_service_small'),
      ),
    );
  }

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'AWESOME SERVICE',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.reload();
  final log = preferences.getStringList('log') ?? <String>[];
  log.add(DateTime.now().toIso8601String());
  await preferences.setStringList('log', log);

  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // IMPORTANT: MUST BE FIRST LINES
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  print("SERVICE STARTED at: ${DateTime.now()}");

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // HANDLERS
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
      print("SERVICE SET TO FOREGROUND");
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
      print("SERVICE SET TO BACKGROUND");
    });
  }

  service.on('stopService').listen((event) {
    print("SERVICE STOPPED BY APP");
    service.stopSelf();
  });

  // BACKGROUND TASK CALL EVERY 1 MINUTE
  Timer.periodic(const Duration(seconds: 60), (timer) async {
    print("TIMER TICK at: ${DateTime.now()}");

    if (service is AndroidServiceInstance &&
        await service.isForegroundService()) {
      print(" SERVICE IS RUNNING IN FOREGROUND");

      try {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? token = prefs.getString("token");
        if (token == null) {

          return;
        }

        // GET LOCATION
        Position position = await Geolocator.getCurrentPosition();
        double latitude = position.latitude;
        double longitude = position.longitude;

        print("LOCATION => Lat: $latitude  Lng: $longitude");
        final url = Uri.parse("https://stafftally.com/api/staff/location-store");

        final response = await http.post(
          url,
          headers: {
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({
            "lat": latitude,
            "lng": longitude,
          }),
        );


        print("API RESPONSE: ${response.body}");

      } catch (e) {
        print("BACKGROUND ERROR: $e");
      }


      // flutterLocalNotificationsPlugin.show(
      //   888,
      //   'COOL SERVICE',
      //   'Location Updated at ${DateTime.now()}',
      //   const NotificationDetails(
      //     android: AndroidNotificationDetails(
      //       'my_foreground',
      //       'MY FOREGROUND SERVICE',
      //       icon: 'ic_bg_service_small',
      //       ongoing: true,
      //     ),
      //   ),
      // );

      // UPDATE FOREGROUND NOTIFICATION (Correct Method)
      // service.setForegroundNotificationInfo(
      //   title: "My App Service",
      //   content: "Updated at ${DateTime.now()}",
      // );

    } else {
      print("SERVICE NOT IN FOREGROUND");
    }
  });

}



