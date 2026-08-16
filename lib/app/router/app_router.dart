import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/audio_reader_cubit.dart';
import '../../core/documents/analysis_date.dart';
import '../../core/documents/recent_document.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/reminders/reminder.dart';
import '../../core/storage/analysis_session.dart';
import '../../features/analysis/domain/entities/analysis_source.dart';
import '../../features/analysis/presentation/cubit/analysis_result_cubit.dart';
import '../../features/analysis/presentation/cubit/analysis_result_state.dart';
import '../../features/analysis/presentation/cubit/ocr_review_cubit.dart';
import '../../features/analysis/presentation/image_analysis_session_holder.dart';
import '../../features/analysis/presentation/screens/analysis_result_screen.dart';
import '../../features/analysis/presentation/screens/ocr_review_screen.dart';
import '../../features/capture/domain/entities/capture_source.dart';
import '../../features/capture/presentation/cubit/camera_capture_cubit.dart';
import '../../features/capture/presentation/cubit/camera_permission_cubit.dart';
import '../../features/capture/presentation/cubit/gallery_picker_cubit.dart';
import '../../features/capture/presentation/cubit/image_preview_cubit.dart';
import '../../features/capture/presentation/screens/camera_capture_screen.dart';
import '../../features/capture/presentation/screens/camera_permission_gate.dart';
import '../../features/capture/presentation/screens/gallery_picker_screen.dart';
import '../../features/capture/presentation/screens/image_preview_screen.dart';
import '../../features/home/presentation/cubit/home_cubit.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/ocr/presentation/cubit/ocr_processing_cubit.dart';
import '../../features/ocr/presentation/ocr_session_holder.dart';
import '../../features/ocr/presentation/screens/ocr_processing_screen.dart';
import '../../features/onboarding/presentation/cubit/onboarding_cubit.dart';
import '../../features/onboarding/presentation/cubit/onboarding_state.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/privacy_screen.dart';
import '../../features/reminders/presentation/cubit/reminder_details_cubit.dart';
import '../../features/reminders/presentation/cubit/reminder_form_cubit.dart';
import '../../features/reminders/presentation/cubit/reminders_cubit.dart';
import '../../features/reminders/presentation/models/reminder_from_document_args.dart';
import '../../features/reminders/presentation/screens/reminder_details_screen.dart';
import '../../features/reminders/presentation/screens/reminder_form_screen.dart';
import '../../features/reminders/presentation/screens/reminder_success_screen.dart';
import '../../features/reminders/presentation/screens/reminders_list_screen.dart';
import '../../features/saved_papers/presentation/cubit/document_details_cubit.dart';
import '../../features/saved_papers/presentation/cubit/document_details_state.dart';
import '../../features/saved_papers/presentation/cubit/documents_list_cubit.dart';
import '../../features/saved_papers/presentation/cubit/save_document_cubit.dart';
import '../../features/saved_papers/presentation/cubit/save_document_state.dart';
import '../../features/saved_papers/presentation/screens/document_details_screen.dart';
import '../../features/saved_papers/presentation/screens/documents_list_screen.dart';
import '../../features/saved_papers/presentation/widgets/save_document_listener.dart';
import '../../features/saved_papers/presentation/widgets/save_mode_sheet.dart';
import '../../features/settings/presentation/cubit/settings_cubit.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../di/service_locator.dart';
import '../shell/scaffold_with_nav_bar.dart';

