//lib\features\meeting\screens\camera_screen.dart
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {

  CameraController? controller;

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {

    final cameras = await availableCameras();

    controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await controller!.initialize();

    if (!mounted) return;

    setState(() {});
  }

  Future<void> capture() async {
    final file = await controller!.takePicture();

    if (!mounted) return;

    Navigator.pop(context, File(file.path));
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(

      body: Stack(

        children: [

          CameraPreview(controller!),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(

              child: FloatingActionButton(
                onPressed: capture,
                child: const Icon(Icons.camera_alt),
              ),

            ),
          )
        ],
      ),
    );
  }
}