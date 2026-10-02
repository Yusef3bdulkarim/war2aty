import 'package:flutter/material.dart';

import '../../../../../core/icons/stroke_icon.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';

const double _radius = 18;
const double _paddingH = 14;
const double _paddingV = 16;
const double _dot = 38;
const double _dotIconSize = 20;
const double _connectorHeight = 2;
const double _connectorInset = 4;
const double _innerGap = 6;
const double _labelFontSize = 13.5;
const double _stateFontSize = 12;

/// Where the explanation, the last of the three steps, stands.
enum ExplanationStep {
  /// It waits for the connection to come back (no internet).
  waiting,

  /// It was tried and did not finish (a service problem).
  failed,
}

/// «الصورة ✓ — قراية الكلام ✓ — الشرح …» (F23 #10): what is already done, so a
/// failure reads as one step short rather than as lost work.
///
/// Done steps carry a check on green, the explanation a clock or a warning on
/// amber — the icon and the words say it, never the colour alone. A screen
/// reader hears the three as one sentence.
class AnalysisStepsCard extends StatelessWidget {
  const AnalysisStepsCard({required this.explanation, super.key});

  final ExplanationStep explanation;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;
    final explanationState = switch (explanation) {
      ExplanationStep.waiting => strings.analysisStepWaitingForInternet,
      ExplanationStep.failed => strings.analysisStepNotFinished,
    };

    return Semantics(
      container: true,
      label: strings.analysisStepsSemantics(explanationState),
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(_radius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _paddingH,
              vertical: _paddingV,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Step(
                  label: strings.analysisStepPhoto,
                  state: strings.analysisStepDone,
                  done: true,
                  glyph: StrokeGlyph.check,
                ),
                _Connector(color: colors.success),
                _Step(
                  label: strings.analysisStepReading,
                  state: strings.analysisStepDone,
                  done: true,
                  glyph: StrokeGlyph.check,
                ),
                _Connector(color: colors.border),
                _Step(
                  label: strings.analysisStepExplanation,
                  state: explanationState,
                  done: false,
                  glyph: switch (explanation) {
                    ExplanationStep.waiting => StrokeGlyph.clock,
                    ExplanationStep.failed => StrokeGlyph.warningTriangle,
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The line between two steps, level with the dots' centres.
class _Connector extends StatelessWidget {
  const _Connector({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(
          top: (_dot - _connectorHeight) / 2,
          left: _connectorInset,
          right: _connectorInset,
        ),
        child: SizedBox(
          height: _connectorHeight,
          child: ColoredBox(color: color),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.state,
    required this.done,
    required this.glyph,
  });

  final String label;
  final String state;
  final bool done;
  final StrokeGlyph glyph;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ink = done ? colors.successInk : colors.warningInk;

    // Three steps share the row; the words wrap rather than crowd under
    // Large Text.
    return Expanded(
      flex: 3,
      child: Column(
        children: [
          Container(
            width: _dot,
            height: _dot,
            decoration: BoxDecoration(
              color: done ? colors.successTint : colors.warningTint,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: StrokeIcon(
                glyph,
                color: ink,
                size: _dotIconSize,
                strokeWidth: done ? 2.2 : 2,
              ),
            ),
          ),
          const SizedBox(height: _innerGap),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.labelCard.copyWith(
              fontSize: _labelFontSize,
              fontWeight: AppTypography.bold,
              color: colors.ink,
            ),
          ),
          Text(
            state,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              fontSize: _stateFontSize,
              fontWeight: AppTypography.semiBold,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}