/// Route path constants.
abstract final class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String privacy = '/privacy';
  static const String home = '/home';
  static const String saved = '/saved';
  static const String reminders = '/reminders';
  static const String settings = '/settings';
  static const String capture = '/capture';
  static const String preview = '/preview';
  static const String ocr = '/ocr';
  static const String ocrReview = '/ocr-review';
  static const String result = '/result';
  static const String documentDetails = '/documents';
  static const String reminderCreate = '/reminders/create';
  static const String reminderManual = '/reminders/manual';
  static const String reminderSuccess = '/reminders/success';

  /// The first-run flow, which sits outside the bottom-nav shell.
  static const Set<String> firstRun = {onboarding, privacy};

  /// One saved document's details (F08-T08), by its id.
  static String documentDetailsWith(String id) => '$documentDetails/$id';

  /// One reminder's details (F09-T12), by its id.
  static String reminderDetailsWith(String id) => '$reminders/$id';

  /// The capture route for [source].
  ///
  /// The choice rides in the query string rather than in `extra`, so the
  /// location stays a plain restorable path — `extra` is dropped when the OS
  /// kills and restores the app mid-scan.
  static String captureWith(CaptureSource source) =>
      '$capture?source=${source.name}';

  /// The crop/rotate preview for the acquired image at [imagePath].
  ///
  /// The path rides in the query string for the same reason [captureWith] does
  /// — a plain restorable location rather than a dropped `extra`.
  static String previewWith(String imagePath) =>
      '$preview?path=${Uri.encodeQueryComponent(imagePath)}';
}

