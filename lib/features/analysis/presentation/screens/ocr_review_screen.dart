import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../ocr/presentation/widgets/candidate_chips.dart';
import '../cubit/ocr_review_cubit.dart';
import '../cubit/ocr_review_state.dart';

/// The OCR review screen (F14): the online route's stop between Azure OCR
/// and Groq analysis. Shows the OCR text editable, candidate hints, and an
/// optional image preview, so the user can correct the reading before it is
/// spent on an analysis.
///
/// Structurally mirrors `OcrProcessingScreen` (the offline sibling) — same
/// layout conventions, same widget reuse — rather than a new design, since
/// this screen has no `Waraqti.dc.html` frame of its own.
class OcrReviewScreen extends StatelessWidget {
  const OcrReviewScreen({
    required this.onAnalyze,
    required this.onRetake,
    required this.onPickAnother,
    this.onOpenSettings,
    super.key,
  });

  final VoidCallback onAnalyze;
  final VoidCallback onRetake;
  final VoidCallback onPickAnother;

  /// The way out of a declined analysis consent (F11-T02) — same escape
  /// hatch `/result` offers today. Optional: a caller that has nowhere to
  /// send the user falls back to [onRetake] instead of a dead button.
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).surface,
      body: SafeArea(
        child: BlocBuilder<OcrReviewCubit, OcrReviewState>(
          builder: (context, state) => switch (state) {
            OcrReviewLoading() => _buildLoading(context),
            OcrReviewFailed(:final failure) => _buildFailed(context, failure),
            OcrReviewPoorQuality(:final imagePath) => _buildPoorQuality(
              context,
              imagePath,
            ),
            OcrReviewReady() => _ReadyBody(
              state: state,
              onAnalyze: onAnalyze,
              onRetake: onRetake,
              onPickAnother: onPickAnother,
            ),
          },
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    final strings = context.strings;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.of(context).brandPrimary),
          const SizedBox(height: AppSpacing.lg),
          Text(
            strings.ocrOnlineLoading,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.of(context).textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailed(BuildContext context, AppFailure failure) {
    final strings = context.strings;
    final isConsentDeclined = failure is AnalysisConsentDeclinedFailure;

    return _FailureView(
      icon: isConsentDeclined
          ? Icons.privacy_tip_outlined
          : Icons.error_outline,
      title: isConsentDeclined
          ? strings.analysisConsentDeclinedTitle
          : strings.ocrErrorTitle,
      message: isConsentDeclined
          ? strings.analysisConsentDeclinedMessage
          : strings.ocrErrorMessage,
      primaryLabel: isConsentDeclined && onOpenSettings != null
          ? strings.analysisConsentDeclinedOpenSettings
          : strings.ocrRetake,
      onPrimary: isConsentDeclined && onOpenSettings != null
          ? onOpenSettings!
          : onRetake,
      // A declined consent fails identically on any retry — offering a
      // second way out of the same wall only confuses the one way that
      // actually works (Settings).
      secondaryLabel: isConsentDeclined ? null : strings.ocrPickAnother,
      onSecondary: isConsentDeclined ? null : onPickAnother,
    );
  }

  Widget _buildPoorQuality(BuildContext context, String? imagePath) {
    final strings = context.strings;
    return _FailureView(
      icon: Icons.text_snippet_outlined,
      title: strings.ocrNoTextTitle,
      message: strings.ocrOnlinePoorQuality,
      primaryLabel: strings.ocrRetake,
      onPrimary: onRetake,
      secondaryLabel: strings.ocrPickAnother,
      onSecondary: onPickAnother,
    );
  }
}

/// Icon + title + message + up to two actions — the same shape
/// `OcrProcessingScreen._buildFailureView` uses for its offline counterpart.
class _FailureView extends StatelessWidget {
  const _FailureView({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: colors.textMuted),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: TextStyle(fontSize: 15, color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxxl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPrimary,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.brandPrimary,
                  foregroundColor: colors.onBrand,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
                child: Text(primaryLabel),
              ),
            ),
            if (secondaryLabel case final label?) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onSecondary,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.brandPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: colors.brandPrimary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  child: Text(label),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The review content once OCR succeeded. Its own [StatefulWidget] so the
/// text field's [TextEditingController] survives the rebuilds `BlocBuilder`
/// triggers on every keystroke (cubit state ← controller, never the other
/// way once seeded — see [_ReadyBodyState.initState]).
class _ReadyBody extends StatefulWidget {
  const _ReadyBody({
    required this.state,
    required this.onAnalyze,
    required this.onRetake,
    required this.onPickAnother,
  });

  final OcrReviewReady state;
  final VoidCallback onAnalyze;
  final VoidCallback onRetake;
  final VoidCallback onPickAnother;

  @override
  State<_ReadyBody> createState() => _ReadyBodyState();
}

class _ReadyBodyState extends State<_ReadyBody> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.state.reviewedOcrText,
  );

  /// Collapsed by default (F14 locked correction #5) to keep the screen
  /// focused on the text; the user opts in to compare against the photo.
  bool _showImage = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = AppColors.of(context);
    final state = widget.state;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.ocrOnlineReviewTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      strings.ocrOnlineReviewSubtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _copyText(context, state.reviewedOcrText),
                icon: Icon(Icons.copy, color: colors.brandPrimary),
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
                if (state.imagePath case final imagePath?)
                  _ImageToggle(
                    imagePath: imagePath,
                    expanded: _showImage,
                    onToggle: () => setState(() => _showImage = !_showImage),
                  ),
                if (state.imagePath != null)
                  const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: colors.borderSoft),
                  ),
                  child: TextField(
                    controller: _controller,
                    onChanged: (text) =>
                        context.read<OcrReviewCubit>().updateOcrText(text),
                    maxLines: null,
                    minLines: 6,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: colors.textBody,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (state.serverCandidates.totalCandidates > 0) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  CandidateChips(result: state.serverCandidates),
                ],
                if (state.serverCandidates.hasAmbiguousCandidates) ...[
                  const SizedBox(height: AppSpacing.md),
                  _AmbiguityNotice(text: strings.ocrOnlineAmbiguityNotice),
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
              onPressed: widget.onAnalyze,
              style: FilledButton.styleFrom(
                backgroundColor: colors.brandPrimary,
                foregroundColor: colors.onBrand,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
              ),
              child: Text(strings.ocrOnlineAnalyze),
            ),
          ),
        ),
      ],
    );
  }

  void _copyText(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.strings.ocrTextCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Collapsible section that shows the perspective-corrected photo, so the
/// user can compare it against the text without leaving the screen.
class _ImageToggle extends StatelessWidget {
  const _ImageToggle({
    required this.imagePath,
    required this.expanded,
    required this.onToggle,
  });

  final String imagePath;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 18,
                  color: colors.brandPrimary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    expanded
                        ? strings.ocrOnlineHideImage
                        : strings.ocrOnlineShowImage,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.brandPrimary,
                    ),
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: colors.brandPrimary,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Image.file(
              File(imagePath),
              fit: BoxFit.contain,
              errorBuilder: (context, _, _) => const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }
}

/// The amber notice below the candidate chips when any of them is ambiguous
/// — an inline hint rather than an auto-opened sheet (F14 locked correction
/// #6): the user keeps control of when to dig into field-level review.
class _AmbiguityNotice extends StatelessWidget {
  const _AmbiguityNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.warningTint,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: colors.warningInk),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: colors.warningInk),
            ),
          ),
        ],
      ),
    );
  }
}
