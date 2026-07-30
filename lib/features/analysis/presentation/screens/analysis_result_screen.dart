import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/documents/analysis_date.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/analysis_result.dart';
import '../../domain/entities/analysis_section.dart';
import '../cubit/analysis_result_cubit.dart';
import '../cubit/analysis_result_state.dart';
import '../widgets/analysis_progress_view.dart';
import '../widgets/expandable_panel.dart';
import '../widgets/extracted_text_only_view.dart';
import '../widgets/partial_result_banner.dart';
import '../widgets/result_action_bar.dart';
import '../widgets/result_actions_card.dart';
import '../widgets/result_amounts_card.dart';
import '../widgets/result_dates_card.dart';
import '../widgets/result_extracted_text_panel.dart';
import '../widgets/result_header_card.dart';
import '../widgets/result_key_information_card.dart';
import '../widgets/result_list_card.dart';
import '../widgets/result_summary_card.dart';
import '../widgets/result_warnings_card.dart';
import '../widgets/service_state_view.dart';

// From `Waraqti.dc.html` → the result page. The top bar's 56px is measured
// from the physical screen top and already contains the 52px status bar, which
// [SafeArea] applies for us.
const double _topBarTop = 56 - 52;
const double _topBarBottom = 12;
const double _topBarSide = AppSpacing.screenHorizontal;
const double _topBarGap = 8;
const double _topBarButton = 40;
const double _pageSide = 18;
const double _pageTop = 18;
const double _pageBottom = 24;
const double _explanationGapAbove = 14;
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
    this.onListen,
    this.onCreateReminder,
    this.onSave,
    this.onCaptureAnother,
    super.key,
  });

  /// Leaves the result. The router supplies it; optional so the screen can be
  /// pumped on its own in a widget test.
  final VoidCallback? onClose;

  /// Reads the paper aloud. Absent until there is a reader (F10) — every
  /// control that would use it is left out rather than shown doing nothing.
  final VoidCallback? onListen;

  /// Starts a reminder for the date the user chose. Absent until the reminder
  /// flow exists (F09).
  final ValueChanged<AnalysisDate>? onCreateReminder;

  /// Keeps this paper. Absent until saved documents exist (F08). The result is
  /// never stored without the user asking (UX rules §5.3 and §5.4).
  final VoidCallback? onSave;

  /// Starts a fresh capture. The way out of an unsupported paper.
  final VoidCallback? onCaptureAnother;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Scaffold(
      backgroundColor: colors.surface,
      body: BlocBuilder<AnalysisResultCubit, AnalysisResultState>(
        builder: (context, state) => switch (state) {
          // Full-bleed and without the top bar: there is nothing to go back to
          // mid-analysis, and the design gives the wait the whole page.
          AnalysisResultAnalyzing() => const AnalysisProgressView(),
          AnalysisResultReady(:final result) => _ResultBody(
            result: result,
            onClose: onClose,
            onListen: onListen,
            onCreateReminder: onCreateReminder,
            onSave: onSave,
          ),
          AnalysisResultFailed() => _FailureBody(
            state: state,
            onClose: onClose,
            onListen: onListen,
            onCaptureAnother: onCaptureAnother,
          ),
        },
      ),
    );
  }
}

/// The top bar and the ordered sections.
class _ResultBody extends StatelessWidget {
  const _ResultBody({
    required this.result,
    this.onClose,
    this.onListen,
    this.onCreateReminder,
    this.onSave,
  });

