import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../core/services/receipt_ocr_service.dart';
import '../../../core/services/receipt_parser_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_widgets.dart';
import 'receipt_review_screen.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  CameraController? _controller;
  bool _initializing = true;
  bool _processing = false;
  String? _error;

  final ReceiptParserService _parser = ReceiptParserService();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _error = 'No camera available';
          _initializing = false;
        });
        return;
      }
      final controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (error) {
      setState(() {
        _error = 'Unable to initialize camera';
        _initializing = false;
      });
    }
  }

  Future<void> _captureAndScan() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_processing) return;

    setState(() => _processing = true);
    try {
      final file = await controller.takePicture();
      final imageFile = File(file.path);
      final input = InputImage.fromFile(imageFile);
      final lines = await ReceiptOCRService.extractLines(input);
      final items = _parser.parseLines(lines);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReceiptReviewScreen(
            image: imageFile,
            items: items,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to scan receipt');
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Receipt')),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        child: CameraPreview(_controller!),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.space24),
                      child: RoundedButton(
                        label: _processing ? 'Processing...' : 'Capture',
                        icon: Icons.camera_alt,
                        onPressed: _processing ? null : _captureAndScan,
                      ),
                    ),
                  ],
                ),
    );
  }
}
