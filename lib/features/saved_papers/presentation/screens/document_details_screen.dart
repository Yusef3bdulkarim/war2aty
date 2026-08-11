import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/documents/analysis_date.dart';
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
import '../widgets/category_picker_sheet.dart';
import '../widgets/document_note_card.dart';
import '../widgets/note_editor_sheet.dart';
import '../widgets/title_editor_sheet.dart';

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
  const DocumentDetailsScreen({this.onClose, this.onCreateReminder, super.key});

  /// Leaves the details screen. The router supplies it; optional so the
  /// screen can be pumped on its own in a widget test.
  final VoidCallback? onClose;

  /// Starts a reminder for the date the user chose (F09). Absent until the
  /// router wires it, same convention `AnalysisResultScreen` uses.
  final ValueChanged<AnalysisDate>? onCreateReminder;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

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
              onCreateReminder: onCreateReminder,
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
        color: AppColors.of(context).brandPrimary,
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
    this.onCreateReminder,
  });

  final SavedDocument document;
  final List<AnalysisSection> sections;
  final VoidCallback? onClose;
  final ValueChanged<AnalysisDate>? onCreateReminder;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Column(
      children: [
        _TopBar(document: document, onClose: onClose),
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
                  _section(context, section, strings),
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
  /// document that was saved instead of the one just analysed. `extractedText`
  /// leaves out the action the result screen offers there (listening aloud):
  /// there is no reader yet, and a button that does nothing is worse than
  /// none (F10). `dates` now offers the reminder action (F09) same as the
  /// result screen's.
  Widget _section(
    BuildContext context,
    AnalysisSection section,
    AppStrings strings,
  ) {
    final colors = AppColors.of(context);
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
      AnalysisSection.dates => ResultDatesCard(
        dates: analysis.dates,
        onCreateReminder: onCreateReminder,
      ),
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
      onEdit: () =>
          _openEditor(context, cubit, strings, initial: document.note),
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

/// The page's own bar: a way back, the page's name, and an overflow menu for
/// rename and category change (F08-T10).
class _TopBar extends StatelessWidget {
  const _TopBar({required this.document, this.onClose});

  final SavedDocument document;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
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
              _OverflowMenu(document: document, onClose: onClose),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three-dot menu that holds rename and category change (F08-T10).
///
/// Each action opens a bottom sheet, writes through the cubit, and shows a
/// snackbar — the same feedback pattern the note section uses (F08-T09).
enum _OverflowAction { editTitle, editCategory, delete }

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.document, this.onClose});

  final SavedDocument document;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    return SizedBox.square(
      dimension: _topBarButton,
      child: PopupMenuButton<_OverflowAction>(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.more_vert, color: colors.ink),
        onSelected: (action) => _handle(context, action, strings),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: _OverflowAction.editTitle,
            child: Text(strings.documentEditTitle),
          ),
          PopupMenuItem(
            value: _OverflowAction.editCategory,
            child: Text(strings.documentEditCategory),
          ),
          PopupMenuItem(
            value: _OverflowAction.delete,
            child: Text(
              strings.documentDeleteAction,
              style: TextStyle(color: colors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _handle(
    BuildContext context,
    _OverflowAction action,
    AppStrings strings,
  ) {
    switch (action) {
      case _OverflowAction.editTitle:
        _editTitle(context, strings);
      case _OverflowAction.editCategory:
        _editCategory(context, strings);
      case _OverflowAction.delete:
        _confirmDelete(context, strings);
    }
  }

  Future<void> _editTitle(BuildContext context, AppStrings strings) async {
    final cubit = context.read<DocumentDetailsCubit>();
    final title = await showTitleEditorSheet(
      context,
      current: document.analysis.title,
    );
    if (title == null || !context.mounted) return;

    final ok = await cubit.updateTitle(title);
    if (!context.mounted) return;
    _showFeedback(
      context,
      ok ? strings.documentTitleUpdated : strings.documentUpdateError,
    );
  }

  Future<void> _editCategory(BuildContext context, AppStrings strings) async {
    final cubit = context.read<DocumentDetailsCubit>();
    final category = await showCategoryPickerSheet(
      context,
      current: document.analysis.category,
    );
    if (category == null || !context.mounted) return;

    final ok = await cubit.updateCategory(category);
    if (!context.mounted) return;
    _showFeedback(
      context,
      ok ? strings.documentCategoryUpdated : strings.documentUpdateError,
    );
  }

  /// Confirms, then permanently removes the document (F08-T11). On success
  /// the screen navigates back — the watcher would eventually show "not found",
  /// but popping immediately is what the user expects.
  Future<void> _confirmDelete(BuildContext context, AppStrings strings) async {
    final cubit = context.read<DocumentDetailsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(strings.documentDeleteConfirmTitle),
        content: Text(strings.documentDeleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              strings.actionDelete,
              style: TextStyle(color: AppColors.of(context).error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await cubit.deleteDocument();
    if (!context.mounted) return;

    if (ok) {
      _showFeedback(context, strings.documentDeleted);
      onClose?.call();
    } else {
      _showFeedback(context, strings.documentDeleteError);
    }
  }

  void _showFeedback(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