  final AnalysisResult result;
  final VoidCallback? onClose;
  final VoidCallback? onListen;
  final ValueChanged<AnalysisDate>? onCreateReminder;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopBar(onClose: onClose),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              _pageSide,
              _pageTop,
              _pageSide,
              _pageBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Above everything: a half-read paper must not look like a
                // fully understood one, whatever it managed to fill in.
                if (result.analysis.isPartial) const PartialResultBanner(),
                for (final section in result.sections)
                  _section(section, context.strings),
              ],
            ),
          ),
        ),
        // Pinned below the scroll: these three are what the page is *for*, and
        // the design keeps them in reach without scrolling to the end.
        ResultActionBar(
          dates: result.analysis.dates,
          onListen: onListen,
          onCreateReminder: onCreateReminder,
          onSave: onSave,
        ),
      ],
    );
  }

  /// The widget for one section. Each owns its own spacing and internal
  /// states, the way Home's sections do — and each is filled in by the task
  /// named beside it.
  Widget _section(AnalysisSection section, AppStrings strings) {
    const colors = AppColors.light;

    return switch (section) {
      AnalysisSection.header => ResultHeaderCard(analysis: result.analysis),
      AnalysisSection.summary => ResultSummaryCard(
        summary: result.analysis.summary.short,
      ),
      AnalysisSection.actionRequired => ResultActionsCard(
        actions: result.analysis.actions,
      ),
      AnalysisSection.warnings => ResultWarningsCard(
        warnings: result.analysis.warnings,
      ),
      AnalysisSection.keyInformation => ResultKeyInformationCard(
        items: result.analysis.keyInformation,
      ),
      AnalysisSection.amounts => ResultAmountsCard(
        amounts: result.analysis.amounts,
      ),
      AnalysisSection.dates => ResultDatesCard(
        dates: result.analysis.dates,
        onCreateReminder: onCreateReminder,
      ),
      AnalysisSection.requiredDocuments => ResultListCard(
        glyph: StrokeGlyph.documentCheck,
        title: strings.resultRequiredDocumentsTitle,
        items: result.analysis.requiredDocuments,
      ),
      AnalysisSection.instructions => ResultListCard(
        glyph: StrokeGlyph.documentSteps,
        title: strings.resultInstructionsTitle,
        items: result.analysis.instructions,
        numbered: true,
      ),
      AnalysisSection.detailedExplanation => ExpandablePanel(
        label: strings.resultShowExplanation,
        gapAbove: _explanationGapAbove,
        child: Text(
          result.analysis.summary.detailed,
          style: AppTypography.bodySmall.copyWith(
            fontSize: _explanationFontSize,
            height: _explanationHeight,
            color: colors.textBody,
          ),
        ),
      ),
      AnalysisSection.extractedText => ResultExtractedTextPanel(
        text: result.extractedText,
        onListen: onListen,
      ),
    };
  }
}

/// The page's own bar: a way back, and the page's name.
///
/// The design also draws an overflow button on the trailing side. The three
/// standing actions live in the bar at the foot of the page, so there is
/// nothing to put behind it until saved documents arrive (F08) — the space is
/// held open rather than filled with a menu that does nothing.
class _TopBar extends StatelessWidget {
  const _TopBar({this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;
    // The design's arrow points towards the start of an Arabic line; in an
    // English layout that is the other way round.
    final mirror = Directionality.of(context) == TextDirection.ltr;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(bottom: BorderSide(color: colors.borderSoft)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            _topBarSide,
            _topBarTop,
            _topBarSide,
            _topBarBottom,
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: _topBarButton,
                child: IconButton(
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  tooltip: strings.analysisResultBackLabel,
                  icon: Transform.flip(
                    flipX: mirror,
                    child: StrokeIcon(
                      StrokeGlyph.arrowBack,
                      color: colors.ink,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: _topBarGap),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    strings.analysisResultTitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelCard.copyWith(
                      fontWeight: AppTypography.extraBold,
                      color: colors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: _topBarGap),
              // Balances the back button so the title stays centred.
              const SizedBox.square(dimension: _topBarButton),
            ],
          ),
        ),
      ),
    );
  }
}

/// The analysis did not come back.
///
/// Each failure gets its own words and its own way forward, and every one of
/// them can fall through to the text the phone already read — which is why
/// this is stateful: showing that text is a branch of this page rather than a
/// place the user navigates away to and has to find their way back from.
class _FailureBody extends StatefulWidget {
  const _FailureBody({
    required this.state,
    this.onClose,
    this.onListen,
    this.onCaptureAnother,
  });

  final AnalysisResultFailed state;
  final VoidCallback? onClose;
  final VoidCallback? onListen;
  final VoidCallback? onCaptureAnother;

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

  /// The service could not answer. Worth another try in a moment.
  serviceProblem,
}

