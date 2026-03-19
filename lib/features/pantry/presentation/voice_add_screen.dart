import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../theme/app_theme.dart';
import '../../../widgets/app_widgets.dart';
import '../services/pantry_service.dart';
import '../services/voice_command_parser.dart';

class VoiceAddScreen extends StatefulWidget {
  const VoiceAddScreen({super.key});

  @override
  State<VoiceAddScreen> createState() => _VoiceAddScreenState();
}

class _VoiceAddScreenState extends State<VoiceAddScreen> {
  final PantryService _pantryService = PantryService();
  final VoiceCommandParser _parser = VoiceCommandParser();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _listening = false;
  bool _speechReady = false;
  String _transcript = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: (_) {},
      onError: (error) => setState(() => _error = error.errorMsg),
    );
    if (!mounted) return;
    setState(() {
      _speechReady = available;
      if (!available) {
        _error = 'Speech recognition not available';
      }
    });
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }

    if (!_speechReady) {
      await _initSpeech();
    }
    if (!_speechReady) return;

    setState(() {
      _error = null;
      _listening = true;
      _transcript = '';
    });

    await _speech.listen(
      onResult: (result) {
        final words = result.recognizedWords;
        final parsed = _parser.parse(words);
        setState(() {
          _transcript = words;
          if (result.finalResult && parsed == null) {
            _error = 'Say a command like "Add milk"';
          }
        });
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
      ),
    );
  }

  Future<void> _applyCommand() async {
    final parsed = _parser.parse(_transcript);
    if (parsed == null) {
      setState(() => _error = 'Say a command like "Add milk"');
      return;
    }

    await _pantryService.addItem(
      name: parsed.name,
      quantity: parsed.quantity,
      unit: parsed.unit,
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Add')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.space24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Speak a command', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppTheme.space8),
                Text(
                  'Examples: "Add milk", "Add 2 kg onions"',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppTheme.space16),
                RoundedButton(
                  label: _listening ? 'Stop Listening' : 'Start Listening',
                  icon: _listening ? Icons.stop : Icons.mic,
                  onPressed: _toggleListening,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Transcript', style: AppTextStyles.bodySmall),
                const SizedBox(height: AppTheme.space8),
                Text(
                  _transcript.isEmpty ? 'Listening...' : _transcript,
                  style: AppTextStyles.bodyLarge,
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppTheme.space8),
                  Text(_error!, style: AppTextStyles.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space24),
          RoundedButton(
            label: 'Add to Pantry',
            icon: Icons.check,
            onPressed: _applyCommand,
          ),
        ],
      ),
    );
  }
}
