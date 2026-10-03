import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/camera_flash_mode.dart';
import '../capture_palette.dart';
import 'camera_flash_glyph.dart';

// From the approved F24 design (`docs/design/F24-camera-mockups.html`).
const double _tapTarget = 48;
const double _disc = 44;
const double _gap = 18;
const double _shutterOuter = 68;
const double _shutterInner = 54;

/// The glass capsule under the feed (F24): photos · shutter · flash.
///
/// On a phone without a flash the flash button is left out entirely, and the
/// capsule shifts by half the missing slot so the shutter stays dead centre —
/// a thumb that knows where the shutter is never has to look for it.
class CameraCapsule extends StatelessWidget {
  const CameraCapsule({
    required this.flashMode,
    required this.hasFlash,
    required this.shutterEnabled,
    required this.onShutter,
    required this.onFlash,
    required this.onPickFromPhone,
    super.key,
  });

  final CameraFlashMode flashMode;
  final bool hasFlash;

  /// Off mid-capture, so a second tap cannot fire a second shot.
  final bool shutterEnabled;
  final VoidCallback onShutter;
  final VoidCallback onFlash;
  final VoidCallback onPickFromPhone;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final colors = AppColors.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // Without the flash slot, the shutter sits half a slot off-centre towards
    // the end; move the capsule back by that much.
    const halfSlot = (_tapTarget + _gap) / 2;
    final shift = hasFlash ? 0.0 : (rtl ? halfSlot : -halfSlot);

    return Transform.translate(
      offset: Offset(shift, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Glass on the plain backdrop: nothing sits behind the capsule, so
          // a fill and a hairline give the look without a BackdropFilter.
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DiscButton(
                label: s.cameraPickFromPhone,
                onTap: onPickFromPhone,
                glyph: StrokeGlyph.gallery,
              ),
              const SizedBox(width: _gap),
              _Shutter(enabled: shutterEnabled, onTap: onShutter),
              if (hasFlash) ...[
                const SizedBox(width: _gap),
                _DiscButton(
                  key: const ValueKey('camera-flash-button'),
                  label: flashLabel(s, flashMode),
                  onTap: onFlash,
                  glyph: glyphFor(flashMode),
                  // "On" also fills mint, on top of its own icon shape.
                  fill: flashMode == CameraFlashMode.on ? colors.mint : null,
                  iconColor: flashMode == CameraFlashMode.on
                      ? colors.ink
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A 44 disc inside a 48 × 48 tap target.
class _DiscButton extends StatelessWidget {
  const _DiscButton({
    required this.label,
    required this.onTap,
    required this.glyph,
    this.fill,
    this.iconColor,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final StrokeGlyph glyph;
  final Color? fill;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: _tapTarget,
        child: Material(
          type: MaterialType.transparency,
          child: InkResponse(
            onTap: onTap,
            radius: _tapTarget / 2,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _disc,
                height: _disc,
                decoration: BoxDecoration(
                  color: fill ?? Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: StrokeIcon(
                    glyph,
                    color: iconColor ?? AppColors.of(context).onBrand,
                    size: 22,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The white shutter with its teal ring. Dimmed and inert mid-capture.
class _Shutter extends StatelessWidget {
  const _Shutter({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Semantics(
      button: true,
      enabled: enabled,
      label: context.strings.cameraShutterLabel,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.6,
          child: Container(
            width: _shutterOuter,
            height: _shutterOuter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.16),
                  spreadRadius: 6,
                ),
                BoxShadow(color: colors.brandPrimary, spreadRadius: 3),
              ],
            ),
            child: Center(
              child: Container(
                width: _shutterInner,
                height: _shutterInner,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: captureBackdrop, width: 2.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
