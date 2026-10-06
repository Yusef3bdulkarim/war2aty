import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/features/ocr/domain/entities/ocr_result.dart';
import 'package:war2aty/features/ocr/domain/repositories/ocr_repository.dart';
import 'package:war2aty/features/ocr/domain/services/amount_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/date_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/phone_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/reference_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/text_normalizer.dart';
import 'package:war2aty/features/ocr/domain/services/time_extractor.dart';
import 'package:war2aty/features/ocr/domain/usecases/extract_candidates.dart';
import 'package:war2aty/features/ocr/domain/usecases/extract_document_text.dart';
import 'package:war2aty/features/ocr/presentation/cubit/ocr_processing_cubit.dart';
import 'package:war2aty/features/ocr/presentation/ocr_session_holder.dart';
import 'package:war2aty/features/ocr/presentation/screens/ocr_processing_screen.dart';

import '../../support/pump_app.dart';
import '../../support/ui_audit.dart';

// F04 — the offline OCR wait screen. It had no test of its own until the
// F27-T15 layout sweep needed one; the sweep's coverage guard lists every
// screen on disk, so this file closes that gap as well as auditing it.
const _session = AnalysisSession(id: 's1', imagePath: '/tmp/processed.jpg');

const _pageText = '''
شركة جنوب القاهرة لتوزيع الكهرباء
فاتورة استهلاك شهر مارس 2024
المبلغ المطلوب: 850.50 جنيه
آخر موعد للسداد: 15/04/2024
''';

/// An OCR engine with a scripted answer — `Ok` for the success path, an
/// `Err` for the failure pages, and a too-short `Ok` for the no-text page
/// (`ExtractDocumentText` turns anything under `kMinUsableTextLength`
/// non-whitespace characters into `NoTextDetectedFailure` itself).
final class _ScriptedOcr implements OcrRepository {
  _ScriptedOcr(this.answer);

  final Result<OcrResult, AppFailure> answer;

  @override
  Future<Result<OcrResult, AppFailure>> recognizeText(String imagePath) async =>
      answer;
}

const _extractCandidates = ExtractCandidates(
  normalizer: TextNormalizer(),
  dateExtractor: DateExtractor(),
  timeExtractor: TimeExtractor(),
  amountExtractor: AmountExtractor(),
  phoneExtractor: PhoneExtractor(),
  referenceExtractor: ReferenceExtractor(),
);

OcrProcessingCubit _cubit(
  Result<OcrResult, AppFailure> answer, {
  OcrSessionHolder? holder,
}) => OcrProcessingCubit(
  session: _session,
  extractText: ExtractDocumentText(_ScriptedOcr(answer)),
  extractCandidates: _extractCandidates,
  sessionHolder: holder ?? OcrSessionHolder(),
);

void main() {
  const ar = ArStrings();
  const en = EnStrings();

  /// The three pages the screen can draw. `OcrCompleted` is deliberately not
  /// one of them: it navigates away and keeps the spinner on screen while it
  /// does, so it looks exactly like [_running].
  final running = _cubit(const Ok(OcrResult(originalText: _pageText)));
  final failed = _cubit(const Err(OcrFailure()));
  final noText = _cubit(const Ok(OcrResult(originalText: 'آ')));

  late List<String> events;

  setUp(() => events = []);

  Future<void> pumpScreen(
    WidgetTester tester,
    OcrProcessingCubit cubit, {
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
    bool settle = true,
  }) => pumpApp(
    tester,
    BlocProvider<OcrProcessingCubit>.value(
      value: cubit,
      child: OcrProcessingScreen(
        onCompleted: () => events.add('completed'),
        onRetake: () => events.add('retake'),
        onPickAnother: () => events.add('pickAnother'),
      ),
    ),
    locale: locale,
    textScaler: textScaler,
    // The waiting page spins forever; `pumpAndSettle` would never return.
    settle: settle,
  );

  auditScreenLayout('OcrProcessingScreen', (tester, locale, scaler) async {
    // The failure page is the tall one — an icon, two paragraphs and two
    // full-width buttons — so it is what the sweep holds to a phone.
    await failed.process();
    await pumpScreen(
      tester,
      failed,
      locale: locale,
      textScaler: scaler,
      settle: false,
    );
  });

  group('OcrProcessingScreen', () {
    testWidgets('waits with a spinner while the engine runs', (tester) async {
      await pumpScreen(tester, running, settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(ar.ocrProcessing), findsOneWidget);
    });

    testWidgets('a failed reading offers retake and pick-another', (
      tester,
    ) async {
      await failed.process();
      await pumpScreen(tester, failed, settle: false);

      expect(find.text(ar.ocrErrorTitle), findsOneWidget);
      expect(find.text(ar.ocrErrorMessage), findsOneWidget);

      await tester.tap(find.text(ar.ocrRetake));
      await tester.tap(find.text(ar.ocrPickAnother));

      expect(events, ['retake', 'pickAnother']);
    });

    testWidgets('too little text gets its own page, not the error one', (
      tester,
    ) async {
      await noText.process();
      await pumpScreen(tester, noText, settle: false);

      expect(find.text(ar.ocrNoTextTitle), findsOneWidget);
      expect(find.text(ar.ocrErrorTitle), findsNothing);
    });

    testWidgets('a finished reading hands off without being tapped', (
      tester,
    ) async {
      final holder = OcrSessionHolder();
      final cubit = _cubit(
        const Ok(OcrResult(originalText: _pageText)),
        holder: holder,
      );
      addTearDown(cubit.close);

      await pumpScreen(tester, cubit, settle: false);
      await cubit.process();
      await tester.pump();

      expect(events, ['completed']);
      // Still the spinner, never a flash of the result (the screen's own
      // reason for drawing `_buildProcessing` on `OcrCompleted`).
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('reads in English too', (tester) async {
      await failed.process();
      await pumpScreen(
        tester,
        failed,
        locale: AppLocalizations.english,
        settle: false,
      );

      expect(find.text(en.ocrErrorTitle), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(OcrProcessingScreen))),
        TextDirection.ltr,
      );
    });
  });

  tearDownAll(() async {
    await running.close();
    await failed.close();
    await noText.close();
  });
}
