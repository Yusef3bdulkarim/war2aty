import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/ocr_result.dart';
import '../../domain/services/ocr_engine.dart';

/// [OcrEngine] backed by Tesseract 4 via [FlutterTesseractOcr].
///
/// Runs Arabic + English recognition in a single pass (`ara+eng`).
/// Trained-data files live in `assets/tessdata/` and are copied to the
/// device on first launch by the plugin automatically.
final class TesseractOcrEngine implements OcrEngine {
  const TesseractOcrEngine();

  @override
  Future<Result<OcrResult, AppFailure>> extractText(String imagePath) async {
    try {
      final text = await FlutterTesseractOcr.extractText(
        imagePath,
        language: 'ara+eng',
      );

      return Ok(OcrResult(originalText: text));
    } on Object {
      return const Err(OcrFailure());
    }
  }
}
