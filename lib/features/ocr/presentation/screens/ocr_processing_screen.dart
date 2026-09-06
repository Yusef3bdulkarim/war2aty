import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../cubit/ocr_processing_cubit.dart';
import '../cubit/ocr_processing_state.dart';

/// The OCR processing screen: shows a loading state while offline OCR runs,
/// then either an error / no-text state, or auto-navigates to the unified
/// review screen on success.
///
/// This screen covers T12 (failure states) and the loading indicator.
/// The completed-text view that was previously inline here has moved to
/// `OcrReviewScreen`, which now serves both online and offline flows.
class OcrProcessingScreen extends StatelessWidget {
  const OcrProcessingScreen({
    required this.onCompleted,
    required this.onRetake,
    required this.onPickAnother,
    super.key,
  });

  /// Called when OCR finishes successfully — the caller navigates to the
  /// unified review screen. Replaces the old `onContinue` which required
  /// a manual tap.
  final VoidCallback onCompleted;
  final VoidCallback onRetake;
  final VoidCallback onPickAnother;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).surface,
      body: SafeArea(
        child: BlocConsumer<OcrProcessingCubit, OcrProcessingState>(
          listener: (context, state) {
            if (state is OcrCompleted) {
              // Auto-navigate to the unified review screen.
              onCompleted();
            }
          },
          builder: (context, state) => switch (state) {
            OcrProcessing() => _buildProcessing(context),
            OcrError() => _buildError(context),
            OcrNoText() => _buildNoText(context),
            // While navigating away, keep the loading indicator rather than
            // flashing the completed state inline.
            OcrCompleted() => _buildProcessing(context),
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
          CircularProgressIndicator(color: AppColors.of(context).brandPrimary),
          const SizedBox(height: AppSpacing.lg),
          Text(
            strings.ocrProcessing,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.of(context).textSecondary,
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
            Icon(icon, size: 64, color: AppColors.of(context).textMuted),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.of(context).ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.of(context).textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxxl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onRetake,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.of(context).brandPrimary,
                  foregroundColor: AppColors.of(context).onBrand,
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
                  foregroundColor: AppColors.of(context).brandPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppColors.of(context).brandPrimary),
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
}
