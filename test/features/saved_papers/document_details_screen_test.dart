import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/audio_reader_cubit.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_speed.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_voice.dart';
import 'package:war2aty/core/documents/analysis_status.dart';
import 'package:war2aty/core/documents/usecases/build_analysis_result.dart';
import 'package:war2aty/core/documents/usecases/delete_document.dart';
import 'package:war2aty/core/documents/usecases/set_document_note.dart';
import 'package:war2aty/core/documents/usecases/update_document.dart';
import 'package:war2aty/core/documents/usecases/watch_document.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/widgets/result_header_card.dart';
import 'package:war2aty/core/widgets/result_summary_card.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/build_reading_text.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/pause_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/resume_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/select_voice_for_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/set_reading_speed.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/start_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/stop_reading.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/watch_reading_events.dart';
import 'package:war2aty/features/saved_papers/presentation/cubit/document_details_cubit.dart';
import 'package:war2aty/features/saved_papers/presentation/screens/document_details_screen.dart';

import '../../support/fakes.dart';
import '../../support/mirrored_icon.dart';
import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();
  const en = EnStrings();

  late FakeDocumentsRepository repository;
  late DocumentDetailsCubit cubit;
  late FakeTextToSpeechService tts;
  late AudioReaderCubit audioReaderCubit;

  setUp(() {
    repository = FakeDocumentsRepository();
    cubit = DocumentDetailsCubit(
      WatchDocument(repository),
      const BuildAnalysisResult(),
      SetDocumentNote(repository),
      UpdateDocument(repository),
      DeleteDocument(repository),
      documentId: 'doc-1',
    );
    tts = FakeTextToSpeechService();
    audioReaderCubit = AudioReaderCubit(
      StartReading(
        const BuildReadingText(),
        const SelectVoiceForReading(),
        tts,
      ),
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
    // `DocumentDetailsCubit.close()` awaits cancelling its subscription on
    // `repository`'s stream — matching this file's existing convention
    // (unlike `AudioReaderCubit`'s plain `close()`), neither is awaited here.
    unawaited(cubit.close());
    unawaited(repository.dispose());
    await audioReaderCubit.close();
    await tts.dispose();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    VoidCallback? onClose,
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
    bool settle = true,
  }) => pumpApp(
    tester,
    MultiBlocProvider(
      providers: [
        BlocProvider<DocumentDetailsCubit>.value(value: cubit),
        BlocProvider<AudioReaderCubit>.value(value: audioReaderCubit),
      ],
      child: DocumentDetailsScreen(onClose: onClose),
    ),
    locale: locale,
    textScaler: textScaler,
    settle: settle,
  );

  group('DocumentDetailsScreen', () {
    testWidgets('shows a spinner before the database answers', (tester) async {
      // Don't call start() — the cubit's initial state is Loading, and an
      // async* generator would yield (and transition) before the first frame.
      await pumpScreen(tester, settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(ar.documentDetailsTitle), findsNothing);
    });

    testWidgets('shows the record once the database answers', (tester) async {
      repository.emitDocument(savedDocumentWith(title: 'فاتورة كهرباء'));
      cubit.start();

      await pumpScreen(tester);

      expect(find.text(ar.documentDetailsTitle), findsOneWidget);
      expect(find.byType(ResultHeaderCard), findsOneWidget);
      expect(find.text('فاتورة كهرباء'), findsOneWidget);
      expect(find.byType(ResultSummaryCard), findsOneWidget);
    });

    testWidgets('flags a partial document the same way the result page does', (
      tester,
    ) async {
      repository.emitDocument(
        savedDocumentWith(status: AnalysisStatus.partial),
      );
      cubit.start();

      await pumpScreen(tester);

      expect(find.text(ar.resultPartialBanner), findsOneWidget);
    });

    testWidgets('says so when the document is gone', (tester) async {
      repository.emitDocument(null);
      cubit.start();

      await pumpScreen(tester);

      expect(find.text(ar.documentDetailsNotFoundTitle), findsOneWidget);
    });

    testWidgets('says so when the read failed', (tester) async {
      repository.emitDocumentFailure();
      cubit.start();

      await pumpScreen(tester);

      expect(find.text(ar.documentDetailsErrorTitle), findsOneWidget);
    });

    testWidgets('fires onClose from the not-found page', (tester) async {
      repository.emitDocument(null);
      cubit.start();
      var closed = 0;

      await pumpScreen(tester, onClose: () => closed++);
      await tester.tap(find.text(ar.documentDetailsBackToList));
      await tester.pumpAndSettle();

      expect(closed, 1);
    });

    testWidgets('renders in English', (tester) async {
      repository.emitDocument(savedDocumentWith());
      cubit.start();

      await pumpScreen(tester, locale: AppLocalizations.english);

      expect(find.text(en.documentDetailsTitle), findsOneWidget);
    });

    testWidgets('the back icon mirrors under English (F12-T03)', (
      tester,
    ) async {
      repository.emitDocument(savedDocumentWith());
      cubit.start();

      await pumpScreen(tester);
      expect(
        mirrorScaleX(tester, StrokeGlyph.arrowBack),
        1,
        reason: 'RTL: points right as drawn',
      );

      await pumpScreen(tester, locale: AppLocalizations.english);
      expect(
        mirrorScaleX(tester, StrokeGlyph.arrowBack),
        -1,
        reason: 'LTR: mirrored to point left',
      );
    });

    testWidgets('survives large text without overflowing', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      repository.emitDocument(savedDocumentWith());
      cubit.start();

      await pumpScreen(tester, textScaler: const TextScaler.linear(2));

      expect(tester.takeException(), isNull);
    });

    // Notes (F08-T09).
    testWidgets('shows the empty note state when no note exists', (
      tester,
    ) async {
      repository.emitDocument(savedDocumentWith());
      cubit.start();

      await pumpScreen(tester);

      expect(find.text(ar.documentNoteHeading), findsOneWidget);
      expect(find.text(ar.documentNoteEmpty), findsOneWidget);
      expect(find.text(ar.documentNoteAdd), findsOneWidget);
    });

    testWidgets('shows the note when one has been saved', (tester) async {
      repository.emitDocument(
        savedDocumentWith(note: 'دفعت الفاتورة يوم 22 أغسطس.'),
      );
      cubit.start();

      await pumpScreen(tester);

      expect(find.text('دفعت الفاتورة يوم 22 أغسطس.'), findsOneWidget);
      expect(find.text(ar.documentNoteEdit), findsOneWidget);
      expect(find.text(ar.documentNoteDelete), findsOneWidget);
      // The empty prompt must not appear alongside an existing note.
      expect(find.text(ar.documentNoteEmpty), findsNothing);
    });

    testWidgets('opens the editor when add is tapped', (tester) async {
      repository.emitDocument(savedDocumentWith());
      cubit.start();

      await pumpScreen(tester);
      // The pinned bottom action bar (F11-T07's "listen aloud" bar) now
      // shares the viewport with the scrollable note section, so the note
      // button is no longer guaranteed on-screen without scrolling first.
      await tester.ensureVisible(find.text(ar.documentNoteAdd));
      await tester.tap(find.text(ar.documentNoteAdd));
      await tester.pumpAndSettle();

      // The editor sheet should be visible with the hint text.
      expect(find.text(ar.documentNoteHint), findsOneWidget);
      expect(find.text(ar.documentNoteSave), findsOneWidget);
    });

    testWidgets('opens the editor pre-filled when edit is tapped', (
      tester,
    ) async {
      repository.emitDocument(savedDocumentWith(note: 'ملاحظة قديمة'));
      cubit.start();

      await pumpScreen(tester);
      // Same as above: scroll the note button into view past the pinned
      // bottom action bar before tapping it.
      await tester.ensureVisible(find.text(ar.documentNoteEdit));
      await tester.tap(find.text(ar.documentNoteEdit));
      await tester.pumpAndSettle();

      // The existing note text should be pre-filled in the field.
      expect(find.widgetWithText(TextField, 'ملاحظة قديمة'), findsOneWidget);
    });

    testWidgets('shows delete confirmation dialog', (tester) async {
      repository.emitDocument(savedDocumentWith(note: 'ملاحظة'));
      cubit.start();

      await pumpScreen(tester);
      // Same as above: scroll the note button into view past the pinned
      // bottom action bar before tapping it.
      await tester.ensureVisible(find.text(ar.documentNoteDelete));
      await tester.tap(find.text(ar.documentNoteDelete));
      await tester.pumpAndSettle();

      expect(find.text(ar.documentNoteDeleteConfirmTitle), findsOneWidget);
      expect(find.text(ar.documentNoteDeleteConfirmMessage), findsOneWidget);
    });

    // Delete document (F08-T11).
    testWidgets('overflow menu shows the delete action', (tester) async {
      repository.emitDocument(savedDocumentWith());
      cubit.start();

      await pumpScreen(tester);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text(ar.documentDeleteAction), findsOneWidget);
    });

    testWidgets('delete action shows a confirmation dialog', (tester) async {
      repository.emitDocument(savedDocumentWith());
      cubit.start();

      await pumpScreen(tester);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ar.documentDeleteAction));
      await tester.pumpAndSettle();

      expect(find.text(ar.documentDeleteConfirmTitle), findsOneWidget);
      expect(find.text(ar.documentDeleteConfirmMessage), findsOneWidget);
    });

    testWidgets('cancelling the delete dialog does nothing', (tester) async {
      repository.emitDocument(savedDocumentWith());
      cubit.start();

      await pumpScreen(tester);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ar.documentDeleteAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ar.actionCancel));
      await tester.pumpAndSettle();

      expect(repository.lastDeletedId, isNull);
    });

    testWidgets('confirming delete calls the cubit and fires onClose', (
      tester,
    ) async {
      repository.emitDocument(savedDocumentWith());
      cubit.start();
      var closed = 0;

      await pumpScreen(tester, onClose: () => closed++);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ar.documentDeleteAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ar.actionDelete));
      await tester.pumpAndSettle();

      expect(repository.lastDeletedId, 'doc-1');
      expect(closed, 1);
      expect(find.text(ar.documentDeleted), findsOneWidget);
    });

    testWidgets('shows error feedback when delete fails', (tester) async {
      repository.deleteOutcome = const Err(LocalDatabaseFailure());
      repository.emitDocument(savedDocumentWith());
      cubit.start();
      var closed = 0;

      await pumpScreen(tester, onClose: () => closed++);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ar.documentDeleteAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ar.actionDelete));
      await tester.pumpAndSettle();

      expect(find.text(ar.documentDeleteError), findsOneWidget);
      expect(closed, 0, reason: 'should not navigate away on failure');
    });
  });
}
