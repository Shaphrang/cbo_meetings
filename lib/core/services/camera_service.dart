//lib\core\services\camera_service.dart
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

class CameraService {

  CameraController? _controller;
  List<CameraDescription>? _cameras;

  Future<void> initialize() async {

    _cameras = await availableCameras();

    _controller = CameraController(
      _cameras!.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();
  }

  Future<File> takePicture() async {

    if (_controller == null || !_controller!.value.isInitialized) {
      await initialize();
    }

    final image = await _controller!.takePicture();

    final directory = await getApplicationDocumentsDirectory();

    final file = File(
      '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    return File(image.path).copy(file.path);
  }

  Future<void> dispose() async {
    await _controller?.dispose();
  }
}