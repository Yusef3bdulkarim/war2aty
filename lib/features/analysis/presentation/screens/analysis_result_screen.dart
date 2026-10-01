import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/audio/audio_reader_cubit.dart';
import '../../../../core/audio/audio_reader_state.dart';
import '../../../../core/documents/analysis_date.dart';
import '../../../../core/documents/analysis_result.dart';
import '../../../../core/documents/analysis_section.dart';
import '../../../../core/documents/reading_mode.dart';
import '../../../../core/documents/reading_mode_label.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/audio_mini_player_bar.dart';
import '../../../../core/widgets/audio_options_sheet.dart';
import '../../../../core/widgets/expandable_panel.dart';
import '../../../../core/widgets/partial_result_banner.dart';
import '../../../../core/widgets/result_action_bar.dart';
import '../../../../core/widgets/result_actions_card.dart';
import '../../../../core/widgets/result_details_card.dart';
import '../../../../core/widgets/result_extracted_text_panel.dart';
import '../../../../core/widgets/result_hero_scroll_view.dart';
import '../../../../core/widgets/result_list_card.dart';
import '../../../../core/widgets/result_warnings_card.dart';
import '../../../../core/widgets/service_state_view.dart';
import '../cubit/analysis_result_cubit.dart';
import '../cubit/analysis_result_state.dart';
import '../widgets/analysis_progress_view.dart';
import '../widgets/extracted_text_only_view.dart';
import '../widgets/failure/analysis_steps_card.dart';
import '../widgets/failure/extracted_text_entry_card.dart';
import '../widgets/failure/failure_note_chip.dart';
import '../widgets/failure/failure_tips_card.dart';
import '../widgets/failure/supported_documents_section.dart';

// From `Waraqti.dc.html` → the result page. The top of the page is F21's
// hero (`ResultHeroScrollView`).
const double _explanationFontSize = 14.5;
const double _explanationHeight = 1.9;

/// The result page: what the paper is, what it says, and what to do about it.
///
/// The body is a plain list of the sections `BuildAnalysisResult` handed over —
/// this screen neither picks the order (§4 fixes it, in the domain) nor decides
/// what to hide, so a section can be filled in without touching this file.
class AnalysisResultScreen extends StatelessWidget {
  const AnalysisResultScreen({
    this.onClose,
    this.onCreateReminder,
    this.onSave,
    this.onCaptureAnother,
    this.onPickFromGallery,
    this.onOpenSettings,
    super.key,
  });

  /// Leaves the result. The router supplies it; optional so the screen can be
  /// pumped on its own in a widget test.
  final VoidCallback? onClose;

  /// Starts a reminder for the date the user chose. Absent until the reminder
  /// flow exists (F09).
  final ValueChanged<AnalysisDate>? onCreateReminder;

  /// Keeps this paper. Absent until saved documents exist (F08). The result is
  /// never stored without the user asking (UX rules §5.3 and §5.4).
  final VoidCallback? onSave;

  /// Opens the camera for a fresh capture: one of an unsupported paper's two
  /// ways out.
  final VoidCallback? onCaptureAnother;

  /// Opens the gallery instead: the other way out of an unsupported paper
  /// (F23 #5).
  final VoidCallback? onPickFromGallery;

  /// Opens the settings screen. The way out of a declined analysis consent
  /// (F11-T02) — absent until the settings screen exists to open (F11-T01).
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.surface,
      body: BlocBuilder<AnalysisResultCubit, AnalysisResultState>(
        builder: (context, state) => _FinishProgressFirst(
          state: state,
          child: switch (state) {
            // Full-bleed and without the top bar: there is nothing to go back
            // to mid-analysis, and the design gives the wait the whole page.
            AnalysisResultAnalyzing() => const AnalysisProgressView(),
            AnalysisResultReady(:final result) => _ResultBody(
              result: result,
              onClose: onClose,
              onCreateReminder: onCreateReminder,
              onSave: onSave,
            ),
            AnalysisResultFailed() => _FailureBody(
              state: state,
              onClose: onClose,
              onCaptureAnother: onCaptureAnother,
              onPickFromGallery: onPickFromGallery,
              onOpenSettings: onOpenSettings,
            ),
          },
        ),
      ),
    );
  }
}

