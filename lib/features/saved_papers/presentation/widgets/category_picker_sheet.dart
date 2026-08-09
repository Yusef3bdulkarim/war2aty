import 'package:flutter/material.dart';

import '../../../../core/documents/document_category.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';

// From `Waraqti.dc.html` → save sheet (reuses the same sheet chrome).
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
const double _optionGap = 10;
const double _optionPaddingH = 16;
const double _optionPaddingV = 14;
const double _optionRadius = 13;
const double _optionFontSize = 15;

/// Opens a sheet that lets the user pick a new category (F08-T10).
///
/// Returns the chosen [DocumentCategory], or `null` if dismissed.
/// [current] highlights which category the document already has.
Future<DocumentCategory?> showCategoryPickerSheet(
  BuildContext context, {
  required DocumentCategory current,
}) => showModalBottomSheet<DocumentCategory>(
  context: context,
  backgroundColor: AppColors.light.card,
  isScrollControlled: true,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * _sheetMaxHeightFactor,
  ),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
  ),
  builder: (_) => _CategoryPickerSheet(current: current),
);

class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({required this.current});

  final DocumentCategory current;

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
                strings.documentEditCategoryHeading,
                style: AppTypography.titleLarge.copyWith(
                  fontSize: _titleFontSize,
                  fontWeight: AppTypography.extraBold,
                  color: colors.ink,
                ),
              ),
            ),
            const SizedBox(height: _titleGapBelow),
            for (final category in DocumentCategory.values)
              Padding(
                padding: EdgeInsets.only(
                  bottom: category == DocumentCategory.values.last
                      ? 0
                      : _optionGap,
                ),
                child: _CategoryOption(
                  category: category,
                  label: _labelOf(strings, category),
                  isSelected: category == current,
                  onTap: () => Navigator.of(context).pop(category),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _labelOf(AppStrings s, DocumentCategory category) => switch (category) {
  DocumentCategory.appointment => s.documentCategoryAppointment,
  DocumentCategory.invoice => s.documentCategoryInvoice,
  DocumentCategory.government => s.documentCategoryGovernment,
  DocumentCategory.education => s.documentCategoryEducation,
  DocumentCategory.other => s.documentCategoryOther,
};

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.category,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final DocumentCategory category;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final radius = BorderRadius.circular(_optionRadius);

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: isSelected ? colors.brandPrimary : colors.surface,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _optionPaddingH,
              vertical: _optionPaddingV,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: _optionFontSize,
                      fontWeight: isSelected
                          ? AppTypography.bold
                          : AppTypography.regular,
                      color: isSelected ? colors.onBrand : colors.textBody,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_rounded, color: colors.onBrand, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
