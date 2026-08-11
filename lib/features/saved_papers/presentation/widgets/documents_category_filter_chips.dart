import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/documents/document_category.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';
import '../cubit/documents_list_cubit.dart';

// From `Waraqti.dc.html` → `isDocuments`, the `hasDocs` chip row.
const double _height = 34;
const double _gap = 8;
const double _paddingH = 16;
const double _paddingV = 8;

/// The «مستنداتي» category filter chips (F08-T07): «الكل» plus one chip per
/// [DocumentCategory], in a row the user scrolls horizontally rather than one
/// that wraps — five chips do not all fit a narrow phone on one line.
///
/// Reads [DocumentsListCubit] directly to send a tap, the same pattern
/// `DocumentsSearchField` uses for a keystroke — the row has nothing else to
/// do with a selection.
class DocumentsCategoryFilterChips extends StatelessWidget {
  const DocumentsCategoryFilterChips({required this.selected, super.key});

  /// The chip currently active; `null` means «الكل» — every category.
  final DocumentCategory? selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: DocumentCategory.values.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: _gap),
        itemBuilder: (context, index) {
          final category = index == 0
              ? null
              : DocumentCategory.values[index - 1];
          return _Chip(
            label: index == 0
                ? context.strings.documentsFilterAll
                : _labelOf(context.strings, category!),
            isSelected: category == selected,
            onTap: () =>
                context.read<DocumentsListCubit>().filterByCategory(category),
          );
        },
      ),
    );
  }
}

String _labelOf(AppStrings s, DocumentCategory category) => switch (category) {
  DocumentCategory.appointment => s.documentsFilterAppointment,
  DocumentCategory.invoice => s.documentsFilterInvoice,
  DocumentCategory.government => s.documentsFilterGovernment,
  DocumentCategory.education => s.documentsFilterEducation,
  DocumentCategory.other => s.documentsFilterOther,
};

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = BorderRadius.circular(AppRadii.pill);

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: isSelected ? colors.brandPrimary : colors.card,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _paddingH,
              // vertical: _paddingV,
            ),
            child: Center(
              child: Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: AppTypography.bold,
                  color: isSelected ? colors.onBrand : colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
