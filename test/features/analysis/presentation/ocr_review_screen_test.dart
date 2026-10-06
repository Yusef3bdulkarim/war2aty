import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/analysis/usecases/get_analysis_consent.dart';
import 'package:war2aty/core/audio/audio_reader_cubit.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_speed.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_voice.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_image_request.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_request.dart';
import 'package:war2aty/features/analysis/domain/repositories/analysis_repository.dart';
import 'package:war2aty/features/analysis/domain/usecases/ocr_image.dart';
import 'package:war2aty/features/analysis/presentation/cubit/ocr_review_cubit.dart';
import 'package:war2aty/features/analysis/presentation/image_analysis_session_holder.dart';
import 'package:war2aty/features/analysis/presentation/screens/ocr_review_screen.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/build_reading_text.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/pause_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/resume_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/select_voice_for_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/set_reading_speed.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/start_raw_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/start_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/stop_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/watch_reading_events.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/ocr/domain/entities/extraction_result.dart';
import 'package:war2aty/features/ocr/domain/entities/normalized_ocr_text.dart';
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

import '../../../support/fakes.dart';
import '../../../support/pump_app.dart';
import '../../../support/ui_audit.dart';

const _ar = ArStrings();
const _en = EnStrings();

const _session = AnalysisSession(id: 'session-1', imagePath: '/tmp/paper.jpg');
const _photo = CapturedPhoto('/tmp/corrected.jpg');
const _pageText = 'فاتورة كهرباء المبلغ المطلوب 850 جنيه';

const _extraction = ExtractionResult(
  text: NormalizedOcrText(originalText: _pageText, cleanedText: _pageText),
  detectedLanguages: ['ar'],
);

/// Answers the online reading with [answer].
final class _FakeAnalysisRepository implements AnalysisRepository {
  _FakeAnalysisRepository(this.answer);

  final Result<ExtractionResult, AppFailure> answer;

  @override
  Future<Result<DocumentAnalysis, AppFailure>> analyze(
    AnalysisRequest request,
  ) => throw UnimplementedError('the review screen never analyses');

  @override
  Future<Result<ExtractionResult, AppFailure>> ocrImage(
    AnalysisImageRequest request,
  ) async => answer;
}

/// The on-device reader: always finds [_pageText].
final class _FakeDeviceOcr implements OcrRepository {
  @override
  Future<Result<OcrResult, AppFailure>> recognizeText(String imagePath) async =>
      const Ok(OcrResult(originalText: _pageText));
}

ExtractCandidates _extractCandidates() => const ExtractCandidates(
  normalizer: TextNormalizer(),
  dateExtractor: DateExtractor(),
  timeExtractor: TimeExtractor(),
  amountExtractor: AmountExtractor(),
  phoneExtractor: PhoneExtractor(),
  referenceExtractor: ReferenceExtractor(),
);

/// A cubit whose online reading answers [onlineAnswer] — `Ok` for a normal
/// online review, an allowlisted `Err` for the on-device fallback.
OcrReviewCubit _onlineCubit(
  Result<ExtractionResult, AppFailure> onlineAnswer,
) => OcrReviewCubit(
  session: _session,
  photo: _photo,
  ocrImage: OcrImage(_FakeAnalysisRepository(onlineAnswer)),
  extractCandidates: _extractCandidates(),
  getAnalysisConsent: GetAnalysisConsent(FakeAnalysisConsentStore()),
  imageHolder: ImageAnalysisSessionHolder(),
  extractDocumentText: ExtractDocumentText(_FakeDeviceOcr()),
);

