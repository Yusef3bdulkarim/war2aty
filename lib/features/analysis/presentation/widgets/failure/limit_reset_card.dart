import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radii.dart';
import '../../../../../core/theme/app_typography.dart';

const double _radius = 22;
const double _paddingH = 18;
const double _paddingV = 20;
const double _gap = 10;
const double _labelFontSize = 14;
const double _timeFontSize = 30;
const double _timeHeight = 1.3;
const double _subFontSize = 13;
const double _pillTop = 6;
const double _pillPaddingH = 14;
const double _pillPaddingV = 8;
const double _dot = 12;
const double _dotGap = 6;
const double _pillGap = 10;
const double _pillFontSize = 13.5;

/// Above this many analyses a day, the pill says the number without dots.
const int _maxDots = 10;

/// The daily-limit page's countdown (F23 #7, #15): how long until the
/// analyses renew at Cairo midnight, and — when the limit is known — how
/// many were used.
///
/// The text refreshes exactly when its minute changes. Minutes round up, so
/// it never reads zero while time is left; at or past [resetAt] it says the
/// analyses have renewed.
class LimitResetCard extends StatefulWidget {
  const LimitResetCard({
    required this.resetAt,
    this.dailyLimit,
    this.now = DateTime.now,
    super.key,
  });

  /// When the quota renews — the failure's own `resetAtCairo`.
  final DateTime resetAt;

  /// The daily limit, or `null` when it is not known (F23 #14): the pill is
  /// then left out.
  final int? dailyLimit;

  /// The clock. Injected so a test can move time.
  final DateTime Function() now;

  @override
  State<LimitResetCard> createState() => _LimitResetCardState();
}

class _LimitResetCardState extends State<LimitResetCard> {
  Timer? _tick;

  Duration get _left => widget.resetAt.difference(widget.now());

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  @override
  void didUpdateWidget(LimitResetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetAt != widget.resetAt) _scheduleTick();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Wakes up when the rounded-up minute next changes — not on a loose
  /// one-minute beat, which could show a stale minute for up to a minute.
  void _scheduleTick() {
    _tick?.cancel();
    final left = _left;
    if (left <= Duration.zero) return;
    const minute = Duration(minutes: 1);
    final intoMinute = Duration(
      microseconds: left.inMicroseconds % minute.inMicroseconds,
    );
    _tick = Timer(intoMinute == Duration.zero ? minute : intoMinute, () {
      if (!mounted) return;
      setState(_scheduleTick);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;
    final left = _left;
    final renewed = left <= Duration.zero;
    final limit = widget.dailyLimit;

    String countdown() {
      // Rounded up: «less than a minute» still reads as one minute.
      final minutes = (left.inSeconds + 59) ~/ 60;
      return strings.analysisLimitResetsIn(minutes ~/ 60, minutes % 60);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceTealAlt,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _paddingH,
          vertical: _paddingV,
        ),
        child: Column(
          children: [
            if (renewed)
              Text(
                strings.analysisLimitRenewed,
                textAlign: TextAlign.center,
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: AppTypography.extraBold,
                  color: colors.brandDeep,
                ),
              )
            else ...[
              Text(
                strings.analysisLimitResetsInLabel,
                textAlign: TextAlign.center,
                style: AppTypography.labelCard.copyWith(
                  fontSize: _labelFontSize,
                  fontWeight: AppTypography.bold,
                  color: colors.brandDeep,
                ),
              ),
              const SizedBox(height: _gap),
              Text(
                countdown(),
                textAlign: TextAlign.center,
                style: AppTypography.displayMedium.copyWith(
                  fontSize: _timeFontSize,
                  fontWeight: AppTypography.extraBold,
                  height: _timeHeight,
                  color: colors.brandDeep,
                ),
              ),
              const SizedBox(height: _gap),
              Text(
                strings.analysisLimitResetTime,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  fontSize: _subFontSize,
                  fontWeight: AppTypography.semiBold,
                  color: colors.textBody,
                ),
              ),
            ],
            if (limit != null) ...[
              const SizedBox(height: _gap + _pillTop),
              _UsagePill(limit: limit),
            ],
          ],
        ),
      ),
    );
  }
}

/// «استخدمت 3 من 3 النهارده», with one dot per analysis when they fit.
class _UsagePill extends StatelessWidget {
  const _UsagePill({required this.limit});

  final int limit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _pillPaddingH,
          vertical: _pillPaddingV,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (limit > 0 && limit <= _maxDots) ...[
              // Decoration: the words say the same.
              ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < limit; i++) ...[
                      if (i > 0) const SizedBox(width: _dotGap),
                      Container(
                        key: ValueKey('usage-dot-$i'),
                        width: _dot,
                        height: _dot,
                        decoration: BoxDecoration(
                          color: colors.brandPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: _pillGap),
            ],
            Flexible(
              child: Text(
                context.strings.analysisLimitUsedOf(limit),
                textAlign: TextAlign.center,
                style: AppTypography.labelMedium.copyWith(
                  fontSize: _pillFontSize,
                  fontWeight: AppTypography.bold,
                  color: colors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
