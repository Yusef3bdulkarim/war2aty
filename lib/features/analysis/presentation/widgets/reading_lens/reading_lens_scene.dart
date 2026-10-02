import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../../../../core/theme/app_colors.dart';
import 'lens_timeline.dart';
import 'paper_layout.dart';
import 'reading_lens_painter.dart';
import 'scene_frame.dart';
import 'stack_raster.dart';

/// The magnifier reading the paper (F22 #18, the approved C+ design).
///
/// One [Ticker] drives it: each tick works out a [SceneFrame] from the time
/// since the page appeared and hands it to the painter, which repaints
/// without any widget rebuilding. Under reduced motion there is no ticker at
/// all — the lens rests over the title (F22 #12).
///
/// Set [finishing] once the analysis has answered: the lens fades as it
/// reads on, and the check springs in. [onCheckShown] fires once, as the check appears (the
/// caller's haptic, F22 #11); [onFinished] fires once, when the finish beat is
/// over (F22 #10). Removing the scene stops everything and fires neither.
class ReadingLensScene extends StatefulWidget {
  const ReadingLensScene({
    this.finishing = false,
    this.onCheckShown,
    this.onFinished,
    super.key,
  });

  final bool finishing;
  final VoidCallback? onCheckShown;
  final VoidCallback? onFinished;

  @override
  State<ReadingLensScene> createState() => _ReadingLensSceneState();
}

class _ReadingLensSceneState extends State<ReadingLensScene>
    with SingleTickerProviderStateMixin {
  /// Created only when the lens moves: under reduced motion there is none.
  Ticker? _ticker;
  final ValueNotifier<SceneFrame> _scene = ValueNotifier(SceneFrame.reading(0));

  /// The sheet stack, rendered once for the scene's life (F22-T13).
  final StackRaster _stack = StackRaster();

  bool _started = false;
  bool _still = false;

  /// Seconds since the first tick.
  double _now = 0;

  /// When the result arrived, on the same clock; null while waiting.
  double? _finishedAt;

  bool _checkShown = false;
  bool _finishReported = false;
  Timer? _stillHold;

  /// The last beat of the finish (the check's ring) ends here; the ticker
  /// stops then, in case the caller keeps the scene on screen.
  static final double _finishEnd = _seconds(LensTimeline.finishRing);

  static double _seconds(Duration d) => d.inMicroseconds / 1e6;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Once: this runs again whenever an ancestor changes (e.g. text size).
    if (_started) return;
    _started = true;
    _still = MediaQuery.disableAnimationsOf(context);

    if (_still) {
      _scene.value = SceneFrame.resting;
      if (widget.finishing) _finishStill();
      return;
    }
    if (widget.finishing) _finishedAt = 0;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(ReadingLensScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.finishing || oldWidget.finishing) return;
    if (_still) {
      _finishStill();
    } else {
      _finishedAt = _now;
    }
  }

  void _onTick(Duration elapsed) {
    _now = _seconds(elapsed);
    final finishedAt = _finishedAt;
    if (finishedAt == null) {
      _scene.value = SceneFrame.reading(_now);
      return;
    }

    _scene.value = SceneFrame.finishing(_now, finishedAt: finishedAt);
    final since = _now - finishedAt;
    // The check springs in at once (F22 #18), and the haptic with it.
    if (!_checkShown) {
      _checkShown = true;
      widget.onCheckShown?.call();
    }
    if (!_finishReported && since >= _seconds(LensTimeline.finishBeat)) {
      _finishReported = true;
      widget.onFinished?.call();
    }
    if (since >= _finishEnd) _ticker?.stop();
  }

  /// Reduced motion: the check at once, still; the result after a short hold
  /// so the moment can be noticed at all.
  void _finishStill() {
    _scene.value = SceneFrame.restingFinished;
    // After this frame: both callbacks may rebuild the caller, which must not
    // happen while it is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _checkShown) return;
      _checkShown = true;
      widget.onCheckShown?.call();
    });
    _stillHold = Timer(LensTimeline.reducedMotionHold, () {
      if (!mounted || _finishReported) return;
      _finishReported = true;
      widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _stillHold?.cancel();
    _ticker?.dispose();
    _scene.dispose();
    _stack.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: PaperLayout.size.width),
      child: AspectRatio(
        aspectRatio: PaperLayout.size.aspectRatio,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: ReadingLensPainter(
              scene: _scene,
              colors: AppColors.of(context),
              stack: _stack,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            ),
          ),
        ),
      ),
    );
  }
}