/// Builds the app's [GoRouter]: the first-run flow, then a persistent
/// 4-destination bottom-nav shell.
///
/// [onboardingGate] drives the first-run redirect. It is app-scoped, and the
/// router re-evaluates the redirect whenever its state changes — so finishing
/// the privacy step navigates to Home without any explicit `go` call.
GoRouter createAppRouter({required OnboardingCubit onboardingGate}) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: _CubitListenable(onboardingGate.stream),
    redirect: (context, state) =>
        _firstRunRedirect(onboardingGate.state, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (context, state) => const PrivacyScreen(),
      ),
      // Deliberately outside the shell: scanning is a task the user finishes
      // and leaves, not a place to browse, so it takes the whole screen and
      // the bottom bar goes away for its duration.
      GoRoute(
        path: AppRoutes.capture,
        builder: (context, state) => _captureEntry(
          context,
          CaptureSource.parse(state.uri.queryParameters['source']),
        ),
      ),
      // Pushed on top of the capture route: retake pops back to the camera or
      // picker; confirm leaves the flow. Full-screen, outside the shell.
      GoRoute(
        path: AppRoutes.preview,
        builder: (context, state) {
          final path = state.uri.queryParameters['path'] ?? '';
          return BlocProvider<ImagePreviewCubit>(
            create: (_) => getIt<ImagePreviewCubit>(param1: path),
            child: ImagePreviewScreen(
              imagePath: path,
              onSessionCreated: (session) =>
                  context.pushReplacement(AppRoutes.ocr, extra: session),
              // The on-device OCR screen is skipped on this route (F13
              // locked decision #1) — but unlike before F14, the online
              // route still stops at an OCR review before analysis: the
              // review screen reads the corrected photo back out of
              // `ImageAnalysisSessionHolder` and runs Azure OCR itself.
              onOnlineReady: (_) =>
                  context.pushReplacement(AppRoutes.ocrReview),
              onRetake: context.pop,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.ocr,
        builder: (context, state) {
          final session = state.extra as AnalysisSession?;
          if (session == null) return const _BackToHome();
          return BlocProvider<OcrProcessingCubit>(
            create: (_) =>
                getIt<OcrProcessingCubit>(param1: session)..process(),
            // The builder's own `context` sits *above* this provider, so a
            // `read` on it cannot find the cubit. This [Builder] puts the
            // callbacks' context below it — without one, continuing threw
            // `ProviderNotFoundException` and the button did nothing.
            child: Builder(
              builder: (context) => OcrProcessingScreen(
                // Replaces this route: once the text is on its way to be
                // analysed there is no going back to the OCR view of it.
                onContinue: () {
                  context.read<OcrProcessingCubit>().confirm();
                  context.pushReplacement(AppRoutes.result);
                },
                // `go(home)` then `push(capture)` rather than
                // `pushReplacement`: `pushReplacement` only swaps the current
                // top route, leaving the original `/capture` entry `Home`
                // pushed underneath still on the stack. Collapsing to Home
                // first guarantees the stack is always `[Home, capture(new)]`,
                // so Back from the fresh Camera can never resurface a stale,
                // covered capture route.
                onRetake: () {
                  context.go(AppRoutes.home);
                  context.push(AppRoutes.captureWith(CaptureSource.camera));
                },
                onPickAnother: () {
                  context.go(AppRoutes.home);
                  context.push(AppRoutes.captureWith(CaptureSource.gallery));
                },
              ),
            ),
          );
        },
      ),
      // The online route's stop between Azure OCR and Groq analysis (F14).
      // Also outside the shell, like the routes either side of it.
      GoRoute(
        path: AppRoutes.ocrReview,
        builder: (context, state) {
          // Read from the hand-off holder rather than `extra`, same reasoning
          // as the `/result` route below: `extra` is dropped when the OS
          // kills and restores the app mid-scan.
          final onlineHandoff = getIt<ImageAnalysisSessionHolder>();
          final session = onlineHandoff.session;
          final photo = onlineHandoff.photo;
          if (session == null || photo == null) return const _BackToHome();

          return BlocProvider<OcrReviewCubit>(
            create: (_) =>
                getIt<OcrReviewCubit>(param1: session, param2: photo)..runOcr(),
            // Same reasoning as the `/ocr` route's `Builder` above: the
            // callbacks need a `context` below the provider to `read` it.
            child: Builder(
              builder: (context) => OcrReviewScreen(
                // Replaces this route: once the approved text is on its way
                // to Groq there is no going back to the OCR review of it.
                onAnalyze: () {
                  final cubit = context.read<OcrReviewCubit>();
                  final extraction = cubit.buildReviewedResult();
                  // The re-extracted result, not the server's original
                  // candidates — see `buildReviewedResult`'s doc (locked
                  // correction #1).
                  getIt<OcrSessionHolder>().set(session, extraction);
                  cubit.cleanupImage();
                  context.pushReplacement(AppRoutes.result);
                },
                // See the `/ocr` route's `onRetake` above for why this is
                // `go(home)` + `push(capture)` rather than `pushReplacement`.
                onRetake: () {
                  context.read<OcrReviewCubit>().cleanupImage();
                  context.go(AppRoutes.home);
                  context.push(AppRoutes.captureWith(CaptureSource.camera));
                },
                onPickAnother: () {
                  context.read<OcrReviewCubit>().cleanupImage();
                  context.go(AppRoutes.home);
                  context.push(AppRoutes.captureWith(CaptureSource.gallery));
                },
                // The way out of a declined analysis consent (F11-T02) — the
                // same escape hatch `/result` offers on the offline route.
                onOpenSettings: () => context.go(AppRoutes.settings),
              ),
            ),
          );
        },
      ),
      // Also outside the shell: the result belongs to the scan the user just
      // finished, and it is left through its own back control.
      GoRoute(
        path: AppRoutes.result,
        builder: (context, state) {
          // Picked up from a hand-off holder rather than from `extra`, which
          // the OS drops when it kills and restores the app — and redoing
          // either OCR or a full Azure/Google/Groq round trip silently would
          // be expensive. `ImagePreviewCubit.proceed` clears both holders
          // before populating the one for the route it actually took, so at
          // most one of these is ever non-empty; the offline check runs
          // first purely because it has to run first, not to break a tie.
          final ocrHandoff = getIt<OcrSessionHolder>();
          final onlineHandoff = getIt<ImageAnalysisSessionHolder>();

          final AnalysisSession? session;
          final AnalysisSource? source;
          final ocrExtraction = ocrHandoff.result;
          if (ocrHandoff.session != null && ocrExtraction != null) {
            session = ocrHandoff.session;
            source = OcrAnalysisSource(ocrExtraction);
          } else {
            final onlinePhoto = onlineHandoff.photo;
            if (onlineHandoff.session != null && onlinePhoto != null) {
              session = onlineHandoff.session;
              source = ImageAnalysisSource(onlinePhoto);
            } else {
              session = null;
              source = null;
            }
          }
          if (session == null || source == null) {
            return const _BackToHome();
          }
          return MultiBlocProvider(
            providers: [
              BlocProvider<AnalysisResultCubit>(
                create: (_) =>
                    getIt<AnalysisResultCubit>(param1: session, param2: source)
                      ..analyze(),
              ),
              BlocProvider<SaveDocumentCubit>(
                create: (_) => getIt<SaveDocumentCubit>(),
              ),
              BlocProvider<AudioReaderCubit>(
                create: (_) => getIt<AudioReaderCubit>(),
              ),
            ],
            child: SaveDocumentListener(
              // Under both providers: the save reads what the analysis
              // produced, and this is the only place that knows about both.
              child: Builder(
                builder: (context) => AnalysisResultScreen(
                  onClose: () => context.go(AppRoutes.home),
                  // See the `/ocr` route's `onRetake` above for why this is
                  // `go(home)` + `push(capture)` rather than `pushReplacement`.
                  onCaptureAnother: () {
                    context.go(AppRoutes.home);
                    context.push(AppRoutes.captureWith(CaptureSource.camera));
                  },
                  onSave: () => unawaited(_saveResult(context, session!)),
                  onCreateReminder: (date) =>
                      _startReminderFromDate(context, date),
                  // The way out of a declined analysis consent (F11-T02).
                  onOpenSettings: () => context.go(AppRoutes.settings),
                ),
              ),
            ),
          );
        },
      ),
      // Also outside the shell, like the result route it shares a layout
      // with: opened from a row in the list, and left through its own back
      // control rather than the bottom nav.
      GoRoute(
        path: '${AppRoutes.documentDetails}/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null) return const _BackToHome();

          return MultiBlocProvider(
            providers: [
              BlocProvider<DocumentDetailsCubit>(
                create: (_) => getIt<DocumentDetailsCubit>(param1: id)..start(),
              ),
              // Mirrors the `/result` route: the details screen grew its own
              // Listen action and mini-player (F08 follow-up), reusing the
              // same reader.
              BlocProvider<AudioReaderCubit>(
                create: (_) => getIt<AudioReaderCubit>(),
              ),
            ],
            child: DocumentDetailsScreen(
              onClose: context.pop,
              onCreateReminder: (date) =>
                  _startReminderFromDocumentDate(context, date),
            ),
          );
        },
      ),
      // The reminder flows (F09): their own back control, opened from the
      // result/details screens above or, once F09-T11 lands, from the
      // reminders tab.
      GoRoute(
        path: AppRoutes.reminderCreate,
        builder: (context, state) {
          final args = state.extra;
          if (args is! ReminderFromDocumentArgs) return const _BackToHome();

          return BlocProvider<ReminderFormCubit>(
            create: (_) => getIt<ReminderFormCubit>(param1: args),
            child: ReminderFormScreen(
              screenTitle: context.strings.reminderCreateScreenTitle,
              onClose: context.pop,
              onSaved: (reminder) => context.pushReplacement(
                AppRoutes.reminderSuccess,
                extra: reminder,
              ),
            ),
          );
        },
      ),
      // F09-T04. `instanceName` (not `param1`) picks the manual factory —
      // there is nothing to seed it with, unlike `reminderCreate` above.
      GoRoute(
        path: AppRoutes.reminderManual,
        builder: (context, state) {
          return BlocProvider<ReminderFormCubit>(
            create: (_) => getIt<ReminderFormCubit>(
              instanceName: manualReminderFormInstanceName,
            ),
            child: ReminderFormScreen(
              screenTitle: context.strings.reminderAddAction,
              onClose: context.pop,
              onSaved: (reminder) => context.pushReplacement(
                AppRoutes.reminderSuccess,
                extra: reminder,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.reminderSuccess,
        builder: (context, state) {
          final reminder = state.extra;
          if (reminder is! Reminder) return const _BackToHome();

          return ReminderSuccessScreen(
            reminder: reminder,
            // The reminders tab now exists (F09-T11); "close" still just
            // leaves the flow for Home, matching every other save-confirm
            // screen in the app.
            onViewReminder: () => context.go(AppRoutes.reminders),
            onClose: () => context.go(AppRoutes.home),
          );
        },
      ),
      // One reminder's details (F09-T12): opened from a card in the
      // reminders tab, its own back control like `documentDetails` above.
      GoRoute(
        path: '${AppRoutes.reminders}/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null) return const _BackToHome();

          return BlocProvider<ReminderDetailsCubit>(
            create: (_) => getIt<ReminderDetailsCubit>()..start(id),
            child: ReminderDetailsScreen(
              onClose: context.pop,
              onOpenDocument: (documentId) =>
                  context.push(AppRoutes.documentDetailsWith(documentId)),
            ),
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNavBar(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => BlocProvider<HomeCubit>(
                  create: (_) => getIt<HomeCubit>()..start(),
                  // Pushed, not switched to: the user comes back to Home when
                  // the scan is done or cancelled, and Home keeps its scroll
                  // position and its live streams while they are away.
                  child: HomeScreen(
                    onScan: () => context.push(
                      AppRoutes.captureWith(CaptureSource.camera),
                    ),
                    onPickImage: () => context.push(
                      AppRoutes.captureWith(CaptureSource.gallery),
                    ),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.saved,
                builder: (context, state) => BlocProvider<DocumentsListCubit>(
                  create: (_) => getIt<DocumentsListCubit>()..start(),
                  child: DocumentsListScreen(
                    onScan: () => context.push(
                      AppRoutes.captureWith(CaptureSource.camera),
                    ),
                    onOpenDocument: (id) =>
                        context.push(AppRoutes.documentDetailsWith(id)),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reminders,
                builder: (context, state) => BlocProvider<RemindersCubit>(
                  create: (_) => getIt<RemindersCubit>()..start(),
                  child: RemindersListScreen(
                    onAddReminder: () => context.push(AppRoutes.reminderManual),
                    onOpenReminder: (id) =>
                        context.push(AppRoutes.reminderDetailsWith(id)),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => BlocProvider<SettingsCubit>(
                  create: (_) => getIt<SettingsCubit>()..load(),
                  child: const SettingsScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Keeps the first-run flow and the shell mutually exclusive.
///
/// Returning `null` means "stay here". An unresolved gate is treated like a
/// first run: the app only builds the router once the flag is known, so that
/// branch is a safety net rather than a state the user can reach.
String? _firstRunRedirect(OnboardingState gate, String location) {
  final inFirstRun = AppRoutes.firstRun.contains(location);
  return switch (gate) {
    OnboardingUnknown() ||
    OnboardingRequired() => inFirstRun ? null : AppRoutes.onboarding,
    OnboardingCompleted() => inFirstRun ? AppRoutes.home : null,
  };
}

/// The entry point of the capture flow, for the source the user chose.
///
/// The camera goes through the permission gate first; the gallery does not
/// need one — the system photo picker asks for nothing (F03-T03).
Widget _captureEntry(BuildContext context, CaptureSource source) {
  return switch (source) {
    CaptureSource.camera => BlocProvider<CameraPermissionCubit>(
      create: (_) => getIt<CameraPermissionCubit>(),
      child: CameraPermissionGate(
        granted: _cameraViewfinder,
        // Replaces the camera route rather than stacking on it: the user chose
        // the gallery *instead*, so backing out should return to Home, not to
        // the permission sheet they just declined.
        onPickInstead: () => context.pushReplacement(
          AppRoutes.captureWith(CaptureSource.gallery),
        ),
        onDismiss: context.pop,
      ),
    ),
    CaptureSource.gallery => _galleryPicker(context),
  };
}

/// The camera viewfinder, once permission is granted.
///
/// A fresh [CameraCaptureCubit] per entry owns one camera session and releases
/// it when this route is popped. The captured photo hand-off is a placeholder
/// until F03-T06 builds the review screen — for now it returns to Home.
Widget _cameraViewfinder(BuildContext context) {
  return BlocProvider<CameraCaptureCubit>(
    create: (_) => getIt<CameraCaptureCubit>(),
    child: CameraCaptureScreen(
      onCaptured: (photo) => context.push(AppRoutes.previewWith(photo.path)),
      onClose: context.pop,
    ),
  );
}

/// The system photo picker flow.
///
/// The chosen photo hand-off is a placeholder until F03-T06 builds the review
/// screen — for now both a pick and a cancel return to Home.
Widget _galleryPicker(BuildContext context) {
  return BlocProvider<GalleryPickerCubit>(
    create: (_) => getIt<GalleryPickerCubit>(),
    child: GalleryPickerScreen(
      onPicked: (photo) => context.push(AppRoutes.previewWith(photo.path)),
      onCancelled: context.pop,
    ),
  );
}

/// Sends the user back to Home, one frame after this builds.
///
/// The scan routes carry their subject with them — a session, an OCR result —
/// and reaching one without it means the flow was restored or deep-linked into
/// halfway through. There is nothing to show, so the route bounces instead of
/// rendering an empty screen.
class _BackToHome extends StatelessWidget {
  const _BackToHome();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go(AppRoutes.home);
    });
    return const SizedBox.shrink();
  }
}

/// Hands the analysis on screen to the save action.
///
/// The result screen exposes a plain callback, so the two cubits are joined
/// here rather than inside either feature: analysis produces the paper, saved
/// papers keeps it, and neither has to import the other.
///
/// Asks which mode to save in first (F08-T04) — the picture is only ever kept
/// because the sheet's own confirm button was pressed, never as a default.
Future<void> _saveResult(BuildContext context, AnalysisSession session) async {
  final state = context.read<AnalysisResultCubit>().state;
  // The save button only exists on a ready result; this guards the case where
  // the state moved on between the tap and this frame.
  if (state is! AnalysisResultReady) return;

  final mode = await showSaveModeSheet(context);
  if (mode == null || !context.mounted) return;

  await context.read<SaveDocumentCubit>().save(
    analysis: state.result.analysis,
    extractedText: state.result.extractedText,
    imagePath: mode == DocumentStorageMode.withImage ? session.imagePath : null,
  );
}

/// Starts the create-from-document reminder form (F09-T03) for [date], from
/// the fresh result screen.
///
/// Opportunistically links to the document if it has already been saved
/// earlier in this same session ([SaveDocumentCubit.state]) — a reminder
/// does not require the paper to be saved, but if it already was, there is
/// no reason to leave the two unconnected.
void _startReminderFromDate(BuildContext context, AnalysisDate date) {
  final resultState = context.read<AnalysisResultCubit>().state;
  if (resultState is! AnalysisResultReady) return;

  final saveState = context.read<SaveDocumentCubit>().state;
  final documentId = saveState is SaveDocumentSaved
      ? saveState.documentId
      : null;
  final title = resultState.result.analysis.title;

  context.push(
    AppRoutes.reminderCreate,
    extra: ReminderFromDocumentArgs(
      documentId: documentId,
      documentTitle: documentId == null ? null : title,
      title: title,
      eventDate: date.date,
      eventMinuteOfDay: _minuteOfDayOf(date.time),
    ),
  );
}

/// Starts the create-from-document reminder form (F09-T03) for [date], from
/// an already-saved document's details screen — always linked, since the
/// document this reads from is right there.
void _startReminderFromDocumentDate(BuildContext context, AnalysisDate date) {
  final state = context.read<DocumentDetailsCubit>().state;
  if (state is! DocumentDetailsAvailable) return;

  final document = state.document;
  context.push(
    AppRoutes.reminderCreate,
    extra: ReminderFromDocumentArgs(
      documentId: document.id,
      documentTitle: document.analysis.title,
      title: document.analysis.title,
      eventDate: date.date,
      eventMinuteOfDay: _minuteOfDayOf(date.time),
    ),
  );
}

/// [AnalysisTime] as minutes since midnight, the shape a reminder's event
/// time is stored in — the reverse of `document_write_mapper.dart`'s own
/// copy of the same conversion, kept private here since routing is the only
/// place a date crosses from one shape to the other.
int? _minuteOfDayOf(AnalysisTime? time) =>
    time == null ? null : time.hour * 60 + time.minute;

/// Adapts a Cubit's [Stream] to the [Listenable] `GoRouter` expects, so gate
/// changes re-run the redirect.
final class _CubitListenable extends ChangeNotifier {
  _CubitListenable(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
