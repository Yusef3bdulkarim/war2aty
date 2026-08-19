import 'package:flutter/material.dart';

import '../audio/reading_speed.dart';
import '../documents/reading_mode.dart';
import '../documents/reading_mode_label.dart';
import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';

// From `Waraqti.dc.html` → the «الاستماع للورقة» sheet.
const double _sheetRadius = 26;
const double _sheetPaddingTop = 12;
const double _sheetPaddingH = 22;
const double _sheetPaddingBottom = 30;
const double _sheetMaxHeightFactor = 0.88;
const double _grabberWidth = 40;
const double _grabberHeight = 5;
const double _grabberGapBelow = 18;
const double _titleFontSize = 19;
const double _titleGapBelow = 14;
const double _optionRadius = 13;
const double _optionBorderWidth = 2;
const double _optionPaddingH = 15;
const double _optionPaddingV = 14;
const double _optionGap = 9;
const double _optionsGapBelow = 18;
const double _optionFontSize = 15;
const double _transportGap = 20;
const double _skipSize = 46;
const double _skipIconSize = 22;
const double _playSize = 70;
const double _playIconSize = 30;
const double _speedRowGapAbove = 16;
const double _speedLabelFontSize = 13;
const double _speedLabelGap = 8;
const double _speedPillGap = 6;
const double _speedPillFontSize = 13;
const double _speedPillPaddingH = 12;
const double _speedPillPaddingV = 6;

/// The modes this sheet offers, in display order. [ReadingMode.extractedText]
/// is not among them: it has no analysis to summarise, and is only reached by
/// reading a fallback screen's text straight away.
const List<ReadingMode> _offeredModes = [
  ReadingMode.summaryOnly,
  ReadingMode.summaryAndKeyInformation,
  ReadingMode.fullExplanation,
];

/// What the sheet answers with once the user taps the play control: both the
/// [ReadingMode] and the [ReadingSpeed] (F10-T06) chosen alongside it — one
/// choice, since both are confirmed by the same tap.
typedef AudioReadingChoice = ({ReadingMode mode, ReadingSpeed speed});

/// Asks which of the paper to read and how fast, and answers with both once
/// the user taps the play control — or with `null` if the sheet was
/// dismissed without choosing: either way nothing starts speaking from this
/// call alone.
///
/// [initialMode] highlights whichever mode is already reading (reopened from
/// the mini-player's «خيارات»), or the first mode the first time this is
/// opened for a paper. [initialSpeed] does the same for the speed row.
Future<AudioReadingChoice?> showAudioOptionsSheet(
  BuildContext context, {
  required ReadingMode initialMode,
  required ReadingSpeed initialSpeed,
}) => showModalBottomSheet<AudioReadingChoice>(
  context: context,
  backgroundColor: AppColors.light.card,
  isScrollControlled: true,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * _sheetMaxHeightFactor,
  ),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
  ),
  builder: (_) =>
      AudioOptionsSheet(initialMode: initialMode, initialSpeed: initialSpeed),
);

/// The body of that sheet: a three-way choice of [ReadingMode], a four-way
/// choice of [ReadingSpeed] (F10-T06), and a play control that confirms
/// whichever of each is picked.
///
/// The rewind/forward controls flanking play are drawn to match the design
/// but stay disabled — nothing in F10 yet seeks within a reading, so a
/// working button here would promise something the app cannot do.
///
/// Lives in `core/` rather than the `audio_reader` feature because the result
/// page (owned by the `analysis` feature) opens it directly, and a feature
/// screen never imports another feature — the same reason `SaveModeSheet`'s
/// sibling `DateSelectionSheet` sits here instead of in `reminders`.
class AudioOptionsSheet extends StatefulWidget {
  const AudioOptionsSheet({
    required this.initialMode,
    required this.initialSpeed,
    super.key,
  });

  final ReadingMode initialMode;
  final ReadingSpeed initialSpeed;

  @override
  State<AudioOptionsSheet> createState() => _AudioOptionsSheetState();
}

