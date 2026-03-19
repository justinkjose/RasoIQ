import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptOCRService {
  static Future<List<String>> extractLines(InputImage image) async {
    final recognizer = TextRecognizer();
    try {
      final result = await recognizer.processImage(image);
      final lines = <String>[];
      for (final block in result.blocks) {
        for (final line in block.lines) {
          lines.add(line.text);
        }
      }
      return lines;
    } finally {
      await recognizer.close();
    }
  }
}
