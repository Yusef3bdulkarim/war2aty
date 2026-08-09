import 'package:flutter/material.dart';

import '../../../../core/documents/recent_document.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';

// From `Waraqti.dc.html` → the «حفظ الورقة» sheet's save-mode section.
const double _sheetRadius = 26;
const double _sheetPaddingTop = 12;
const double _sheetPaddingH = 22;
const double _sheetPaddingBottom = 30;
const double _sheetMaxHeightFactor = 0.88;
const double _grabberWidth = 40;
const double _grabberHeight = 5;
const double _grabberGapBelow = 18;
const double _titleFontSize = 19;
const double _titleGapBelow = 18;
const double _labelFontSize = 13;
const double _labelGapBelow = 8;
const double _optionRadius = 15;
const double _optionBorderWidth = 2;
const double _optionPaddingH = 15;
const double _optionPaddingV = 14;
const double _optionGap = 9;
const double _optionsGapBelow = 22;
const double _dotOuter = 22;
const double _dotInner = 11;
const double _dotGap = 11;
const double _optionTitleFontSize = 15;
const double _optionSubtitleFontSize = 13;
const double _optionSubtitleGapAbove = 3;
const double _optionSubtitleHeight = 1.55;
const double _buttonHeight = 54;
const double _buttonRadius = 15;
const double _buttonFontSize = 17;

/// Asks whether to keep just the result, or the result and the page picture
/// too — the explicit opt-in the privacy default requires (F08-T04).
///
/// Answers the chosen [DocumentStorageMode], or `null` if the sheet was
/// dismissed without confirming: either way nothing is saved by this call
/// alone, only decided.
Future<DocumentStorageMode?> showSaveModeSheet(BuildContext context) {
  return showModalBottomSheet<DocumentStorageMode>(
    context: context,
    backgroundColor: AppColors.light.card,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * _sheetMaxHeightFactor,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
    ),
    builder: (_) => const SaveModeSheet(),
  );
}

/// The body of that sheet: a two-way choice, defaulting to the privacy
/// default, and a button that confirms whichever is picked.
class SaveModeSheet extends StatefulWidget {
  const SaveModeSheet({super.key});

  @override
  State<SaveModeSheet> createState() => _SaveModeSheetState();
}

class _SaveModeSheetState extends State<SaveModeSheet> {
  // Local UI state: which option is highlighted before the user confirms.
  // Never anything but resultOnly until the user themselves picks otherwise
  // (CLAUDE.md §7 — the default is never pre-empted).
  DocumentStorageMode _mode = DocumentStorageMode.resultOnly;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          _sheetPaddingH,
          _sheetPaddingTop,
          _sheetPaddingH,
          _sheetPaddingBottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: _grabberWidth,
                height: _grabberHeight,
                margin: const EdgeInsets.only(bottom: _grabberGapBelow),
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
            Semantics(
              header: true,
              child: Text(
                strings.resultSavePaper,
                style: AppTypography.titleLarge.copyWith(
                  fontSize: _titleFontSize,
                  fontWeight: AppTypography.extraBold,
                  color: colors.ink,
                ),
              ),
            ),
            const SizedBox(height: _titleGapBelow),
            Text(
              strings.saveModeSectionLabel,
              style: AppTypography.caption.copyWith(
                fontSize: _labelFontSize,
                fontWeight: AppTypography.bold,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: _labelGapBelow),
            _ModeOption(
              title: strings.saveModeResultOnlyTitle,
              subtitle: strings.saveModeResultOnlySubtitle,
              selected: _mode == DocumentStorageMode.resultOnly,
              onTap: () =>
                  setState(() => _mode = DocumentStorageMode.resultOnly),
            ),
            const SizedBox(height: _optionGap),
            _ModeOption(
              title: strings.saveModeWithImageTitle,
              subtitle: strings.saveModeWithImageSubtitle,
              selected: _mode == DocumentStorageMode.withImage,
              onTap: () =>
                  setState(() => _mode = DocumentStorageMode.withImage),
            ),
            const SizedBox(height: _optionsGapBelow),
            SizedBox(
              height: _buttonHeight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_mode),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.brandPrimary,
                  foregroundColor: colors.onBrand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_buttonRadius),
                  ),
                  textStyle: AppTypography.labelMedium.copyWith(
                    fontSize: _buttonFontSize,
                    fontWeight: AppTypography.bold,
                  ),
                ),
                child: Text(strings.actionSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One radio-style choice: a title and an explanation of what it keeps.
class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Material(
      color: selected ? colors.surfaceTeal : colors.card,
      borderRadius: BorderRadius.circular(_optionRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_optionRadius),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? colors.brandPrimary : colors.borderSoft,
              width: _optionBorderWidth,
            ),
            borderRadius: BorderRadius.circular(_optionRadius),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: _optionPaddingH,
            vertical: _optionPaddingV,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Container(
                  width: _dotOuter,
                  height: _dotOuter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? colors.brandPrimary : colors.border,
                      width: _optionBorderWidth,
                    ),
                  ),
                  child: selected
                      ? Center(
                          child: Container(
                            width: _dotInner,
                            height: _dotInner,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.brandPrimary,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: _dotGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.labelCard.copyWith(
                        fontSize: _optionTitleFontSize,
                        fontWeight: AppTypography.bold,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: _optionSubtitleGapAbove),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        fontSize: _optionSubtitleFontSize,
                        fontWeight: AppTypography.medium,
                        height: _optionSubtitleHeight,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
