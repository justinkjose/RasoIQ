import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum VoiceInputAvailability {
  granted,
  permissionDenied,
  unavailable,
}

class VoiceInputService {
  VoiceInputService({stt.SpeechToText? speechToText})
      : _speech = speechToText ?? stt.SpeechToText();

  final stt.SpeechToText _speech;
  ValueChanged<bool>? _onListeningChanged;
  ValueChanged<String>? _onResult;
  bool _initialized = false;

  Future<VoiceInputAvailability> ensureInitialized() async {
    if (!_initialized) {
      final available = await _speech.initialize(
        onStatus: _handleStatus,
        onError: (error) => debugPrint('Voice input error: $error'),
      );
      _initialized = true;
      if (!available) {
        return VoiceInputAvailability.unavailable;
      }
    }

    final hasPermission = await _speech.hasPermission;
    if (!hasPermission) {
      return VoiceInputAvailability.permissionDenied;
    }

    return VoiceInputAvailability.granted;
  }

  Future<void> startListening({
    required ValueChanged<String> onResult,
    required ValueChanged<bool> onListeningChanged,
  }) async {
    _onResult = onResult;
    _onListeningChanged = onListeningChanged;
    await _speech.listen(
      onResult: (result) => _onResult?.call(result.recognizedWords),
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
      ),
    );
    _onListeningChanged?.call(true);
  }

  Future<void> stopListening() async {
    await _speech.stop();
    _onListeningChanged?.call(false);
  }

  void _handleStatus(String status) {
    if (status == 'listening') {
      _onListeningChanged?.call(true);
    } else if (status == 'done' || status == 'notListening') {
      _onListeningChanged?.call(false);
    }
  }
}
