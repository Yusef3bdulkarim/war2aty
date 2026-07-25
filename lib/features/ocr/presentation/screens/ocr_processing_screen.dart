import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/extraction_result.dart';
import '../cubit/ocr_processing_cubit.dart';
import '../cubit/ocr_processing_state.dart';
import '../widgets/candidate_chips.dart';
import '../widgets/field_review_sheet.dart';

/// The OCR processing screen: shows a loading state while OCR runs,
/// then either an error / no-text state, or the extracted-text result.
///
/// This single screen covers T12 (failure states) and T13 (extracted text).
class OcrProcessingScreen extends StatelessWidget {
  const OcrProcessingScreen({
    required this.onContinue,
    required this.onRetake,
    required this.onPickAnother,
    super.key,
  });

  final VoidCallback onContinue;
  final VoidCallback onRetake;
  final VoidCallback onPickAnother;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.light.surface,
      body: SafeArea(
        child: BlocConsumer<OcrProcessingCubit, OcrProcessingState>(
          listener: (context, state) {
            if (state is OcrCompleted && state.result.hasAmbiguousCandidates) {
              _showFieldReviewSheet(context, state.result);
            }
          },
          builder: (context, state) => switch (state) {
            OcrProcessing() => _buildProcessing(context),
            OcrError() => _buildError(context),
            OcrNoText() => _buildNoText(context),
            OcrCompleted(:final result) => _buildCompleted(context, result),
          },
        ),
      ),
    );
  }

  Widget _buildProcessing(BuildContext context) {
    final strings = context.strings;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.light.brandPrimary),
          const SizedBox(height: AppSpacing.lg),
          Text(
            strings.ocrProcessing,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.light.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final strings = context.strings;
    return _buildFailureView(
      context,
      icon: Icons.error_outline,
      title: strings.ocrErrorTitle,
      message: strings.ocrErrorMessage,
    );
  }

  Widget _buildNoText(BuildContext context) {
    final strings = context.strings;
    return _buildFailureView(
      context,
      icon: Icons.text_snippet_outlined,
      title: strings.ocrNoTextTitle,
      message: strings.ocrNoTextMessage,
    );
  }

  Widget _buildFailureView(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    final strings = context.strings;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.light.textMuted),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.light.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.light.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxxl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onRetake,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.light.brandPrimary,
                  foregroundColor: AppColors.light.onBrand,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
                child: Text(strings.ocrRetake),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onPickAnother,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.light.brandPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppColors.light.brandPrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
                child: Text(strings.ocrPickAnother),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleted(BuildContext context, ExtractionResult result) {
    final strings = context.strings;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.lg,
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  strings.ocrExtractedTextTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.light.ink,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _copyText(context, result),
                icon: Icon(Icons.copy, color: AppColors.light.brandPrimary),
                tooltip: strings.ocrCopyText,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.light.card,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: AppColors.light.borderSoft),
                  ),
                  child: SelectableText(
                    result.text.cleanedText,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: AppColors.light.textBody,
                    ),
                  ),
                ),
                if (result.totalCandidates > 0) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  CandidateChips(result: result),
                ],
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
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
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.light.brandPrimary,
                foregroundColor: AppColors.light.onBrand,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
              ),
              child: Text(strings.ocrContinue),
            ),
          ),
        ),
      ],
    );
  }

  void _copyText(BuildContext context, ExtractionResult result) {
    Clipboard.setData(ClipboardData(text: result.text.cleanedText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.strings.ocrTextCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showFieldReviewSheet(BuildContext context, ExtractionResult result) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.light.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (_) => FieldReviewSheet(result: result),
    );
  }
}
