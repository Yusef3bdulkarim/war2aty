import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../documents/analysis_amount.dart';
import '../documents/analysis_date.dart';
import '../documents/analysis_section.dart';
import '../documents/confidence_label.dart';
import '../documents/key_information.dart';
import '../icons/stroke_icon.dart';
import '../localization/app_localizations.dart';
import '../money/document_amount_label.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'caveated_value.dart';
import 'result_date_row.dart';

// The owner's result-screen review (F21 locked decisions #3 and #9).
const double _rowPaddingH = 16;
const double _rowPaddingV = 14;
const double _rowGap = 8;
// A labelled row: its copy button brings its own 48 dp of room, so the end
// side needs less padding than the start.
const double _rowPaddingStart = 16;
const double _rowPaddingEnd = 4;
const double _twoLinePaddingV = 12;
const double _labelValueGap = 12;

/// Above this text scale a row always takes two lines (F21 #16): a label and
/// a value side by side at that size read as one run of words.
const double _largeTextScale = 1.3;
const double _labelGapBelow = 2;
const double _valueFontSize = 16;
const double _subHeaderTop = 14;
const double _subHeaderBottom = 2;
const double _reminderBottom = 16;
const double _copyTarget = 48;
const double _copyIconSize = 16;
const double _cardGapBelow = AppSpacing.resultCardGap;

/// How long the "copied" confirmation stays up.
const Duration _copiedFeedback = Duration(seconds: 2);

/// The sections [ResultDetailsCard] draws together, in §4 order.
const Set<AnalysisSection> resultDetailsSections = {
  AnalysisSection.keyInformation,
  AnalysisSection.amounts,
  AnalysisSection.dates,
};

/// Whether [section] is where the details card goes in [sections]: the first
/// of [resultDetailsSections] present. The others it absorbs draw nothing, so
/// the §4 order (the domain's) is kept and the card appears exactly once.
bool isResultDetailsSlot(
  List<AnalysisSection> sections,
  AnalysisSection section,
) =>
    resultDetailsSections.contains(section) &&
    sections.firstWhere(resultDetailsSections.contains) == section;

/// Everything read off the paper, in one card: «أهم المعلومات», «المبالغ»,
/// then «التواريخ والمواعيد», each under a small neutral sub-header (F21
/// locked decision #9).
///
/// Every row stands on its own: a value the analysis is unsure of, or worked
/// out rather than read, says so in words beside it. Confidence is never
/// summarised for the whole document and no row is badged "clear" (UX rules
/// §5.9 and §5.10).
///
/// Values can be copied — these are the numbers a user retypes into a payment
/// app or reads out on the phone. An amount copies the figure alone; a date
/// has no copy button.
///
/// The dates group ends with «إنشاء تذكير», the branch point into a reminder —
/// where the user, not the app, picks which date it is for (§5.8).
class ResultDetailsCard extends StatelessWidget {
  const ResultDetailsCard({
    required this.keyInformation,
    required this.amounts,
    required this.dates,
    this.onCreateReminder,
    super.key,
  }) : assert(
         keyInformation.length + amounts.length + dates.length > 0,
         'BuildAnalysisResult drops these sections when there is nothing to show',
       );

  final List<KeyInformation> keyInformation;
  final List<AnalysisAmount> amounts;

  /// In the order the analysis reported them.
  final List<AnalysisDate> dates;

