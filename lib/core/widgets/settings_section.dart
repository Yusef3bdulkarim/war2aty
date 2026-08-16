import 'package:flutter/material.dart';

import '../icons/stroke_icon.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_typography.dart';

// From `Waraqti.dc.html` → the settings screen's card sections (`الخصوصية`
// and every section after it). One shared shape for all of them.
const double _titleFontSize = 13;
const double _titleGapBelow = 10;
const double _cardGapBelow = 22;
const double _rowPaddingH = 16;
const double _rowPaddingV = 15;
const double _rowGap = 12;
const double _rowIconSize = 20;
const double _rowLabelFontSize = 15;

/// A titled card of settings rows (F11-T02 onward) — «الخصوصية» and every
/// section that follows it on the settings screen.
///
/// Rows are separated by the design's hairline; the last one gets none, which
/// this draws automatically rather than asking every caller to remember it.
class SettingsSection extends StatelessWidget {
  const SettingsSection({required this.title, required this.rows, super.key});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: AppTypography.caption.copyWith(
                fontSize: _titleFontSize,
                fontWeight: AppTypography.extraBold,
                color: colors.textMuted,
              ),
            ),
          ),
        ),
        const SizedBox(height: _titleGapBelow),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            boxShadow: AppShadows.card,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: i == rows.length - 1
                          ? null
                          : Border(
                              bottom: BorderSide(color: colors.surfaceAlt),
                            ),
                    ),
                    child: rows[i],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: _cardGapBelow),
      ],
    );
  }
}

/// One row: a leading icon, a label, the current value as a subtitle, and a
/// trailing chevron. Tapping it opens a picker or navigates.
class SettingsValueRow extends StatelessWidget {
  const SettingsValueRow({
    required this.glyph,
    required this.label,
    required this.value,
    required this.onTap,
    this.description,
    super.key,
  });

  final StrokeGlyph glyph;
  final String label;

  /// The human-readable label of the current selection (e.g. «تحليل ذكي»).
  final String value;

  final VoidCallback? onTap;

  /// An optional explanatory line under [label], above [value] — e.g. «صوت
  /// القراءة»'s «الأصوات المتاحة حسب إعدادات الموبايل.» (F11-T07). Every
  /// other row has none.
  final String? description;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    // Material(transparency) provides the required Material ancestor
    // that InkWell checks at build time — the same approach
    // SettingsToggleRow uses for its Switch.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _rowPaddingH,
            vertical: _rowPaddingV,
          ),
          child: Row(
            children: [
              StrokeIcon(glyph, color: colors.brandPrimary, size: _rowIconSize),
              const SizedBox(width: _rowGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: _rowLabelFontSize,
                        fontWeight: AppTypography.semiBold,
                        color: colors.ink,
                      ),
                    ),
                    if (description case final description?) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: AppTypography.caption.copyWith(
                          fontSize: 13,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: AppTypography.caption.copyWith(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              StrokeIcon(
                StrokeGlyph.chevronForward,
                color: colors.textMuted,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row: a leading icon and a label styled as a link, with no trailing
/// value or chevron — a plain action, e.g. «تجربة الصوت» (F11-T07).
class SettingsActionRow extends StatelessWidget {
  const SettingsActionRow({
    required this.glyph,
    required this.label,
    required this.onTap,
    super.key,
  });

  final StrokeGlyph glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _rowPaddingH,
            vertical: _rowPaddingV,
          ),
          child: Row(
            children: [
              StrokeIcon(glyph, color: colors.brandPrimary, size: _rowIconSize),
              const SizedBox(width: _rowGap),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: _rowLabelFontSize,
                    fontWeight: AppTypography.semiBold,
                    color: colors.brandPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row: a leading icon, a label (with an optional supporting line), and a
/// trailing on/off switch.
class SettingsToggleRow extends StatelessWidget {
  const SettingsToggleRow({
    required this.glyph,
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final StrokeGlyph glyph;
  final String label;
  final bool value;

  /// `null` shows the row as disabled — read but not interactive.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _rowPaddingH,
        vertical: _rowPaddingV,
      ),
      child: Row(
        children: [
          StrokeIcon(glyph, color: colors.brandPrimary, size: _rowIconSize),
          const SizedBox(width: _rowGap),
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: _rowLabelFontSize,
                fontWeight: AppTypography.semiBold,
                color: colors.ink,
              ),
            ),
          ),
          // Material's own Switch, not a hand-drawn track: it mirrors
          // correctly for RTL/LTR and carries its own semantics for free,
          // which a pixel-exact custom track would have to reimplement.
          //
          // Material(transparency) provides the required Material ancestor
          // that Switch checks at build time — the screen itself lives
          // inside the shell's Scaffold, but that is outside a
          // LookupBoundary in some subtrees. SizedBox + FittedBox scale the
          // Switch to match the design's 44×26 pill (Transform.scale only
          // paints smaller, it doesn't shrink the layout box).
          Material(
            type: MaterialType.transparency,
            child: SizedBox(
              width: 44,
              height: 26,
              child: FittedBox(
                child: Switch(
                  value: value,
                  onChanged: onChanged,
                  activeTrackColor: colors.brandPrimary,
                  inactiveTrackColor: colors.switchTrackOff,
                  thumbColor: WidgetStateProperty.all(colors.card),
                  trackOutlineColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
