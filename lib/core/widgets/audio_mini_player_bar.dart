import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

// From `Waraqti.dc.html` → the result page's audio mini-player bar.
const double _paddingH = 16;
const double _paddingV = 11;
const double _rowGap = 12;
const double _toggleSize = 42;
const double _toggleIconSize = 20;
const double _stopSize = 34;
const double _stopIconSize = 18;
const double _labelFontSize = 13.5;
const double _trackHeight = 4;
const double _trackGapAbove = 6;
const double _optionsFontSize = 12.5;

/// The bar shown while the reader (F10) is reading the result aloud —
/// «بيقرأ: {mode}». Sits between the result page's scrollable content and its
/// action bar, never as a global overlay: the reading is scoped to the paper
/// currently on screen, the same way the design draws it.
///
/// Purely presentational — [isPlaying] and [progress] are handed in rather
/// than read from a TTS engine. `AudioReaderCubit` wires the real reading
/// behind [onOptions]/[onStop], real pause/resume behind
/// [onTogglePlayPause], and turns `TextToSpeechService.events` into
/// [progress] (F10-T04/T05/T08).
///
/// Lives in `core/` rather than the `audio_reader` feature because the result
/// page (owned by the `analysis` feature) renders it inline in its own
/// layout, and a feature screen never imports another feature directly —
/// the same reason `DateSelectionSheet` sits here instead of in `reminders`.
class AudioMiniPlayerBar extends StatelessWidget {
  const AudioMiniPlayerBar({
    required this.modeLabel,
    required this.isPlaying,
    required this.progress,
    required this.onTogglePlayPause,
    required this.onOptions,
    required this.onStop,
    super.key,
  });

  /// The reading mode's own label — e.g. «الخلاصة فقط» — shown after «بيقرأ:».
  final String modeLabel;

  /// Whether the icon shows "tap to pause" (true) or "tap to resume" (false).
  final bool isPlaying;

  /// How far through the reading, 0 to 1.
  final double progress;

  final VoidCallback onTogglePlayPause;

  /// Reopens the mode-picker sheet to change what is being read.
  final VoidCallback onOptions;

  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return ColoredBox(
      color: colors.brandDeep,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _paddingH,
          vertical: _paddingV,
        ),
        child: Row(
          children: [
            _ToggleButton(isPlaying: isPlaying, onPressed: onTogglePlayPause),
            const SizedBox(width: _rowGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    strings.audioReaderNowReading(modeLabel),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMedium.copyWith(
                      fontSize: _labelFontSize,
                      fontWeight: AppTypography.bold,
                      color: colors.onBrand,
                    ),
                  ),
                  const SizedBox(height: _trackGapAbove),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(_trackHeight / 2),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0).toDouble(),
                      minHeight: _trackHeight,
                      backgroundColor: colors.onBrand.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation(colors.mint),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: _rowGap),
            TextButton(
              onPressed: onOptions,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: colors.mintSoft,
                textStyle: AppTypography.labelMedium.copyWith(
                  fontSize: _optionsFontSize,
                  fontWeight: AppTypography.bold,
                ),
              ),
              child: Text(strings.audioReaderOptions),
            ),
            const SizedBox(width: _rowGap),
            SizedBox.square(
              dimension: _stopSize,
              child: IconButton(
                onPressed: onStop,
                padding: EdgeInsets.zero,
                tooltip: strings.audioReaderStopLabel,
                icon: Icon(
                  Icons.close,
                  size: _stopIconSize,
                  color: colors.onBrand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The circular play/pause control at the bar's leading edge.
class _ToggleButton extends StatelessWidget {
  const _ToggleButton({required this.isPlaying, required this.onPressed});

  final bool isPlaying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return SizedBox.square(
      dimension: _toggleSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.onBrand.withValues(alpha: 0.16),
        ),
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          tooltip: isPlaying
              ? strings.audioReaderPauseLabel
              : strings.audioReaderResumeLabel,
          icon: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: _toggleIconSize,
            color: colors.onBrand,
          ),
        ),
      ),
    );
  }
}