  /// Starts a reminder for the date the user settled on. Absent until there
  /// is somewhere for it to go (F09); the button is left out while it is —
  /// better no button than one that does nothing.
  final ValueChanged<AnalysisDate>? onCreateReminder;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    final groups = [
      if (keyInformation.isNotEmpty)
        (
          title: strings.resultKeyInformationTitle,
          footer: null,
          rows: <Widget>[
            for (final item in keyInformation)
              _DetailRow(
                label: item.label,
                value: item.value,
                caveats: [
                  ?confidenceLabel(strings, item.confidence),
                  if (item.source == InfoSource.inferred)
                    strings.resultActionInferred,
                ],
                copyText: item.value,
              ),
          ],
        ),
      if (amounts.isNotEmpty)
        (
          title: strings.resultAmountsTitle,
          footer: null,
          rows: <Widget>[
            for (final amount in amounts)
              _DetailRow(
                label: amount.label,
                value: formatDocumentAmount(
                  strings,
                  amount.value,
                  amount.currency,
                ),
                caveats: [?confidenceLabel(strings, amount.confidence)],
                copyText: formatAmountNumber(amount.value),
              ),
          ],
        ),
      if (dates.isNotEmpty)
        (
          title: strings.resultDatesTitle,
          footer: switch (onCreateReminder) {
            final onCreateReminder? => Padding(
              padding: const EdgeInsets.fromLTRB(
                _rowPaddingH,
                0,
                _rowPaddingH,
                _reminderBottom,
              ),
              child: ResultReminderButton(
                dates: dates,
                onCreateReminder: onCreateReminder,
              ),
            ),
            null => null,
          },
          rows: <Widget>[
            for (final date in dates)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _rowPaddingH,
                  vertical: _rowPaddingV,
                ),
                child: ResultDateRow(date: date),
              ),
          ],
        ),
    ];

    final divider = Divider(height: 1, thickness: 1, color: colors.surfaceAlt);

    return Padding(
      padding: const EdgeInsets.only(bottom: _cardGapBelow),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          boxShadow: AppShadows.card,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, group) in groups.indexed) ...[
                if (index > 0) divider,
                _SubHeader(title: group.title),
                for (final (rowIndex, row) in group.rows.indexed) ...[
                  if (rowIndex > 0) divider,
                  row,
                ],
                ?group.footer,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The small neutral name of a group, announced as a heading so a screen
/// reader can still jump between the blocks of a long result.
class _SubHeader extends StatelessWidget {
  const _SubHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _rowPaddingH,
        _subHeaderTop,
        _rowPaddingH,
        _subHeaderBottom,
      ),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: AppTypography.caption.copyWith(
            fontWeight: AppTypography.bold,
            // Not `textMuted` (3.0:1): 13 px text needs 4.5:1 (F21 #18).
            color: colors.textCaption,
          ),
        ),
      ),
    );
  }
}

/// One labelled value, with a copy button at the end.
///
/// On one line — the label on the start side, the value on the end side —
/// whenever that line can hold both (F21 locked decision #16). It falls back
/// to the label above the value when the value is too long for the line, when
/// a caution chip has to sit beside it, or under Large Text, so nothing is
/// ever squeezed or cut off.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.caveats,
    required this.copyText,
  });

  final String label;
  final String value;
  final List<String> caveats;

  /// What the copy button puts on the clipboard.
  final String copyText;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final labelStyle = AppTypography.caption.copyWith(
      fontWeight: AppTypography.semiBold,
      color: colors.textCaption,
    );
    final valueStyle = AppTypography.bodyLarge.copyWith(
      fontSize: _valueFontSize,
      fontWeight: AppTypography.bold,
      color: colors.ink,
    );
    final copy = _CopyButton(label: label, text: copyText);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textWidth =
            constraints.maxWidth -
            _rowPaddingStart -
            _rowPaddingEnd -
            _rowGap -
            _copyTarget;
        final oneLine =
            caveats.isEmpty &&
            MediaQuery.textScalerOf(context).scale(1) <= _largeTextScale &&
            _fitsOnOneLine(context, textWidth, labelStyle, valueStyle);

        if (oneLine) {
          return Padding(
            padding: const EdgeInsetsDirectional.only(
              start: _rowPaddingStart,
              end: _rowPaddingEnd,
            ),
            child: Row(
              children: [
                Expanded(child: Text(label, style: labelStyle)),
                const SizedBox(width: _labelValueGap),
                Text(value, style: valueStyle),
                const SizedBox(width: _rowGap),
                copy,
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            _rowPaddingStart,
            _twoLinePaddingV,
            _rowPaddingEnd,
            _twoLinePaddingV,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: labelStyle),
                    const SizedBox(height: _labelGapBelow),
                    CaveatedValue(
                      value: Text(value, style: valueStyle),
                      caveats: caveats,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: _rowGap),
              copy,
            ],
          ),
        );
      },
    );
  }

  /// Whether the label and the value, side by side, fit in [width] at the
  /// user's text size.
  bool _fitsOnOneLine(
    BuildContext context,
    double width,
    TextStyle labelStyle,
    TextStyle valueStyle,
  ) {
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);

    double widthOf(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final measured = painter.width;
      painter.dispose();
      return measured;
    }

    return widthOf(label, labelStyle) +
            _labelValueGap +
            widthOf(value, valueStyle) <=
        width;
  }
}

/// Puts one value on the clipboard: a small, quiet icon on a full-size tap
/// target (F12-T01's 48 dp floor).
class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.label, required this.text});

  /// The row's label, so a screen reader says what is being copied.
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    return SizedBox.square(
      dimension: _copyTarget,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _copy(context),
          child: Semantics(
            button: true,
            label: strings.resultCopyValueLabel(label),
            child: Center(
              child: StrokeIcon(
                StrokeGlyph.copy,
                color: colors.textMuted,
                size: _copyIconSize,
                strokeWidth: 1.9,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.strings.ocrTextCopied),
        duration: _copiedFeedback,
      ),
    );
  }
}