/// Holds the progress page up for its finish — the check and its haptic —
/// when a running analysis answers, then shows [child] (F22 #10).
///
/// Only on analyzing → ready: a failure replaces the page at once (which
/// disposes the magnifier and halts it), and a screen that opens on a ready
/// result has no wait to finish.
class _FinishProgressFirst extends StatefulWidget {
  const _FinishProgressFirst({required this.state, required this.child});

  final AnalysisResultState state;
  final Widget child;

  @override
  State<_FinishProgressFirst> createState() => _FinishProgressFirstState();
}

class _FinishProgressFirstState extends State<_FinishProgressFirst> {
  bool _finishing = false;

  @override
  void didUpdateWidget(_FinishProgressFirst oldWidget) {
    super.didUpdateWidget(oldWidget);
    final state = widget.state;
    if (oldWidget.state is AnalysisResultAnalyzing &&
        state is AnalysisResultReady) {
      _finishing = true;
    } else if (state is! AnalysisResultReady) {
      _finishing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_finishing) return widget.child;
    // Same type in the same place as the analyzing page, so the magnifier
    // keeps its state and finishes from wherever the wait had reached.
    return AnalysisProgressView(
      finishing: true,
      onFinished: () => setState(() => _finishing = false),
    );
  }
}

/// The top bar and the ordered sections.
class _ResultBody extends StatefulWidget {
  const _ResultBody({
    required this.result,
    this.onClose,
    this.onCreateReminder,
    this.onSave,
  });

  final AnalysisResult result;
  final VoidCallback? onClose;
  final ValueChanged<AnalysisDate>? onCreateReminder;
  final VoidCallback? onSave;

  @override
  State<_ResultBody> createState() => _ResultBodyState();
}

class _ResultBodyState extends State<_ResultBody> {
  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final detailsAt = resultDetailsIndex(widget.result.sections);

