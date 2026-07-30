import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../capture_palette.dart';

// From `Waraqti.dc.html` → the `camPerm` sheet.
const double _sheetRadius = 26;
const double _sheetTop = 12;
const double _sheetSide = 24;
const double _sheetBottom = 34;
const double _handleWidth = 40;
const double _handleHeight = 5;
const double _iconBox = 64;
const double _iconRadius = 19;
const double _primaryHeight = 54;
const double _secondaryHeight = 52;
const double _tertiaryHeight = 46;
const double _buttonRadius = 15;

/// Explains why the app wants the camera, and offers a way forward without it.
///
/// Three actions, in the order the design puts them: allow, pick an existing
/// photo instead, or back out. The middle one matters — a user who will not
/// grant the camera is not stuck, they can still get a paper analysed.
class CameraPermissionSheet extends StatelessWidget {
  const CameraPermissionSheet({
    required this.isBlocked,
    required this.onAllow,
    required this.onPickInstead,
    required this.onDismiss,
    super.key,
  });

  /// Whether the OS has stopped prompting, which changes the message and the
  /// primary button from "allow" to "open settings".
  final bool isBlocked;

  final VoidCallback onAllow;
  final VoidCallback onPickInstead;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    const colors = AppColors.light;

    return Semantics(
      // The sheet is the whole point of this screen, so it is announced as a
      // dialog: assistive tech traps focus here rather than wandering into
      // the Home screen still visible behind the scrim.
      scopesRoute: true,
      explicitChildNodes: true,
      child: Material(
        // The scrim over the viewfinder backdrop the gate paints behind it.
        color: Color.alphaBlend(captureScrim, captureBackdrop),
        child: Stack(
          children: [
            // Tapping the scrim backs out, matching every other sheet in the
            // app. Excluded from semantics: assistive tech gets the explicit
            // "back" button below instead of an unlabelled full-screen target.
            Positioned.fill(
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDismiss,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(_sheetRadius),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    _sheetSide,
                    _sheetTop,
                    _sheetSide,
                    _sheetBottom,
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _GrabHandle(),
                        const SizedBox(height: 22),
                        const _CameraBadge(),
                        const SizedBox(height: 18),
                        Text(
                          s.cameraPermissionTitle,
                          style: AppTypography.headlineMedium.copyWith(
                            fontSize: 20,
                            fontWeight: AppTypography.extraBold,
                            color: colors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isBlocked
                              ? s.cameraPermissionBlockedMessage
                              : s.cameraPermissionMessage,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: AppTypography.medium,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _SheetButton(
                          label: isBlocked
                              ? s.cameraPermissionOpenSettings
                              : s.cameraPermissionAllow,
                          onPressed: onAllow,
                          background: colors.brandPrimary,
                          foreground: colors.onBrand,
                          height: _primaryHeight,
                          fontSize: 17,
                        ),
                        const SizedBox(height: 8),
                        _SheetButton(
                          label: s.cameraPermissionPickInstead,
                          onPressed: onPickInstead,
                          background: colors.surfaceTeal,
                          foreground: colors.brandPrimary,
                          height: _secondaryHeight,
                          fontSize: 16,
                        ),
                        const SizedBox(height: 4),
                        _SheetButton(
                          label: s.actionBack,
                          onPressed: onDismiss,
                          background: Colors.transparent,
                          foreground: colors.textMuted,
                          height: _tertiaryHeight,
                          fontSize: 15,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The short bar at the top of the sheet.
class _GrabHandle extends StatelessWidget {
  const _GrabHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: _handleWidth,
        height: _handleHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.light.border,
            borderRadius: const BorderRadius.all(Radius.circular(3)),
          ),
        ),
      ),
    );
  }
}

/// The teal-tinted camera tile above the heading.
class _CameraBadge extends StatelessWidget {
  const _CameraBadge();

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Container(
      width: _iconBox,
      height: _iconBox,
      decoration: BoxDecoration(
        color: colors.surfaceTealAlt,
        borderRadius: BorderRadius.circular(_iconRadius),
      ),
      child: Center(
        child: StrokeIcon(
          StrokeGlyph.camera,
          color: colors.brandPrimary,
          size: 32,
          strokeWidth: 1.7,
        ),
      ),
    );
  }
}

/// One full-width button in the sheet's stack.
///
/// The heights from the design are minimums, not fixed sizes, so a label still
/// fits when the user runs the phone at a large text scale.
class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.onPressed,
    required this.background,
    required this.foreground,
    required this.height,
    required this.fontSize,
  });

  final String label;
  final VoidCallback onPressed;
  final Color background;
  final Color foreground;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          minimumSize: Size.fromHeight(height),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_buttonRadius),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.labelLarge.copyWith(
            fontSize: fontSize,
            fontWeight: AppTypography.bold,
          ),
        ),
      ),
    );
  }
}
