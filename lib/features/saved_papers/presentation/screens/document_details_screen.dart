import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/documents/analysis_section.dart';
import '../../../../core/documents/saved_document.dart';
import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/expandable_panel.dart';
import '../../../../core/widgets/partial_result_banner.dart';
import '../../../../core/widgets/result_actions_card.dart';
import '../../../../core/widgets/result_amounts_card.dart';
import '../../../../core/widgets/result_dates_card.dart';
import '../../../../core/widgets/result_extracted_text_panel.dart';
import '../../../../core/widgets/result_header_card.dart';
import '../../../../core/widgets/result_key_information_card.dart';
import '../../../../core/widgets/result_list_card.dart';
import '../../../../core/widgets/result_summary_card.dart';
import '../../../../core/widgets/result_warnings_card.dart';
import '../../../../core/widgets/service_state_view.dart';
import '../cubit/document_details_cubit.dart';
import '../cubit/document_details_state.dart';
import '../widgets/document_note_card.dart';
import '../widgets/note_editor_sheet.dart';

// From `Waraqti.dc.html` → `docDetails`, which shares the result page's own
// layout constants (`resultScreenLabel`) — see `analysis_result_screen.dart`.
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

/// A saved paper's full record (F08-T08): what the analysis understood about
/// it, read back exactly as it was written down.
///
/// The design draws this as the result page itself, with a different heading
/// and no save button — a saved document has nothing left to save. The body
/// below the heading is the same ordered, filtered list of sections the
/// result screen draws (`AnalysisSection`), fed from what was stored instead
/// of what a fresh analysis just returned.
class DocumentDetailsScreen extends StatelessWidget {
  const DocumentDetailsScreen({this.onClose, super.key});

  /// Leaves the details screen. The router supplies it; optional so the
  /// screen can be pumped on its own in a widget test.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Scaffold(
      backgroundColor: colors.surface,
      body: BlocBuilder<DocumentDetailsCubit, DocumentDetailsState>(
        builder: (context, state) => switch (state) {
          DocumentDetailsLoading() => const _Loading(),
          DocumentDetailsAvailable(:final document, :final sections) =>
            _DetailsBody(
              document: document,
              sections: sections,
              onClose: onClose,
            ),
          DocumentDetailsNotFound() => _StateBody(
            glyph: StrokeGlyph.search,
            tint: colors.surfaceAlt,
            iconColor: colors.textMuted,
            title: context.strings.documentDetailsNotFoundTitle,
            message: context.strings.documentDetailsNotFoundMessage,
            onClose: onClose,
          ),
          DocumentDetailsUnavailable() => _StateBody(
            glyph: StrokeGlyph.warningTriangle,
            tint: colors.warningTint,
            iconColor: colors.warning,
            title: context.strings.documentDetailsErrorTitle,
            message: context.strings.documentDetailsErrorMessage,
            onClose: onClose,
          ),
        },
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: AppColors.light.brandPrimary,
        semanticsLabel: context.strings.stateLoading,
      ),
    );
  }
}

/// The document is gone, or could not be read — one layout, two sets of
/// words, the same shape [ServiceStateView]'s callers already use.
class _StateBody extends StatelessWidget {
  const _StateBody({
    required this.glyph,
    required this.tint,
    required this.iconColor,
    required this.title,
    required this.message,
    this.onClose,
  });

  final StrokeGlyph glyph;
  final Color tint;
  final Color iconColor;
  final String title;
  final String message;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return ServiceStateView(
      glyph: glyph,
      tint: tint,
      iconColor: iconColor,
      title: title,
      message: message,
      primary: ServiceStateAction(
        label: strings.documentDetailsBackToList,
        onPressed: onClose ?? () {},
      ),
      onBack: onClose,
    );
  }
}

/// The top bar and the ordered sections.
class _DetailsBody extends StatelessWidget {
  const _DetailsBody({
    required this.document,
    required this.sections,
    this.onClose,
  });

  final SavedDocument document;
  final List<AnalysisSection> sections;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

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
                // fully understood one, whatever it managed to fill in — the
                // same rule the result screen follows for the same status.
                if (document.analysis.isPartial) const PartialResultBanner(),
                for (final section in sections)
                  _section(section, strings),
                // «ملاحظتي» lives between the analysis sections and the
                // explanation/extracted-text panels — the same position the
                // design draws it in, after the paper's own content and
                // before the raw OCR output (F08-T09).
                _NoteSection(document: document),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The widget for one section — the result screen's own mapping, over the
  /// document that was saved instead of the one just analysed. `dates` and
  /// `extractedText` leave out the actions the result screen offers there
  /// (a reminder, listening aloud): neither has anywhere to go yet, and a
  /// button that does nothing is worse than none (F09, F10).
  Widget _section(AnalysisSection section, AppStrings strings) {
    const colors = AppColors.light;
    final analysis = document.analysis;

    return switch (section) {
      AnalysisSection.header => ResultHeaderCard(analysis: analysis),
      AnalysisSection.summary => ResultSummaryCard(
        summary: analysis.summary.short,
      ),
      AnalysisSection.actionRequired => ResultActionsCard(
        actions: analysis.actions,
      ),
      AnalysisSection.warnings => ResultWarningsCard(
        warnings: analysis.warnings,
      ),
      AnalysisSection.keyInformation => ResultKeyInformationCard(
        items: analysis.keyInformation,
      ),
      AnalysisSection.amounts => ResultAmountsCard(amounts: analysis.amounts),
      AnalysisSection.dates => ResultDatesCard(dates: analysis.dates),
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
        gapAbove: _explanationGapAbove,
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
        text: document.extractedText,
      ),
    };
  }
}

/// Handles the note section's add / edit / delete actions (F08-T09).
///
/// Stateless: every action pops up a sheet or a dialog, and the cubit's
/// watcher refreshes the screen once the write lands. Snackbar feedback
/// confirms the outcome so the user is never left guessing.
class _NoteSection extends StatelessWidget {
  const _NoteSection({required this.document});

  final SavedDocument document;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DocumentDetailsCubit>();
    final strings = context.strings;

    return DocumentNoteCard(
      note: document.note,
      onAdd: () => _openEditor(context, cubit, strings),
      onEdit: () => _openEditor(context, cubit, strings,
          initial: document.note),
      onDelete: () => _confirmDelete(context, cubit, strings),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    DocumentDetailsCubit cubit,
    AppStrings strings, {
    String? initial,
  }) async {
    final text = await showNoteEditorSheet(context, initial: initial);
    if (text == null || !context.mounted) return;

    final ok = await cubit.saveNote(text);
    if (!context.mounted) return;
    _showFeedback(
      context,
      ok ? strings.documentNoteSaved : strings.documentNoteError,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DocumentDetailsCubit cubit,
    AppStrings strings,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(strings.documentNoteDeleteConfirmTitle),
        content: Text(strings.documentNoteDeleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await cubit.deleteNote();
    if (!context.mounted) return;
    _showFeedback(
      context,
      ok ? strings.documentNoteDeleted : strings.documentNoteError,
    );
  }

  void _showFeedback(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// The page's own bar: a way back, and the page's name.
///
/// The design also draws an overflow button on the trailing side, for rename
/// and delete (F08-T10, F08-T11). Nothing lives behind it yet, so the space
/// is held open rather than filled with a menu that does nothing.
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
                    strings.documentDetailsTitle,
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
