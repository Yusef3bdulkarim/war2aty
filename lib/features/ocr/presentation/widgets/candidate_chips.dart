import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/extraction_result.dart';

class CandidateChips extends StatelessWidget {
  const CandidateChips({required this.result, super.key});

  final ExtractionResult result;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.dates.isNotEmpty)
          _Section(
            label: strings.ocrDatesSection,
            icon: Icons.calendar_today,
            chips: result.dates.map((c) => _ChipData(c.rawText, c.isAmbiguous)),
          ),
        if (result.times.isNotEmpty)
          _Section(
            label: strings.ocrTimesSection,
            icon: Icons.schedule,
            chips: result.times.map((c) => _ChipData(c.rawText, c.isAmbiguous)),
          ),
        if (result.amounts.isNotEmpty)
          _Section(
            label: strings.ocrAmountsSection,
            icon: Icons.payments_outlined,
            chips: result.amounts.map(
              (c) => _ChipData(c.rawText, c.isAmbiguous),
            ),
          ),
        if (result.phones.isNotEmpty)
          _Section(
            label: strings.ocrPhonesSection,
            icon: Icons.phone_outlined,
            chips: result.phones.map(
              (c) => _ChipData(c.rawText, c.isAmbiguous),
            ),
          ),
        if (result.references.isNotEmpty)
          _Section(
            label: strings.ocrReferencesSection,
            icon: Icons.tag,
            chips: result.references.map(
              (c) => _ChipData(c.rawText, c.isAmbiguous),
            ),
          ),
      ],
    );
  }
}

class _ChipData {
  const _ChipData(this.text, this.isAmbiguous);
  final String text;
  final bool isAmbiguous;
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.icon,
    required this.chips,
  });

  final String label;
  final IconData icon;
  final Iterable<_ChipData> chips;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.light.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.light.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: chips.map(_buildChip).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(_ChipData data) {
    final bgColor = data.isAmbiguous
        ? AppColors.light.warningTint
        : AppColors.light.surfaceTeal;
    final fgColor = data.isAmbiguous
        ? AppColors.light.warningInk
        : AppColors.light.brandDeep;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (data.isAmbiguous) ...[
            Icon(Icons.info_outline, size: 14, color: fgColor),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              data.text,
              style: TextStyle(fontSize: 13, color: fgColor),
            ),
          ),
        ],
      ),
    );
  }
}
