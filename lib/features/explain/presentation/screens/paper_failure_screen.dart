import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/service_state_view.dart';
import '../../domain/entities/paper_failure_kind.dart';
import '../widgets/failure/analysis_steps_card.dart';
import '../widgets/failure/failure_tips_card.dart';
import '../widgets/failure/limit_reset_card.dart';

class PaperFailureScreen extends StatelessWidget {
  const PaperFailureScreen({
    required this.kind,
    required this.onRetry,
    required this.onHome,
    this.limitResetAt,
    this.dailyLimit,
    super.key,
  });

  final PaperFailureKind kind;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  final DateTime? limitResetAt;
  final int? dailyLimit;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = AppColors.of(context);
    final home = ServiceStateAction(
      label: strings.analysisBackToHome,
      onPressed: onHome,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) => onHome(),
      child: Scaffold(
        backgroundColor: colors.surface,
        body: ServiceStateView(
          onBack: onHome,
          title: switch (kind) {
            PaperFailureKind.offline => strings.analysisNoInternetTitle,
            PaperFailureKind.limitReached => strings.analysisLimitReachedTitle,
            PaperFailureKind.serviceProblem => strings.analysisFailedTitle,
          },
          message: switch (kind) {
            PaperFailureKind.offline => strings.paperOfflineMessage,
            PaperFailureKind.limitReached => switch (dailyLimit) {
              final limit? when limit > 0 =>
                strings.paperLimitReachedMessageWithLimit(limit),
              _ => strings.paperLimitReachedMessage,
            },
            PaperFailureKind.serviceProblem =>
              strings.paperServiceFailedMessage,
          },
          content: _content(kind, strings),
          primary: switch (kind) {
            PaperFailureKind.offline ||
            PaperFailureKind.serviceProblem => ServiceStateAction(
              label: strings.actionRetry,
              onPressed: onRetry,
            ),
            PaperFailureKind.limitReached => home,
          },
          tertiary: switch (kind) {
            PaperFailureKind.offline || PaperFailureKind.serviceProblem => home,
            PaperFailureKind.limitReached => null,
          },
        ),
      ),
    );
  }

  List<Widget> _content(PaperFailureKind kind, AppStrings strings) =>
      switch (kind) {
        PaperFailureKind.offline => [
          const AnalysisStepsCard(explanation: ExplanationStep.waiting),
          FailureTipsCard(
            title: strings.analysisNoInternetTipsTitle,
            tips: [
              FailureTip(
                glyph: StrokeGlyph.wifi,
                text: strings.analysisNoInternetTipWifi,
              ),
              FailureTip(
                glyph: StrokeGlyph.airplane,
                text: strings.analysisNoInternetTipAirplane,
              ),
              FailureTip(
                glyph: StrokeGlyph.signal,
                text: strings.analysisNoInternetTipSignal,
              ),
            ],
          ),
        ],
        PaperFailureKind.limitReached => [
          if (limitResetAt case final resetAt?)
            LimitResetCard(resetAt: resetAt, dailyLimit: dailyLimit),
          FailureTipsCard(
            title: strings.analysisLimitTipsTitle,
            tips: [
              FailureTip(
                glyph: StrokeGlyph.lightbulb,
                text: strings.analysisLimitTipTomorrow,
                tone: FailureTipTone.amber,
              ),
            ],
          ),
        ],
        PaperFailureKind.serviceProblem => [
          const AnalysisStepsCard(explanation: ExplanationStep.failed),
          FailureTipsCard(
            title: strings.analysisFailedTipsTitle,
            tips: [
              FailureTip(
                glyph: StrokeGlyph.clock,
                text: strings.analysisFailedTipWait,
              ),
              FailureTip(
                glyph: StrokeGlyph.wifi,
                text: strings.analysisFailedTipConnection,
              ),
            ],
          ),
        ],
      };
}