class _FailureBodyState extends State<_FailureBody> {
  // Local UI state: which of this page's two faces is showing.
  bool _showText = false;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    if (_showText) {
      return ExtractedTextOnlyView(
        text: widget.state.extractedText,
        onBack: () => setState(() => _showText = false),
        onListen: widget.onListen,
      );
    }

    final kind = _kind;
    return ServiceStateView(
      onBack: widget.onClose,
      glyph: switch (kind) {
        _FailureKind.offline => StrokeGlyph.wifiOff,
        _FailureKind.limitReached => StrokeGlyph.clock,
        _FailureKind.unsupported => StrokeGlyph.documentSteps,
        _FailureKind.serviceProblem => StrokeGlyph.warningTriangle,
      },
      tint: switch (kind) {
        _FailureKind.offline ||
        _FailureKind.limitReached => colors.surfaceTealAlt,
        _FailureKind.unsupported => colors.surfaceAlt,
        _FailureKind.serviceProblem => colors.warningTint,
      },
      iconColor: switch (kind) {
        _FailureKind.offline ||
        _FailureKind.limitReached => colors.brandPrimary,
        _FailureKind.unsupported => colors.textMuted,
        _FailureKind.serviceProblem => colors.warning,
      },
      title: switch (kind) {
        _FailureKind.offline => strings.analysisNoInternetTitle,
        _FailureKind.limitReached => strings.analysisLimitReachedTitle,
        _FailureKind.unsupported => strings.analysisUnsupportedTitle,
        _FailureKind.serviceProblem => strings.analysisFailedTitle,
      },
      message: switch (kind) {
        _FailureKind.offline => strings.analysisNoInternetMessage,
        _FailureKind.limitReached => strings.analysisLimitReachedMessage,
        _FailureKind.unsupported => strings.analysisUnsupportedMessage,
        _FailureKind.serviceProblem => strings.analysisFailedMessage,
      },
      primary: _primary(strings),
      secondary: _secondary(strings),
      tertiary: _tertiary(strings, kind),
    );
  }

  _FailureKind get _kind => switch (widget.state.failure) {
    NoInternetFailure() => _FailureKind.offline,
    DailyLimitReachedFailure() => _FailureKind.limitReached,
    UnsupportedDocumentFailure() => _FailureKind.unsupported,
    _ => _FailureKind.serviceProblem,
  };

  /// Whether there is any text to fall back to.
  ///
  /// There nearly always is — the OCR ran on the phone before any of this, so
  /// the fallback costs nothing and uses none of the daily allowance.
  bool get _hasText => widget.state.extractedText.trim().isNotEmpty;

  bool get _canRetry =>
      _kind == _FailureKind.offline || _kind == _FailureKind.serviceProblem;

  ServiceStateAction _showTextAction(AppStrings strings) => ServiceStateAction(
    label: strings.resultShowExtractedText,
    onPressed: () => setState(() => _showText = true),
  );

  /// Retrying leads the way where it can work; otherwise the text does.
  ServiceStateAction _primary(AppStrings strings) {
    if (_canRetry) {
      return ServiceStateAction(
        label: strings.actionRetry,
        onPressed: () => context.read<AnalysisResultCubit>().analyze(),
      );
    }
    if (_hasText) return _showTextAction(strings);
    return ServiceStateAction(
      label: strings.analysisBackToHome,
      onPressed: widget.onClose ?? () {},
    );
  }

  ServiceStateAction? _secondary(AppStrings strings) {
    if (!_hasText) return null;
    // Whichever of the two the primary did not take.
    if (_canRetry) return _showTextAction(strings);
    if (widget.onListen case final onListen?) {
      return ServiceStateAction(
        label: strings.resultListenToExtractedText,
        onPressed: onListen,
      );
    }
    return null;
  }

  /// An unsupported paper is the one dead end the user can only leave by
  /// photographing something else; the rest are worth coming back to.
  ServiceStateAction _tertiary(AppStrings strings, _FailureKind kind) {
    if (kind == _FailureKind.unsupported) {
      if (widget.onCaptureAnother case final onCaptureAnother?) {
        return ServiceStateAction(
          label: strings.analysisCaptureAnother,
          onPressed: onCaptureAnother,
        );
      }
    }
    return ServiceStateAction(
      label: strings.analysisBackToHome,
      onPressed: widget.onClose ?? () {},
    );
  }
}