    // A `BlocListener` rather than a `BlocConsumer` around the whole page: a
    // reading in progress emits a fresh state on every `TtsProgressed` tick
    // (F10-T08), and a `builder` up here would rebuild the top bar, every
    // result card and the action bar on each one. Only `_MiniPlayerSlot`
    // below needs to watch the state at all (CLAUDE.md §B8: `BlocBuilder` on
    // the smallest Widget that needs it).
    return BlocListener<AudioReaderCubit, AudioReaderState>(
      listenWhen: (previous, current) => current is AudioReaderFailed,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(strings.audioReaderFailedFeedback)),
          );
      },
      // The system back gesture leaves the way the arrow does, through
      // `onClose` — otherwise it would pop to whatever the capture flow left
      // underneath and skip what `onClose` does on the way out.
      child: PopScope(
        canPop: widget.onClose == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) widget.onClose?.call();
        },
        child: Column(
          children: [
            Expanded(
              child: ResultHeroScrollView(
                heading: strings.analysisResultTitle,
                backTooltip: strings.analysisResultBackLabel,
                onBack: widget.onClose,
                summary:
                    widget.result.sections.contains(AnalysisSection.summary)
                    ? widget.result.analysis.summary.short
                    : null,
                children: [
                  for (final (index, section)
                      in widget.result.sections.indexed) ...[
                    if (index == detailsAt) ..._dataBlock(),
                    _section(context, section, strings),
                  ],
                  if (detailsAt == widget.result.sections.length)
                    ..._dataBlock(),
                ],
              ),
            ),
            _MiniPlayerSlot(onOpenAudioSheet: _openAudioSheet),
            // Pinned below the scroll: these three are what the page is *for*,
            // and the design keeps them in reach without scrolling to the end.
            ResultActionBar(
              dates: widget.result.analysis.dates,
              onListen: _openAudioSheet,
              onCreateReminder: widget.onCreateReminder,
              onSave: widget.onSave,
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the mode-and-speed-picker sheet and starts the mini-player reading
  /// whatever the user confirms there. Reopening it (from the bar's
  /// «خيارات») highlights the mode and speed already reading rather than
  /// resetting either to the first/default — a fresh open instead highlights
  /// the user's persisted «سرعة القراءة الافتراضية» (F11-T07) rather than
  /// always the same fixed default.
  Future<void> _openAudioSheet() async {
    final cubit = context.read<AudioReaderCubit>();
    final currentlyReading = cubit.state;
    final defaultSpeed = currentlyReading is AudioReaderReading
        ? currentlyReading.speed
        : await cubit.loadDefaultSpeed();
    if (!mounted) return;
    final choice = await showAudioOptionsSheet(
      context,
      initialMode: currentlyReading is AudioReaderReading
          ? currentlyReading.mode
          : ReadingMode.summaryOnly,
      initialSpeed: defaultSpeed,
    );
    if (choice == null || !mounted) return;
    await cubit.start(
      result: widget.result,
      mode: choice.mode,
      speed: choice.speed,
      strings: context.strings,
    );
  }

  /// The partial-result banner when the paper was only half read, then
  /// everything read off the paper in one card (F21 #9, #15, #17).
  ///
  /// The banner sits right before the data rather than at the top of the
  /// page: it qualifies the figures below it, and the top stays the summary's.
  List<Widget> _dataBlock() {
    final analysis = widget.result.analysis;
    return [
      if (analysis.isPartial) const PartialResultBanner(),
      ResultDetailsCard(
        kind: analysis.kind,
        kindConfidence: analysis.kindConfidence,
        keyInformation: analysis.keyInformation,
        amounts: analysis.amounts,
        dates: analysis.dates,
        onCreateReminder: widget.onCreateReminder,
      ),
    ];
  }

  /// The widget for one section. Each owns its own spacing and internal
  /// states, the way Home's sections do — and each is filled in by the task
  /// named beside it.
  Widget _section(
    BuildContext context,
    AnalysisSection section,
    AppStrings strings,
  ) {
    final colors = AppColors.of(context);
    final analysis = widget.result.analysis;

    return switch (section) {
      AnalysisSection.actionRequired => ResultActionsCard(
        actions: analysis.actions,
      ),
      AnalysisSection.warnings => ResultWarningsCard(
        warnings: analysis.warnings,
      ),
      // The summary is the hero (F21 #14), the type a row of the details card
      // (F21 #15), and the three data sections are drawn together by that
      // card — see `_dataBlock`.
      AnalysisSection.header ||
      AnalysisSection.summary ||
      AnalysisSection.keyInformation ||
      AnalysisSection.amounts ||
      AnalysisSection.dates => const SizedBox.shrink(),
      AnalysisSection.requiredDocuments => ResultListCard(
        glyph: StrokeGlyph.documentCheck,
        title: strings.resultRequiredDocumentsTitle,
        items: analysis.requiredDocuments,
      ),
      AnalysisSection.instructions => ResultListCard(
        glyph: StrokeGlyph.documentSteps,
        title: strings.resultInstructionsTitle,
        items: analysis.instructions,
        numbered: true,
      ),
      AnalysisSection.detailedExplanation => ExpandablePanel(
        label: strings.resultShowExplanation,
        gapBelow: AppSpacing.resultCardGap,
        child: Text(
          analysis.summary.detailed,
          style: AppTypography.bodySmall.copyWith(
            fontSize: _explanationFontSize,
            height: _explanationHeight,
            color: colors.textBody,
          ),
        ),
      ),
      AnalysisSection.extractedText => ResultExtractedTextPanel(
        text: widget.result.extractedText,
        onListen: _openAudioSheet,
      ),
    };
  }
}

/// Watches [AudioReaderCubit] on its own, scoped to just the mini-player —
/// see the comment on `_ResultBodyState.build` for why this is split out
/// rather than folded into the page's own `builder` (F10-T08).
class _MiniPlayerSlot extends StatelessWidget {
  const _MiniPlayerSlot({required this.onOpenAudioSheet});

  final VoidCallback onOpenAudioSheet;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return BlocBuilder<AudioReaderCubit, AudioReaderState>(
      builder: (context, audioState) => switch (audioState) {
        AudioReaderReading(:final mode, :final isPaused, :final progress) =>
          AudioMiniPlayerBar(
            modeLabel: readingModeLabel(strings, mode),
            isPlaying: !isPaused,
            progress: progress,
            onTogglePlayPause: () {
              final cubit = context.read<AudioReaderCubit>();
              if (isPaused) {
                cubit.resume();
              } else {
                cubit.pause();
              }
            },
            onOptions: onOpenAudioSheet,
            onStop: () => context.read<AudioReaderCubit>().stop(),
          ),
        AudioReaderIdle() || AudioReaderFailed() => const SizedBox.shrink(),
      },
    );
  }
}

/// The analysis did not come back.
///
/// Each failure gets its own words and its own way forward. Every one of them
/// can also fall through to the text already read off the paper — which is
/// why this is stateful: showing that text is a branch of this page rather
/// than a place the user navigates away to and has to find their way back
/// from. Listening is not offered here (F23 #12).
class _FailureBody extends StatefulWidget {
  const _FailureBody({
    required this.state,
    this.onClose,
    this.onCaptureAnother,
    this.onPickFromGallery,
    this.onOpenSettings,
  });

  final AnalysisResultFailed state;
  final VoidCallback? onClose;
  final VoidCallback? onCaptureAnother;
  final VoidCallback? onPickFromGallery;
  final VoidCallback? onOpenSettings;

  @override
  State<_FailureBody> createState() => _FailureBodyState();
}

/// Which page a failure gets.
///
/// Three states the user can do something specific about, and one page for
/// everything else — a timeout, a bad response, an outage all mean the same
/// thing to someone holding a piece of paper.
enum _FailureKind {
  /// The phone is offline. Retrying is worth offering: connections come back.
  offline,

  /// The three daily analyses are spent. No retry — it would fail the same way
  /// and the user would be told to wait a second time.
  limitReached,

  /// This kind of paper cannot be explained responsibly. No retry either: the
  /// same text would come back unsupported, at the cost of one analysis.
  unsupported,

  /// The user turned off «السماح بإرسال النص للتحليل» (F11-T02). Not an
  /// error — retrying would fail the exact same way until the setting
  /// changes, so the way forward is Settings, not another attempt.
  consentDeclined,

  /// The service could not answer. Worth another try in a moment.
  serviceProblem,
}

class _FailureBodyState extends State<_FailureBody> {
  // Local UI state: which of this page's two faces is showing.
  bool _showText = false;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    if (_showText) {
      return ExtractedTextOnlyView(
        text: widget.state.extractedText,
        onBack: () => setState(() => _showText = false),
      );
    }

    final kind = _kind;
    return ServiceStateView(
      onBack: widget.onClose,
      title: switch (kind) {
        _FailureKind.offline => strings.analysisNoInternetTitle,
        _FailureKind.limitReached => strings.analysisLimitReachedTitle,
        _FailureKind.unsupported => strings.analysisUnsupportedTitle,
        _FailureKind.consentDeclined => strings.analysisConsentDeclinedTitle,
        _FailureKind.serviceProblem => strings.analysisFailedTitle,
      },
      message: switch (kind) {
        _FailureKind.offline => strings.analysisNoInternetMessage,
        _FailureKind.limitReached => strings.analysisLimitReachedMessage,
        _FailureKind.unsupported => strings.analysisUnsupportedMessage,
        _FailureKind.consentDeclined => strings.analysisConsentDeclinedMessage,
        _FailureKind.serviceProblem => strings.analysisFailedMessage,
      },
      note: kind == _FailureKind.unsupported
          ? FailureNoteChip(text: strings.analysisAttemptNotCounted)
          : null,
      content: _content(kind, strings),
      // Camera and gallery: two equal ways to a paper the app can explain.
      pairPrimaryActions: kind == _FailureKind.unsupported,
      primary: _primary(strings),
      secondary: _secondary(strings),
      tertiary: _tertiary(strings),
    );
  }

  /// The page's own blocks under its words.
  List<Widget> _content(_FailureKind kind, AppStrings strings) =>
      switch (kind) {
        // Option B (F23 #5): the text one tap away, then what does work.
        _FailureKind.unsupported => [
          if (_hasText) ExtractedTextEntryCard(onTap: _openText),
          const SupportedDocumentsSection(),
        ],
        // What is already done, then what to check (F23 #6).
        _FailureKind.offline => [
          const AnalysisStepsCard(explanation: ExplanationStep.waiting),
          FailureTipsCard(
            title: strings.analysisNoInternetTipsTitle,
            tips: [
              FailureTip(
                glyph: StrokeGlyph.wifi,
                text: strings.analysisNoInternetTipWifi,
              ),
              FailureTip(
                glyph: StrokeGlyph.airplane,
                text: strings.analysisNoInternetTipAirplane,
              ),
              FailureTip(
                glyph: StrokeGlyph.signal,
                text: strings.analysisNoInternetTipSignal,
              ),
            ],
          ),
        ],
        _ => const [],
      };

  void _openText() => setState(() => _showText = true);

  _FailureKind get _kind => switch (widget.state.failure) {
    NoInternetFailure() => _FailureKind.offline,
    DailyLimitReachedFailure() => _FailureKind.limitReached,
    UnsupportedDocumentFailure() => _FailureKind.unsupported,
    AnalysisConsentDeclinedFailure() => _FailureKind.consentDeclined,
    _ => _FailureKind.serviceProblem,
  };

  /// Whether there is any text to fall back to.
  ///
  /// Both routes reach the analysis through the OCR review, so it is normally
  /// there (F23 #11); showing it costs nothing and uses none of the daily
  /// allowance. When it is empty, the actions that would show it drop
  /// themselves.
  bool get _hasText => widget.state.extractedText.trim().isNotEmpty;

  bool get _canRetry =>
      _kind == _FailureKind.offline || _kind == _FailureKind.serviceProblem;

  ServiceStateAction _showTextAction(AppStrings strings) => ServiceStateAction(
    label: strings.resultShowExtractedText,
    onPressed: _openText,
  );

  ServiceStateAction _homeAction(AppStrings strings) => ServiceStateAction(
    label: strings.analysisBackToHome,
    onPressed: widget.onClose ?? () {},
  );

  /// The camera, when the router supplied the way there.
  ServiceStateAction? _cameraAction(AppStrings strings) =>
      switch (widget.onCaptureAnother) {
        final onCaptureAnother? => ServiceStateAction(
          label: strings.analysisCaptureAnother,
          glyph: StrokeGlyph.camera,
          onPressed: onCaptureAnother,
        ),
        null => null,
      };

  /// The gallery, when the router supplied the way there.
  ServiceStateAction? _galleryAction(AppStrings strings) =>
      switch (widget.onPickFromGallery) {
        final onPickFromGallery? => ServiceStateAction(
          label: strings.analysisPickFromGallery,
          glyph: StrokeGlyph.gallery,
          onPressed: onPickFromGallery,
        ),
        null => null,
      };

  /// Retrying leads the way where it can work; a declined consent leads to
  /// Settings instead, since retrying would only fail the same way again;
  /// otherwise the text does.
  ServiceStateAction _primary(AppStrings strings) {
    // An unsupported paper leads with a new one: the camera, else the
    // gallery; its text is a card in the page instead (F23 #5).
    if (_kind == _FailureKind.unsupported) {
      return _cameraAction(strings) ??
          _galleryAction(strings) ??
          _homeAction(strings);
    }
    if (_kind == _FailureKind.consentDeclined) {
      if (widget.onOpenSettings case final onOpenSettings?) {
        return ServiceStateAction(
          label: strings.analysisConsentDeclinedOpenSettings,
          onPressed: onOpenSettings,
        );
      }
    }
    if (_canRetry) {
      return ServiceStateAction(
        label: strings.actionRetry,
        onPressed: () => context.read<AnalysisResultCubit>().analyze(),
      );
    }
    if (_hasText) return _showTextAction(strings);
    return _homeAction(strings);
  }

  ServiceStateAction? _secondary(AppStrings strings) {
    // An unsupported paper: the gallery, beside the camera.
    if (_kind == _FailureKind.unsupported) {
      return _cameraAction(strings) == null ? null : _galleryAction(strings);
    }
    if (!_hasText) return null;
    // A declined consent's primary slot went to Settings above, so the text
    // — never spent, since the request never went out — takes this one.
    if (_kind == _FailureKind.consentDeclined &&
        widget.onOpenSettings != null) {
      return _showTextAction(strings);
    }
    // Whichever of the two the primary did not take.
    if (_canRetry) return _showTextAction(strings);
    return null;
  }

  /// The quiet way home — unless the primary already is it (an unsupported
  /// page with neither the camera nor the gallery to offer).
  ServiceStateAction? _tertiary(AppStrings strings) {
    if (_kind == _FailureKind.unsupported &&
        _cameraAction(strings) == null &&
        _galleryAction(strings) == null) {
      return null;
    }
    return _homeAction(strings);
  }
}
