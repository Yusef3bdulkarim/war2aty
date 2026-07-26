import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../cubit/home_state.dart';

// From `Waraqti.dc.html` → `home`, the `homeEmpty` block.
const double _gapAbove = 40;
const double _padding = 20;
const double _artWidth = 130;
const double _artHeight = 110;
const double _paperWidth = 78;
const double _paperHeight = 96;
const double _paperTilt = -7 * math.pi / 180;
const double _cameraTile = 62;
const double _titleGap = 18;

/// Shown when the user has nothing saved and nothing scheduled.
///
/// Sits *below* the scan actions rather than replacing them: the buttons are
/// the way out of this state, so they stay where they always are.
class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({
    required this.reminder,
    required this.documents,
    super.key,
  });

  final ReminderSection reminder;
  final DocumentsSection documents;

  /// Whether Home is genuinely empty.
  ///
  /// Requires both sections to have *answered* and answered empty. While
  /// either is loading the state is unknown, and claiming emptiness would
  /// flash the wrong message; if either failed to read, the app does not know
  /// enough to claim it either.
  static bool isVisible({
    required ReminderSection reminder,
    required DocumentsSection documents,
  }) {
    final noReminder = switch (reminder) {
      ReminderAvailable(:final reminder) => reminder == null,
      ReminderLoading() || ReminderUnavailable() => false,
    };
    final noDocuments = switch (documents) {
      DocumentsAvailable(:final documents) => documents.isEmpty,
      DocumentsLoading() || DocumentsUnavailable() => false,
    };

    return noReminder && noDocuments;
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible(reminder: reminder, documents: documents)) {
      return const SizedBox.shrink();
    }

    final s = context.strings;
    const colors = AppColors.light;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _padding,
        _gapAbove + _padding,
        _padding,
        _padding,
      ),
      child: Column(
        children: [
          const _EmptyArt(),
          const SizedBox(height: _titleGap),
          Text(
            s.homeEmptyTitle,
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(
              fontSize: 17,
              color: colors.textBody,
            ),
          ),
        ],
      ),
    );
  }
}

/// A tilted blank page with a camera tile resting on it.
///
/// Laid out with plain [Positioned] rather than the directional variant: this
/// is a picture, not a line of content, so it keeps the same composition in
/// both languages — the same reasoning as the scan card's gradient.
class _EmptyArt extends StatelessWidget {
  const _EmptyArt();

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return ExcludeSemantics(
      child: SizedBox(
        width: _artWidth,
        height: _artHeight,
        child: Stack(
          children: [
            Positioned(
              left: 14,
              top: 8,
              child: Transform.rotate(
                angle: _paperTilt,
                child: Container(
                  width: _paperWidth,
                  height: _paperHeight,
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppShadows.paper,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 0,
              child: Container(
                width: _cameraTile,
                height: _cameraTile,
                decoration: BoxDecoration(
                  color: colors.brandPrimary,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D0E7C86),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: StrokeIcon(
                    StrokeGlyph.camera,
                    color: colors.onBrand,
                    size: 30,
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
