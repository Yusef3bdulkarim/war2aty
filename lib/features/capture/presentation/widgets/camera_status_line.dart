import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/camera_flash_mode.dart';
import 'camera_flash_glyph.dart';

/// The line above the capsule (F24): the focus hint, or — for a moment after a
/// tap on the flash — the flash mode spelled out. One at a time, cross-faded.
///
/// The flash chip is visual only: the flash button already carries the mode
/// as its screen-reader label, so the chip is not read a second time. The
/// hint is read only while it shows.
class CameraStatusLine extends StatefulWidget {
  const CameraStatusLine({
    required this.hintVisible,
    required this.flashChip,
    super.key,
  });

  /// Whether the focus hint is showing.
  final bool hintVisible;

  /// The flash mode to spell out, or `null` when the chip is hidden.
  final CameraFlashMode? flashChip;

  @override
  State<CameraStatusLine> createState() => _CameraStatusLineState();
}

class _CameraStatusLineState extends State<CameraStatusLine> {
  static const Duration _fade = Duration(milliseconds: 350);

  /// The mode the chip shows. It outlives [CameraStatusLine.flashChip] by the
  /// fade, so the chip fades out with its words instead of vanishing.
  CameraFlashMode? _shown;

  @override
  void initState() {
    super.initState();
    _shown = widget.flashChip;
  }

  @override
  void didUpdateWidget(CameraStatusLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    final chip = widget.flashChip;
    if (chip != null) _shown = chip;
  }

  void _onChipFaded() {
    if (widget.flashChip == null && _shown != null) {
      setState(() => _shown = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chip = _shown;
    final colors = AppColors.of(context);
    final hintShows = widget.hintVisible && widget.flashChip == null;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 34),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ExcludeSemantics(
            excluding: !hintShows,
            child: AnimatedOpacity(
              opacity: hintShows ? 1 : 0,
              duration: _fade,
              child: _Pill(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: colors.mint,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(child: _PillText(context.strings.cameraFocusHint)),
                  ],
                ),
              ),
            ),
          ),
          ExcludeSemantics(
            child: AnimatedOpacity(
              opacity: widget.flashChip == null ? 0 : 1,
              duration: _fade,
              onEnd: _onChipFaded,
              child: chip == null
                  ? const SizedBox.shrink()
                  : _Pill(
                      color: chip == CameraFlashMode.on
                          ? colors.mint
                          : Colors.white.withValues(alpha: 0.1),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StrokeIcon(
                            glyphFor(chip),
                            color: chip == CameraFlashMode.on
                                ? colors.ink
                                : colors.onBrand,
                            size: 16,
                            strokeWidth: 2,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: _PillText(
                              flashLabel(context.strings, chip),
                              color: chip == CameraFlashMode.on
                                  ? colors.ink
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: child,
    );
  }
}

class _PillText extends StatelessWidget {
  const _PillText(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: AppTypography.caption.copyWith(
        fontSize: 13.5,
        fontWeight: AppTypography.semiBold,
        color: color ?? AppColors.of(context).onBrand,
      ),
    );
  }
}
