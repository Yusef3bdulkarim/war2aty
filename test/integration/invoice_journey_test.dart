/// The vertical slice, end to end (F27-T17).
///
/// Each test drives the shipped app from a tap on Home to the rows the
/// journey leaves behind: capture → read → analyze → result → save →
/// reminder → Home. Everything between the camera and the Edge Functions is
/// the real thing — see `support/app_harness.dart` for what is faked and why.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/app/di/service_locator.dart';
import 'package:war2aty/app/router/app_router.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/network/interceptors/request_id_interceptor.dart';
import 'package:war2aty/core/time/document_date_label.dart';
import 'package:war2aty/core/usage/usage_remote_data_source.dart';
import 'package:war2aty/core/widgets/result_action_bar.dart';
import 'package:war2aty/features/analysis/data/datasources/edge_function_analysis_remote_data_source.dart';
import 'package:war2aty/features/capture/presentation/screens/camera_capture_screen.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

const _ar = ArStrings();

/// How long the save confirmation SnackBar stays up
/// (`SaveDocumentListener`), with a second of margin on top.
const Duration _saveFeedback = Duration(seconds: 4);

void main() {
  setUp(getIt.reset);
  tearDown(getIt.reset);

  journeyTest('the app boots over the real dependency graph onto Home', (
    harness,
  ) async {
    expect(harness.location, AppRoutes.home);
    expect(find.text(_ar.homeScanTitle), findsOneWidget);
    expect(harness.tester.takeException(), isNull);
  });

  journeyTest('the camera opens on a granted permission', (harness) async {
    await harness.tester.tap(find.text(_ar.homeScanTitle));
    await harness.tester.pumpAndSettle();

    expect(find.byType(CameraCaptureScreen), findsOneWidget);
    expect(harness.camera.initializeCount, 1);
    expect(find.byKey(FakeCameraPreview.key), findsOneWidget);
  });

  journeyTest('the shutter lands on the preview of the captured photo', (
    harness,
  ) async {
    await harness.tester.tap(find.text(_ar.homeScanTitle));
    await harness.tester.pumpAndSettle();
    await harness.tester.tap(find.bySemanticsLabel(_ar.cameraShutterLabel));
    await harness.tester.pumpAndSettle();

    expect(harness.camera.captureCount, 1);
    expect(harness.location, AppRoutes.previewWith(harness.photoPath));
  });

  journeyTest('the on-device route reads the page and reviews its text', (
    harness,
  ) async {
    await harness.tester.tap(find.text(_ar.homeScanTitle));
    await harness.tester.pumpAndSettle();
    await harness.tester.tap(find.bySemanticsLabel(_ar.cameraShutterLabel));
    await harness.tester.pumpAndSettle();
    await harness.tester.tap(find.text(_ar.previewUseImage));
    await harness.tester.pumpAndSettle();

    expect(harness.location, AppRoutes.ocrReview);
    expect(harness.ocrEngine.runs, 1);
    expect(harness.backend.countOf(kOcrDocumentPath), 0);
    expect(find.text(_ar.ocrContinue), findsOneWidget);
  });

  journeyTest(
    'the on-device journey: capture → read → analyze → result → save → '
    'reminder → Home',
    (harness) async {
      final tester = harness.tester;

      // ── Capture ────────────────────────────────────────────────────────
      await tester.tap(find.text(_ar.homeScanTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(_ar.cameraShutterLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_ar.previewUseImage));
      await tester.pumpAndSettle();

      // ── Read, on the phone ─────────────────────────────────────────────
      expect(harness.location, AppRoutes.ocrReview);
      expect(harness.ocrEngine.runs, 1);
      expect(
        harness.backend.countOf(kOcrDocumentPath),
        0,
        reason: 'the on-device route must not send the image anywhere',
      );

      // ── Analyze ────────────────────────────────────────────────────────
      await tester.tap(find.text(_ar.ocrContinue));
      await tester.pumpAndSettle();

      expect(harness.location, AppRoutes.result);
      expect(harness.backend.countOf(kAnalyzeDocumentPath), 1);
      // The fixture's own figures, through the real DTO, mapper and
      // formatters: the amount as money, the deadline as a Cairo-day date.
      expect(find.text('850.50 جنيه'), findsOneWidget);
      expect(find.text('آخر موعد للسداد'), findsWidgets);
      expect(
        find.text(formatDocumentDate(_ar, harness.deadline)),
        findsWidgets,
      );

      final call = harness.backend.callsTo(kAnalyzeDocumentPath).single;
      final request = call.body!;
      // The real interceptor chain ran on the way out: the publishable key,
      // the session's own bearer token and a correlation id.
      expect(call.headers['apikey'], isNotNull);
      expect(call.headers['Authorization'], startsWith('Bearer '));
      expect(call.headers[kRequestIdHeader], isNotNull);
      expect(request['ocr_text'], contains('المبلغ المطلوب'));
      expect(request['input_type'], 'text');
      expect(
        request.keys,
        isNot(contains('image')),
        reason: 'the analysis provider never sees the image (§7)',
      );

      // The server consumed one of the three slots, and the app noticed.
      expect(harness.backend.usedToday, 1);
      expect(harness.backend.countOf(kGetUsagePath), greaterThan(1));

      // ── Save: the result only, never the picture unless asked ──────────
      await tester.tap(find.text(_ar.resultSavePaper));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_ar.actionSave));
      await tester.pumpAndSettle();

      expect(find.text(_ar.documentSaved), findsOneWidget);
      final saved = await harness.savedDocuments();
      expect(saved, hasLength(1));
      expect(saved.single.title, 'فاتورة كهرباء');
      expect(
        harness.documentImages.stored,
        isEmpty,
        reason: '«النتيجة فقط» keeps no image',
      );

      // The save confirmation covers the action bar until it retires, so the
      // next tap waits it out rather than landing on the SnackBar.
      await tester.pump(_saveFeedback);
      await tester.pumpAndSettle();

      // ── Reminder, for the deadline the paper carries ───────────────────
      // The bar's reminder action, not the dates card's — the bar is the one
      // that asks which date first (UX §5.8).
      await tester.tap(
        find.descendant(
          of: find.byType(ResultActionBar),
          matching: find.text(_ar.resultCreateReminder),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(_ar.resultDateReminderWorthy));
      await tester.pumpAndSettle();

      expect(harness.location, AppRoutes.reminderCreate);

      await tester.tap(find.text(_ar.reminderSaveAction));
      await tester.pumpAndSettle();

      expect(harness.location, AppRoutes.reminderSuccess);
      final reminders = await harness.savedReminders();
      expect(reminders, hasLength(1));
      expect(
        reminders.single.documentId,
        saved.single.id,
        reason: 'the paper was already saved, so the two are linked',
      );
      final alerts = await harness.savedAlerts();
      expect(alerts, hasLength(1), reason: 'the form opened with one alert');
      expect(
        harness.notifications.scheduled,
        hasLength(alerts.length),
        reason: 'every alert the user confirmed reached the OS',
      );

      // ── Home, with the paper and the count the journey earned ──────────
      await tester.tap(find.text(_ar.actionBack));
      await tester.pumpAndSettle();

      expect(harness.location, AppRoutes.home);
      expect(
        find.text('فاتورة كهرباء'),
        findsWidgets,
        reason: 'the paper is on the recent strip',
      );
      expect(find.text(_ar.homeUsageRemaining(2)), findsWidgets);
      // The scan's working directory went with the result route (F27-T15):
      // an unsaved page image must not outlive the screen that read it.
      expect(
        harness.sessions.hasSession(harness.sessions.created.single),
        isFalse,
      );
      expect(harness.backend.unexpectedPaths, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  journeyTest(
    'the online journey: the image is read off the device, the analysis is '
    'not',
    boot: (tester) => bootApp(tester, onlineOcrEnabled: true),
    (harness) async {
      final tester = harness.tester;

      await tester.tap(find.text(_ar.homeScanTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(_ar.cameraShutterLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_ar.previewUseImage));
      // The online reading reads the photo off disk and encodes it on a real
      // isolate — neither finishes under `FakeAsync`.
      await harness.settleWithIo();

      // ── Read, online ───────────────────────────────────────────────────
      expect(harness.location, AppRoutes.ocrReview);
      expect(harness.backend.countOf(kOcrDocumentPath), 1);
      expect(
        harness.ocrEngine.runs,
        0,
        reason: 'once online is chosen, the phone does not read the page too',
      );

      final imageRequest = harness.backend
          .callsTo(kOcrDocumentPath)
          .single
          .body!;
      expect(imageRequest['input_type'], 'image');
      final image = imageRequest['image'] as Map<String, dynamic>;
      expect(image['data'], isNotEmpty);
      expect(image['mime_type'], 'image/jpeg');
      // Exactly the §29b fields — nothing about the device, the location or
      // the capture rides along with the picture (§7).
      expect(imageRequest.keys.toSet(), <String>{
        'schema_version',
        'session_id',
        'installation_id',
        'app_version',
        'input_type',
        'image',
      });
      expect(image.keys.toSet(), <String>{'data', 'mime_type'});

      // ── Analyze: text only ─────────────────────────────────────────────
      await tester.tap(find.text(_ar.ocrOnlineAnalyze));
      await harness.settleWithIo();

      expect(harness.location, AppRoutes.result);
      expect(find.text('850.50 جنيه'), findsOneWidget);
      expect(harness.backend.countOf(kAnalyzeDocumentPath), 1);

      final analyzeRequest = harness.backend
          .callsTo(kAnalyzeDocumentPath)
          .single
          .body!;
      expect(analyzeRequest['input_type'], 'text');
      expect(
        analyzeRequest.keys,
        isNot(contains('image')),
        reason: 'the analysis provider never sees the image (§7)',
      );
      expect(
        analyzeRequest['ocr_text'],
        contains('850.50'),
        reason: 'the reviewed text from the online reading is what was sent',
      );
      expect(harness.backend.usedToday, 1);
      expect(harness.backend.unexpectedPaths, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  journeyTest(
    'a reminder made before the paper is saved is kept, unlinked — and the '
    'result page is not there to go back to',
    (harness) async {
      final tester = harness.tester;

      await tester.tap(find.text(_ar.homeScanTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(_ar.cameraShutterLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_ar.previewUseImage));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_ar.ocrContinue));
      await tester.pumpAndSettle();

      // Straight to the reminder, with nothing saved yet.
      await tester.tap(
        find.descendant(
          of: find.byType(ResultActionBar),
          matching: find.text(_ar.resultCreateReminder),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(_ar.resultDateReminderWorthy));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_ar.reminderSaveAction));
      await tester.pumpAndSettle();

      final reminders = await harness.savedReminders();
      expect(reminders, hasLength(1));
      expect(
        reminders.single.documentId,
        isNull,
        reason: 'a reminder does not require the paper to be kept',
      );
      expect(await harness.savedDocuments(), isEmpty);

      // Both ways off the confirmation leave the scan for good (`go`, not
      // `pop`), so saving the paper afterwards is not a path the user has:
      // the save has to come first for the two to be linked.
      await tester.tap(find.text(_ar.reminderSuccessViewAction));
      await tester.pumpAndSettle();

      expect(harness.location, AppRoutes.reminders);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(_ar.resultSavePaper), findsNothing);
    },
  );
}
