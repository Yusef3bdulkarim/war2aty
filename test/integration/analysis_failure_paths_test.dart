/// The failure paths of the analysis journey, end to end (F27-T17).
///
/// The same real app as `invoice_journey_test.dart`, with one endpoint made to
/// fail the way the backend really fails: a timeout, a refused quota, an
/// online reading that cannot run. What each test is about is not the error
/// page on its own — those have their own widget tests — but that the whole
/// path behaves: what was sent, what was *not* sent, whether a slot was
/// spent, and whether the user can carry on from there.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/app/di/service_locator.dart';
import 'package:war2aty/app/router/app_router.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/analysis/data/datasources/edge_function_analysis_remote_data_source.dart';

import '../support/app_harness.dart';

const _ar = ArStrings();

void main() {
  setUp(getIt.reset);
  tearDown(getIt.reset);

  /// Capture → confirm → on-device reading → the review screen's Continue,
  /// which is where the analysis starts. The on-device route, so nothing here
  /// depends on the online reading.
  Future<void> analyzeOnDevice(AppHarness harness) async {
    final tester = harness.tester;
    await tester.tap(find.text(_ar.homeScanTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(_ar.cameraShutterLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_ar.previewUseImage));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_ar.ocrContinue));
    await tester.pumpAndSettle();
  }

  /// Capture → confirm, on the online route, which runs the reading itself.
  Future<void> readOnline(AppHarness harness) async {
    final tester = harness.tester;
    await tester.tap(find.text(_ar.homeScanTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(_ar.cameraShutterLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_ar.previewUseImage));
    await harness.settleWithIo();
  }

  journeyTest(
    'an analysis that times out costs no slot, keeps the text, and can be '
    'retried',
    (harness) async {
      // The server is designed to time out first and release the slot; the
      // client's own receive timeout is the longer one (`createApiClient`).
      harness.backend.replyOnce(
        kAnalyzeDocumentPath,
        const EdgeReply.transportFailure(DioExceptionType.receiveTimeout),
      );

      await analyzeOnDevice(harness);

      expect(harness.location, AppRoutes.result);
      expect(find.text(_ar.analysisFailedTitle), findsOneWidget);
      expect(find.text(_ar.analysisFailedTipWait), findsOneWidget);
      expect(
        harness.backend.usedToday,
        0,
        reason: 'a failed analysis consumes nothing',
      );
      // The reading is still the user's: the page offers it rather than
      // sending them back to the camera (F23 #11).
      expect(find.text(_ar.analysisFailedTipReadText), findsOneWidget);

      // The retry goes back out on the same session, and this time lands.
      await harness.tester.tap(find.text(_ar.actionRetry));
      await harness.tester.pumpAndSettle();

      expect(find.text('850.50 جنيه'), findsOneWidget);
      expect(harness.backend.countOf(kAnalyzeDocumentPath), 2);
      expect(harness.backend.usedToday, 1);
      final requests = harness.backend.callsTo(kAnalyzeDocumentPath).toList();
      expect(
        requests.first.body!['session_id'],
        requests.last.body!['session_id'],
        reason: 'a retry is the same scan, not a new one',
      );
    },
  );

  journeyTest(
    'an online reading that times out is read on the phone instead, with the '
    'warning that says so',
    boot: (tester) => bootApp(tester, onlineOcrEnabled: true),
    (harness) async {
      // One of the four failures F20 §1 allows the device to work around.
      harness.backend.reply(
        kOcrDocumentPath,
        const EdgeReply.transportFailure(DioExceptionType.receiveTimeout),
      );

      await readOnline(harness);

      expect(harness.location, AppRoutes.ocrReview);
      expect(
        harness.ocrEngine.runs,
        1,
        reason: 'the phone reads the page exactly once',
      );
      expect(find.text(_ar.ocrOnlineFallbackWarning), findsOneWidget);
      expect(find.text(_ar.ocrErrorTitle), findsNothing);

      // And the analysis carries on from the text the phone read.
      await harness.tester.tap(find.text(_ar.ocrOnlineAnalyze));
      await harness.settleWithIo();

      expect(harness.location, AppRoutes.result);
      expect(harness.backend.countOf(kAnalyzeDocumentPath), 1);
      expect(
        harness.backend.callsTo(kAnalyzeDocumentPath).single.body!['ocr_text'],
        contains('المبلغ المطلوب'),
        reason: "the device reading's own text, not the online one's",
      );
      expect(harness.backend.usedToday, 1);
    },
  );

  journeyTest(
    'an online reading that fails any other way is shown as it is — the phone '
    'never reads the page behind it',
    boot: (tester) => bootApp(tester, onlineOcrEnabled: true),
    (harness) async {
      // A deploy fault, not something a weaker reading can paper over
      // (F20 §1).
      harness.backend.reply(
        kOcrDocumentPath,
        EdgeReply.error(500, 'INTERNAL_ERROR'),
      );

      await readOnline(harness);

      expect(harness.location, AppRoutes.ocrReview);
      expect(find.text(_ar.ocrErrorTitle), findsOneWidget);
      expect(find.text(_ar.ocrOnlineFallbackWarning), findsNothing);
      expect(
        harness.ocrEngine.runs,
        0,
        reason: 'Tesseract must not run for a failure outside the allowlist',
      );
      expect(harness.backend.countOf(kAnalyzeDocumentPath), 0);
    },
  );

  journeyTest(
    "the day's last analysis: the limit page names the limit and when it "
    'resets',
    // A limit of 5, not the default 3: the page has to be reading the
    // cached quota rather than happening to match the number this harness
    // starts with.
    boot: (tester) => bootApp(tester, dailyLimit: 5, usedToday: 4),
    (harness) async {
      // The fifth attempt of five: the server refuses it with §31's
      // DAILY_LIMIT_REACHED and the Cairo reset it carries.
      final resetAt = DateTime.now().toUtc().add(const Duration(hours: 5));
      harness.backend.reply(
        kAnalyzeDocumentPath,
        EdgeReply.error(
          429,
          'DAILY_LIMIT_REACHED',
          details: {'reset_at': resetAt.toIso8601String()},
        ),
      );

      await analyzeOnDevice(harness);

      expect(harness.location, AppRoutes.result);
      expect(find.text(_ar.analysisLimitReachedTitle), findsOneWidget);
      expect(
        find.text(_ar.analysisLimitReachedMessageWithLimit(5)),
        findsOneWidget,
        reason: 'the limit comes from the cached quota, not a guess',
      );
      expect(find.text(_ar.analysisLimitTipTomorrow), findsOneWidget);
      expect(harness.backend.usedToday, 4, reason: 'a refusal spends nothing');
    },
  );

  journeyTest(
    'with no connection the page is still read on the phone, and the failure '
    'says it is the connection',
    boot: (tester) => bootApp(tester, connected: false),
    (harness) async {
      harness.backend.reply(
        kAnalyzeDocumentPath,
        const EdgeReply.transportFailure(DioExceptionType.connectionError),
      );

      await analyzeOnDevice(harness);

      expect(
        harness.ocrEngine.runs,
        1,
        reason: 'no connection is exactly what the on-device route is for',
      );
      expect(harness.backend.countOf(kOcrDocumentPath), 0);
      expect(harness.location, AppRoutes.result);
      expect(find.text(_ar.analysisNoInternetTitle), findsOneWidget);
      expect(find.text(_ar.analysisNoInternetTipWifi), findsOneWidget);
      expect(harness.backend.usedToday, 0);
    },
  );

  journeyTest(
    'a declined analysis consent sends nothing at all',
    boot: (tester) => bootApp(tester, analysisConsent: false),
    (harness) async {
      await analyzeOnDevice(harness);

      expect(harness.location, AppRoutes.result);
      expect(find.text(_ar.analysisConsentDeclinedTitle), findsOneWidget);
      expect(
        harness.backend.countOf(kAnalyzeDocumentPath),
        0,
        reason: 'the text never left the phone (F11-T02)',
      );
      expect(
        harness.ocrEngine.runs,
        1,
        reason: 'reading the page on the device needs no consent',
      );
    },
  );
}
