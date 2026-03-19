import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_widgets.dart';
import '../services/receipt_scanner_service.dart';
import 'receipt_preview_screen.dart';

class ReceiptScanScreen extends StatefulWidget {
  const ReceiptScanScreen({super.key});

  @override
  State<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends State<ReceiptScanScreen> {
  final ReceiptScannerService _scanner = ReceiptScannerService();
  CameraController? _controller;
  bool _loading = false;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() => _initializing = false);
        return;
      }
      final back = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _initializing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _loading) return;
    setState(() => _loading = true);
    try {
      final xfile = await controller.takePicture();
      final image = File(xfile.path);
      final items = await _scanner.scanReceipt(image);
      if (!mounted) return;
      setState(() => _loading = false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReceiptPreviewScreen(
            image: image,
            items: items,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Receipt')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.space24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Capture Receipt', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppTheme.space8),
                Text(
                  'Take a clear photo to extract items.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppTheme.space16),
                if (_initializing)
                  const Center(child: CircularProgressIndicator())
                else if (_controller == null)
                  const Text('Camera not available.'),
                if (_controller != null && _controller!.value.isInitialized) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: CameraPreview(_controller!),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space16),
                  RoundedButton(
                    label: _loading ? 'Processing...' : 'Capture Receipt',
                    icon: Icons.camera_alt,
                    onPressed: _loading ? null : _captureImage,
                  ),
                ],
              ],
            ),
          ),
          if (_loading) ...[
            const SizedBox(height: AppTheme.space24),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