class _AudioOptionsSheetState extends State<AudioOptionsSheet> {
  // Local UI state: which mode/speed are highlighted before the user
  // confirms.
  late ReadingMode _mode;
  late ReadingSpeed _speed;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _speed = widget.initialSpeed;
  }

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;
    final strings = context.strings;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          _sheetPaddingH,
          _sheetPaddingTop,
          _sheetPaddingH,
          _sheetPaddingBottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: _grabberWidth,
                height: _grabberHeight,
                margin: const EdgeInsets.only(bottom: _grabberGapBelow),
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
            Semantics(
              header: true,
              child: Text(
                strings.audioReaderSheetTitle,
                style: AppTypography.titleLarge.copyWith(
                  fontSize: _titleFontSize,
                  fontWeight: AppTypography.extraBold,
                  color: colors.ink,
                ),
              ),
            ),
            const SizedBox(height: _titleGapBelow),
            for (final (index, mode) in _offeredModes.indexed) ...[
              if (index > 0) const SizedBox(height: _optionGap),
              _ModeOption(
                label: readingModeLabel(strings, mode),
                selected: _mode == mode,
                onTap: () => setState(() => _mode = mode),
              ),
            ],
            const SizedBox(height: _optionsGapBelow),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _SkipButton(icon: Icons.fast_rewind_rounded),
                const SizedBox(width: _transportGap),
                _PlayButton(
                  label: strings.audioReaderStartLabel,
                  onPressed: () =>
                      Navigator.of(context).pop((mode: _mode, speed: _speed)),
                ),
                const SizedBox(width: _transportGap),
                const _SkipButton(icon: Icons.fast_forward_rounded),
              ],
            ),
            const SizedBox(height: _speedRowGapAbove),
            _SpeedRow(
              label: strings.audioReaderSpeedLabel,
              selected: _speed,
              onSelected: (speed) => setState(() => _speed = speed),
            ),
          ],
        ),
      ),
    );
  }
}

/// The speed row (F10-T06): a muted label followed by the four
/// [ReadingSpeed] pills, matching the design's own centred layout.
class _SpeedRow extends StatelessWidget {
  const _SpeedRow({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final ReadingSpeed selected;
  final ValueChanged<ReadingSpeed> onSelected;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: _speedLabelFontSize,
            fontWeight: AppTypography.semiBold,
            color: colors.textMuted,
          ),
        ),
        const SizedBox(width: _speedLabelGap),
        for (final (index, speed) in ReadingSpeed.values.indexed) ...[
          if (index > 0) const SizedBox(width: _speedPillGap),
          _SpeedPill(
            speed: speed,
            selected: speed == selected,
            onTap: () => onSelected(speed),
          ),
        ],
      ],
    );
  }
}

/// One choosable [ReadingSpeed].
class _SpeedPill extends StatelessWidget {
  const _SpeedPill({
    required this.speed,
    required this.selected,
    required this.onTap,
  });

  final ReadingSpeed speed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    // Selection is otherwise conveyed only by fill color — invisible to a
    // screen reader without this (F12-T01).
    return Semantics(
      button: true,
      selected: selected,
      label: speed.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.brandPrimary : colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _speedPillPaddingH,
              vertical: _speedPillPaddingV,
            ),
            child: Text(
              speed.label,
              style: AppTypography.caption.copyWith(
                fontSize: _speedPillFontSize,
                fontWeight: AppTypography.bold,
                color: selected ? colors.onBrand : colors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One choosable reading mode.
class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    // Selection is otherwise conveyed only by fill/border color — invisible
    // to a screen reader without this (F12-T01).
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.surfaceTeal : colors.card,
        borderRadius: BorderRadius.circular(_optionRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(_optionRadius),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? colors.brandPrimary : colors.borderSoft,
                width: _optionBorderWidth,
              ),
              borderRadius: BorderRadius.circular(_optionRadius),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: _optionPaddingH,
              vertical: _optionPaddingV,
            ),
            child: Text(
              label,
              style: AppTypography.labelCard.copyWith(
                fontSize: _optionFontSize,
                fontWeight: AppTypography.bold,
                color: colors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The disabled rewind/forward controls flanking [_PlayButton].
class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    // Excluded from semantics (F12-T01): a permanently disabled control has
    // no label to give it — the same "nothing to announce" call
    // `camera_permission_sheet.dart`'s dismiss scrim makes — rather than a
    // screen reader finding an unlabeled, un-actionable "button".
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: _skipSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.surface,
          ),
          // Disabled rather than left out: the design keeps its place in the
          // row, and a greyed-out control says "not yet" more honestly than
          // an active one that would do nothing.
          child: IconButton(
            onPressed: null,
            padding: EdgeInsets.zero,
            icon: Icon(icon, size: _skipIconSize, color: colors.textBody),
          ),
        ),
      ),
    );
  }
}

/// The large central control that confirms the chosen mode and starts
/// reading it.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return SizedBox.square(
      dimension: _playSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.brandPrimary,
          boxShadow: [
            BoxShadow(
              color: colors.brandPrimary.withValues(alpha: 0.32),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          tooltip: label,
          icon: Icon(
            Icons.play_arrow_rounded,
            size: _playIconSize,
            color: colors.onBrand,
          ),
        ),
      ),
    );
  }
}
