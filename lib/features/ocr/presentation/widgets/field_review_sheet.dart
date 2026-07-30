import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/extraction_result.dart';

class FieldReviewSheet extends StatelessWidget {
  const FieldReviewSheet({required this.result, super.key});

  final ExtractionResult result;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ambiguous = _collectAmbiguous(strings);

    return DraggableScrollableSheet(
      minChildSize: 0.3,
      maxChildSize: 0.85,

      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.light.borderStrong,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.lg,
              AppSpacing.screenHorizontal,
              AppSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.ocrReviewTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.light.ink,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  strings.ocrReviewSubtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.light.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
                vertical: AppSpacing.md,
              ),
              itemCount: ambiguous.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final item = ambiguous[index];
                return _ReviewTile(
                  icon: item.icon,
                  sectionLabel: item.sectionLabel,
                  rawText: item.rawText,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              AppSpacing.lg,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.light.brandPrimary,
                  foregroundColor: AppColors.light.onBrand,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
                child: Text(strings.ocrReviewDone),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_AmbiguousItem> _collectAmbiguous(AppStrings strings) {
    final items = <_AmbiguousItem>[];
    for (final c in result.dates.where((c) => c.isAmbiguous)) {
      items.add(
        _AmbiguousItem(
          Icons.calendar_today,
          strings.ocrDatesSection,
          c.rawText,
        ),
      );
    }
    for (final c in result.times.where((c) => c.isAmbiguous)) {
      items.add(
        _AmbiguousItem(Icons.schedule, strings.ocrTimesSection, c.rawText),
      );
    }
    for (final c in result.amounts.where((c) => c.isAmbiguous)) {
      items.add(
        _AmbiguousItem(
          Icons.payments_outlined,
          strings.ocrAmountsSection,
          c.rawText,
        ),
      );
    }
    for (final c in result.phones.where((c) => c.isAmbiguous)) {
      items.add(
        _AmbiguousItem(
          Icons.phone_outlined,
          strings.ocrPhonesSection,
          c.rawText,
        ),
      );
    }
    for (final c in result.references.where((c) => c.isAmbiguous)) {
      items.add(
        _AmbiguousItem(Icons.tag, strings.ocrReferencesSection, c.rawText),
      );
    }
    return items;
  }
}

class _AmbiguousItem {
  const _AmbiguousItem(this.icon, this.sectionLabel, this.rawText);
  final IconData icon;
  final String sectionLabel;
  final String rawText;
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.icon,
    required this.sectionLabel,
    required this.rawText,
  });

  final IconData icon;
  final String sectionLabel;
  final String rawText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.light.warningTint,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: AppColors.light.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: AppColors.light.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: AppColors.light.warningInk),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      sectionLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.light.warningInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  rawText,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.light.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
