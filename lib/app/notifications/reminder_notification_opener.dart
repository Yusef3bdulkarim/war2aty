import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import 'reminder_notification_taps.dart';

/// Opens the reminder a notification tap asked for, once [router] can show
/// it (F25-T04) — on the first frame for the tap that launched the app,
/// straight away for one that arrives while it runs.
///
/// Sits above the router's navigator (in `MaterialApp.router`'s builder),
/// so it pushes through [router] itself rather than a `BuildContext` below
/// it.
class ReminderNotificationOpener extends StatefulWidget {
  const ReminderNotificationOpener({
    super.key,
    required this.taps,
    required this.router,
    required this.child,
    this.revealed,
  });

  final ReminderNotificationTaps taps;
  final GoRouter router;
  final Widget child;

  /// Whether the launch splash has finished fading off the app (F27-P01).
  /// A tap waits for it, so its page never slides in under the fade; `null`
  /// opens straight away.
  final ValueListenable<bool>? revealed;

  @override
  State<ReminderNotificationOpener> createState() =>
      _ReminderNotificationOpenerState();
}

class _ReminderNotificationOpenerState
    extends State<ReminderNotificationOpener> {
  @override
  void initState() {
    super.initState();
    widget.taps.addListener(_scheduleOpen);
    // The launch tap was stored before this widget existed.
    _scheduleOpen();
  }

  @override
  void didUpdateWidget(ReminderNotificationOpener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taps != widget.taps) {
      oldWidget.taps.removeListener(_scheduleOpen);
      widget.taps.addListener(_scheduleOpen);
    }
  }

  @override
  void dispose() {
    widget.taps.removeListener(_scheduleOpen);
    widget.revealed?.removeListener(_onRevealed);
    super.dispose();
  }

  /// Waiting for the launch reveal before opening anything.
  bool _awaitingReveal = false;

  void _onRevealed() {
    if (!(widget.revealed?.value ?? true)) return;
    widget.revealed?.removeListener(_onRevealed);
    _awaitingReveal = false;
    _scheduleOpen();
  }

  /// After the frame, so the router has built its first page — pushing
  /// before then would race its initial location. A frame is asked for too:
  /// a tap on an idle app would otherwise wait for something else to
  /// repaint. During launch, only once the splash is gone.
  void _scheduleOpen() {
    final revealed = widget.revealed;
    if (revealed != null && !revealed.value) {
      if (!_awaitingReveal) {
        _awaitingReveal = true;
        revealed.addListener(_onRevealed);
      }
      return;
    }
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (!mounted) return;
        final reminderId = widget.taps.take();
        if (reminderId == null) return;
        widget.router.push(AppRoutes.reminderDetailsWith(reminderId));
      })
      ..scheduleFrame();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