void main() {
  late FakeTextToSpeechService tts;
  late AudioReaderCubit audioReaderCubit;
  late OcrReviewCubit cubit;

  setUp(() {
    tts = FakeTextToSpeechService();
    audioReaderCubit = AudioReaderCubit(
      StartReading(
        const BuildReadingText(),
        const SelectVoiceForReading(),
        tts,
      ),
      StartRawReading(const SelectVoiceForReading(), tts),
      StopReading(tts),
      PauseReading(tts),
      ResumeReading(tts),
      SetReadingSpeed(tts),
      WatchReadingEvents(tts),
      GetDefaultReadingSpeed(FakeDefaultReadingSpeedStore()),
      GetDefaultReadingVoice(FakeDefaultReadingVoiceStore()),
    );
  });

  tearDown(() async {
    await cubit.close();
    await audioReaderCubit.close();
    await tts.dispose();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
  }) => pumpApp(
    tester,
    MultiBlocProvider(
      providers: [
        BlocProvider<OcrReviewCubit>.value(value: cubit),
        BlocProvider<AudioReaderCubit>.value(value: audioReaderCubit),
      ],
      child: OcrReviewScreen(
        onAnalyze: () {},
        onRetake: () {},
        onPickAnother: () {},
      ),
    ),
    locale: locale,
    textScaler: textScaler,
  );

  auditScreenLayout('OcrReviewScreen', (tester, locale, scaler) async {
    cubit = OcrReviewCubit.offline(
      session: _session,
      extractCandidates: _extractCandidates(),
    )..loadOffline(_extraction);
    await pumpScreen(tester, locale: locale, textScaler: scaler);
  });

  group('OcrReviewScreen quality banners (F20-T23)', () {
    testWidgets('the online fallback shows its own banner, not the offline '
        'one, and keeps the online title and button', (tester) async {
      cubit = _onlineCubit(const Err(OnlineOcrUnavailableFailure()));
      await cubit.runOcr();

      await pumpScreen(tester);

      expect(find.text(_ar.ocrOnlineFallbackWarning), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text(_ar.ocrOfflineQualityWarning), findsNothing);
      expect(find.byIcon(Icons.wifi_off), findsNothing);
      expect(find.text(_ar.ocrOnlineReviewTitle), findsOneWidget);
      expect(find.text(_ar.ocrOnlineAnalyze), findsOneWidget);
    });

    testWidgets('a normal online reading shows no banner', (tester) async {
      cubit = _onlineCubit(const Ok(_extraction));
      await cubit.runOcr();

      await pumpScreen(tester);

      expect(find.text(_ar.ocrOnlineFallbackWarning), findsNothing);
      expect(find.text(_ar.ocrOfflineQualityWarning), findsNothing);
    });

    testWidgets('the offline route keeps its own banner', (tester) async {
      cubit = OcrReviewCubit.offline(
        session: _session,
        extractCandidates: _extractCandidates(),
      )..loadOffline(_extraction);

      await pumpScreen(tester);

      expect(find.text(_ar.ocrOfflineQualityWarning), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(find.text(_ar.ocrOnlineFallbackWarning), findsNothing);
      expect(find.text(_ar.ocrContinue), findsOneWidget);
    });

    testWidgets('the fallback banner reads right to left in Arabic', (
      tester,
    ) async {
      cubit = _onlineCubit(const Err(AiProviderRateLimitFailure()));
      await cubit.runOcr();

      await pumpScreen(tester);

      final banner = find.text(_ar.ocrOnlineFallbackWarning);
      expect(Directionality.of(tester.element(banner)), TextDirection.rtl);
      // In RTL the icon leads on the right, before the text.
      final icon = find.byIcon(Icons.warning_amber_rounded);
      expect(
        tester.getTopRight(icon).dx,
        greaterThan(tester.getTopRight(banner).dx),
      );
    });

    testWidgets('the fallback banner survives Large Text without overflow', (
      tester,
    ) async {
      cubit = _onlineCubit(const Err(RequestTimeoutFailure()));
      await cubit.runOcr();

      await pumpScreen(tester, textScaler: const TextScaler.linear(2));

      expect(find.text(_ar.ocrOnlineFallbackWarning), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the fallback banner follows the locale', (tester) async {
      cubit = _onlineCubit(const Err(NoInternetFailure()));
      await cubit.runOcr();

      await pumpScreen(tester, locale: AppLocalizations.english);

      expect(find.text(_en.ocrOnlineFallbackWarning), findsOneWidget);
      expect(find.text(_ar.ocrOnlineFallbackWarning), findsNothing);
    });
  });
}
