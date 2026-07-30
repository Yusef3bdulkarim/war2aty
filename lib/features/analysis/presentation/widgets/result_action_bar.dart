import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/analysis_date.dart';
import 'date_selection_sheet.dart';

// From `Waraqti.dc.html` → the result page's bottom action bar.
const double _paddingH = AppSpacing.screenHorizontal;
const double _paddingTop = 12;
const double _paddingBottom = 28;
const double _gap = 10;
const double _buttonHeight = 52;
const double _buttonRadius = 15;
const double _iconSize = 21;
const double _iconGapBelow = 2;
const double _labelFontSize = 14.5;

/// The reminder button is the widest: it is the one the design leads with.
const int _reminderFlex = 12;
const int _flex = 10;

/// The three things §4 says a user does with a result: listen to it, be
/// reminded about it, keep it.
///
/// A button appears only when there is somewhere for it to go — the reader
/// (F10), the reminder flow (F09) and the saved documents (F08) each arrive in
/// their own feature. The alternative would be shipping controls that do
/// nothing, which is worse than a shorter bar.
///
/// The bar itself disappears when none of the three is available, rather than
/// leaving an empty strip pinned to the bottom of the page.
class ResultActionBar extends StatelessWidget {
  const ResultActionBar({
    required this.dates,
    this.onListen,
    this.onCreateReminder,
    this.onSave,
    super.key,
  });

  /// The paper's dates, in the order the analysis reported them. The reminder
  /// action asks which one it is for before going anywhere (UX rule §5.8).
  final List<AnalysisDate> dates;

  final VoidCallback? onListen;
  final ValueChanged<AnalysisDate>? onCreateReminder;
  final VoidCallback? onSave;

  /// Whether a reminder can be started at all: somewhere to go, and a date to
  /// go there with.
  bool get _canRemind => onCreateReminder != null && dates.isNotEmpty;

  /// Whether the bar has anything to show.
  bool get _isEmpty => onListen == null && !_canRemind && onSave == null;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    if (_isEmpty) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.borderSoft)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            _paddingH,
            _paddingTop,
            _paddingH,
            _paddingBottom,
          ),
          child: Row(
            children: [
              if (onListen case final onListen?) ...[
                _BarButton(
                  flex: _flex,
                  glyph: StrokeGlyph.headphones,
                  label: strings.resultListen,
                  background: colors.surfaceTeal,
                  foreground: colors.brandPrimary,
                  onPressed: onListen,
                ),
                const SizedBox(width: _gap),
              ],
              if (_canRemind) ...[
                _BarButton(
                  flex: _reminderFlex,
                  glyph: StrokeGlyph.navReminders,
                  label: strings.resultCreateReminder,
                  background: colors.brandPrimary,
                  foreground: colors.onBrand,
                  onPressed: () => _startReminder(context),
                ),
                const SizedBox(width: _gap),
              ],
              if (onSave case final onSave?)
                _BarButton(
                  flex: _flex,
                  glyph: StrokeGlyph.save,
                  label: strings.resultSavePaper,
                  background: colors.surfaceTeal,
                  foreground: colors.brandPrimary,
                  onPressed: onSave,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startReminder(BuildContext context) async {
    final chosen = await chooseReminderDate(context, dates: dates);
    if (chosen != null) onCreateReminder!(chosen);
  }
}

/// One stacked icon-over-label button.
class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.flex,
    required this.glyph,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final int flex;
  final StrokeGlyph glyph;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: SizedBox(
        height: _buttonHeight,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_buttonRadius),
            ),
            textStyle: AppTypography.labelMedium.copyWith(
              fontSize: _labelFontSize,
              fontWeight: AppTypography.bold,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StrokeIcon(
                glyph,
                color: foreground,
                size: _iconSize,
                strokeWidth: 1.9,
              ),
              const SizedBox(height: _iconGapBelow),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
