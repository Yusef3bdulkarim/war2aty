import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/audio/audio_reader_cubit.dart';
import '../../../../core/audio/audio_reader_state.dart';
import '../../../../core/audio/reading_speed.dart';
import '../../../../core/documents/reading_mode_label.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/audio_mini_player_bar.dart';
import '../cubit/ocr_review_cubit.dart';
import '../cubit/ocr_review_state.dart';

/// The unified OCR review screen: the stop between OCR (online or offline) and
/// Groq analysis. Shows the OCR text editable, candidate hints, an optional
/// image preview, and a listen button + mini-player for pre-analysis TTS.
///
/// When [OcrReviewReady.isOffline] is `true`, an amber banner warns that OCR
/// accuracy may be lower, and the bottom button reads "متابعة" instead of
/// "تحليل الورقة".
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

    return BlocListener<AudioReaderCubit, AudioReaderState>(
      listenWhen: (previous, current) => current is AudioReaderFailed,
      listener: (context, audioState) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(strings.audioReaderFailedFeedback)),
          );
      },
      child: Column(
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
                        state.isOffline
                            ? strings.ocrExtractedTextTitle
                            : strings.ocrOnlineReviewTitle,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                      if (!state.isOffline) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          strings.ocrOnlineReviewSubtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _startListening(context),
                  icon: Icon(Icons.volume_up, color: colors.brandPrimary),
                  tooltip: strings.ocrListenToText,
                ),
                IconButton(
                  onPressed: () => _copyText(context, state.reviewedOcrText),
                  icon: Icon(Icons.copy, color: colors.brandPrimary),
                  tooltip: strings.ocrCopyText,
                ),
              ],
            ),
          ),
          // Offline quality warning banner.
          if (state.isOffline)
            _OfflineWarning(text: strings.ocrOfflineQualityWarning),
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
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
          // Mini-player — scoped to its own BlocBuilder (CLAUDE.md §B8).
          _MiniPlayerSlot(onOptions: () => _showSpeedOptions(context)),
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
                child: Text(
                  state.isOffline
                      ? strings.ocrContinue
                      : strings.ocrOnlineAnalyze,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startListening(BuildContext context) async {
    final cubit = context.read<AudioReaderCubit>();
    // If already reading, just stop — a second tap is an implicit "stop".
    if (cubit.state is AudioReaderReading) {
      await cubit.stop();
      return;
    }
    final speed = await cubit.loadDefaultSpeed();
    if (!mounted) return;
    await cubit.startRaw(text: _controller.text, speed: speed);
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

  /// Opens a speed-only picker sheet so the user can change TTS pace without
  /// stopping the current reading — the review screen has only one reading
  /// mode ([ReadingMode.extractedText]), so the full [AudioOptionsSheet]'s
  /// mode picker would be misleading here.
  Future<void> _showSpeedOptions(BuildContext context) async {
    final cubit = context.read<AudioReaderCubit>();
    final current = cubit.state;
    if (current is! AudioReaderReading) return;

    final picked = await showModalBottomSheet<ReadingSpeed>(
      context: context,
      backgroundColor: AppColors.of(context).card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (_) => _SpeedPickerSheet(selected: current.speed),
    );

    if (picked == null || !mounted) return;
    await cubit.startRaw(text: _controller.text, speed: picked);
  }
}

/// Watches [AudioReaderCubit] on its own, scoped to just the mini-player —
/// avoids rebuilding the text field and the rest of the page on every
/// `TtsProgressed` tick (CLAUDE.md §B8).
class _MiniPlayerSlot extends StatelessWidget {
  const _MiniPlayerSlot({required this.onOptions});

  /// Called when the user taps the options button on the mini-player.
  /// On the review screen this restarts listening (no mode picker here).
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return BlocBuilder<AudioReaderCubit, AudioReaderState>(
      builder: (context, audioState) => switch (audioState) {
        AudioReaderReading(:final mode, :final isPaused, :final progress) =>
          AudioMiniPlayerBar(
            modeLabel: readingModeLabel(strings, mode),
            isPlaying: !isPaused,
            progress: progress,
            onTogglePlayPause: () {
              final cubit = context.read<AudioReaderCubit>();
              if (isPaused) {
                cubit.resume();
              } else {
                cubit.pause();
              }
            },
            onOptions: onOptions,
            onStop: () => context.read<AudioReaderCubit>().stop(),
          ),
        _ => const SizedBox.shrink(),
      },
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

/// Amber warning banner for the offline path — OCR quality may be lower
/// without internet access. Same amber styling as [_AmbiguityNotice].
class _OfflineWarning extends StatelessWidget {
  const _OfflineWarning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: Container(
        width: double.infinity,
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
            Icon(Icons.wifi_off, size: 16, color: colors.warningInk),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 13, color: colors.warningInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Speed-only picker sheet for the review screen's mini-player «خيارات».
///
/// The full [AudioOptionsSheet] offers reading-mode + speed, but the review
/// screen has exactly one mode ([ReadingMode.extractedText]), so only the
/// speed row is meaningful here. Visually matches the speed pills from
/// [AudioOptionsSheet] for consistency.
class _SpeedPickerSheet extends StatefulWidget {
  const _SpeedPickerSheet({required this.selected});

  final ReadingSpeed selected;

  @override
  State<_SpeedPickerSheet> createState() => _SpeedPickerSheetState();
}

class _SpeedPickerSheetState extends State<_SpeedPickerSheet> {
  late ReadingSpeed _speed = widget.selected;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = AppColors.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.md,
          AppSpacing.screenHorizontal,
          AppSpacing.xxxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              strings.audioReaderSpeedLabel,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (index, speed) in ReadingSpeed.values.indexed) ...[
                  if (index > 0) const SizedBox(width: 6),
                  Material(
                    color: speed == _speed
                        ? colors.brandPrimary
                        : colors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      onTap: () => setState(() => _speed = speed),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          speed.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: speed == _speed
                                ? colors.onBrand
                                : colors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_speed),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.brandPrimary,
                  foregroundColor: colors.onBrand,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
                child: Text(strings.audioReaderStartLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
