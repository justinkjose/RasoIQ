import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

enum CameraScanError {
  permissionDenied,
  noTextDetected,
  unknown,
}

class CameraTextScanResult {
  const CameraTextScanResult({
    this.text,
    this.error,
    this.cancelled = false,
  });

  final String? text;
  final CameraScanError? error;
  final bool cancelled;
}

class CameraTextScanService {
  CameraTextScanService({
    ImagePicker? picker,
    TextRecognizer? recognizer,
  })  : _picker = picker ?? ImagePicker(),
        _recognizer = recognizer ?? TextRecognizer();

  final ImagePicker _picker;
  final TextRecognizer _recognizer;

  Future<CameraTextScanResult> scanFromCamera() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );
      if (file == null) {
        return const CameraTextScanResult(cancelled: true);
      }

      final inputImage = InputImage.fromFile(File(file.path));
      final recognizedText = await _recognizer.processImage(inputImage);
      final text = recognizedText.text.trim();
      if (text.isEmpty) {
        return const CameraTextScanResult(error: CameraScanError.noTextDetected);
      }

      return CameraTextScanResult(text: text);
    } on PlatformException catch (error) {
      if (error.code.contains('denied')) {
        return const CameraTextScanResult(error: CameraScanError.permissionDenied);
      }
      return const CameraTextScanResult(error: CameraScanError.unknown);
    } catch (_) {
      return const CameraTextScanResult(error: CameraScanError.unknown);
    }
  }

  Future<void> dispose() async {
    await _recognizer.close();
  }
}
