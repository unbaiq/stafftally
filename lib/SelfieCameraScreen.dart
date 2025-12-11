import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class SelfieCameraScreen extends StatefulWidget {
  const SelfieCameraScreen({super.key});

  @override
  State<SelfieCameraScreen> createState() => _SelfieCameraScreenState();
}

class _SelfieCameraScreenState extends State<SelfieCameraScreen> {
  CameraController? controller;
  late List<CameraDescription> cameras;

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
    cameras = await availableCameras();

    final frontCamera = cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front,
    );

    controller = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await controller!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> capturePhoto() async {
    if (!controller!.value.isInitialized) return;

    final image = await controller!.takePicture();
    Navigator.pop(context, File(image.path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: controller == null || !controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
        children: [
          // -------- CAMERA PREVIEW --------
          Positioned.fill(child: CameraPreview(controller!)),

          // -------- TOP BAR --------
          Positioned(
            top: 40,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              radius: 24,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // -------- CENTER CIRCLE GUIDELINE --------
          // Center(
          //   child: Container(
          //     width: 260,
          //     height: 260,
          //     decoration: BoxDecoration(
          //       shape: BoxShape.circle,
          //       border: Border.all(
          //         color: Colors.white.withOpacity(0.25),
          //         width: 4,
          //       ),
          //     ),
          //   ),
          // ),

          // -------- BOTTOM CAPTURE BUTTON --------
          Positioned(
            bottom: 35,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: capturePhoto,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Colors.white, Colors.white70],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border:
                      Border.all(color: Colors.grey.shade300, width: 3),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
