import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_whisper_kit/flutter_whisper_kit.dart';
import 'package:whisper4dart/whisper4dart.dart' as whisper;

class WhisperTranscriptionService {
  WhisperTranscriptionService({
    FlutterWhisperKit? whisper,
    this.modelName = 'tiny',
    this.modelRepo = 'argmaxinc/whisperkit-coreml',
    this.androidModelAsset = 'assets/whisper/ggml-tiny.en.bin',
  }) : _whisper = whisper ?? FlutterWhisperKit();

  final FlutterWhisperKit _whisper;
  final String modelName;
  final String modelRepo;
  final String androidModelAsset;
  bool _modelReady = false;
  Uint8List? _androidModelBytes;

  Future<void> ensureModelLoaded() async {
    if (Platform.isAndroid) {
      if (_androidModelBytes != null) return;
      try {
        final buffer = await rootBundle.load(androidModelAsset);
        _androidModelBytes = buffer.buffer.asUint8List();
      } catch (error) {
        debugPrint('Whisper model asset load failed: $error');
        rethrow;
      }
      return;
    }

    if (Platform.isIOS || Platform.isMacOS) {
      if (_modelReady) return;
      try {
        await _whisper.loadModel(
          modelName,
          modelRepo: modelRepo,
        );
        _modelReady = true;
      } catch (error) {
        debugPrint('Whisper model load failed: $error');
        rethrow;
      }
    }
  }

  Future<String?> transcribeFile(String path) async {
    await ensureModelLoaded();
    if (Platform.isAndroid) {
      final tempDir = await getTemporaryDirectory();
      final logPath = '${tempDir.path}/whisper_log.txt';
      final params = whisper.createContextDefaultParams();
      final model = _androidModelBytes;
      if (model == null) return null;
      final whisperModel =
          whisper.Whisper(model, params, outputMode: 'plaintext');
      final output = await whisperModel.infer(
        path,
        logPath: logPath,
        numProcessors: 1,
        translate: false,
        initialPrompt: '',
        startTime: 0,
        endTime: -1,
        useOriginalTime: true,
      );
      return output;
    }

    if (Platform.isIOS || Platform.isMacOS) {
      final result = await _whisper.transcribeFromFile(
        path,
        options: const DecodingOptions(
          task: DecodingTask.transcribe,
          language: 'en',
        ),
      );
      return result?.text;
    }

    return null;
  }
}
