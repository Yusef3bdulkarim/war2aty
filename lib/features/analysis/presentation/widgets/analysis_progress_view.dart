import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import 'reading_lens/reading_lens_scene.dart';
import 'reading_lens/wait_caption.dart';

// From the approved C+ mockup (F22 #18).
const double _pagePadding = 24;

/// Room either side of the paper for the lens and its handle, which reach
/// past its edges as it reads.
const double _sceneInset = 32;
const double _sceneToCaption = 48;

/// At most this share of the page's height goes to the drawing, so a short
/// screen under Large Text keeps room for the words (F22 #14).
const double _sceneHeightShare = 0.55;

/// The gap under the drawing, as a share of the page's height, up to
/// [_sceneToCaption].
const double _gapHeightShare = 0.06;

/// The full-bleed page shown while the analysis service is working: a
/// magnifying glass reads a drawn paper while the caption says what is being
/// looked for (F22 #18, the approved C+ design).
///
/// Fully passive — nothing to tap, nothing to cancel. The captions follow the
/// clock (the service reports no stages) and never claim something was
/// found. Nothing on the page is a completion figure.
///
/// Set [finishing] once the analysis has answered: the check springs in with
/// one light haptic, then [onFinished] fires so the caller can swap in the
/// result. Removing the page (an error, leaving the route) stops it and fires
/// nothing.
///
/// For assistive technology the page is passive too: it announces nothing
/// (owner's decision, F22 #19). It carries one label saying where the wait
/// stands, read only when someone swipes onto it, so the page is never
/// blank to a screen reader. The drawing and the rotating captions are not
/// read.
class AnalysisProgressView extends StatefulWidget {
  const AnalysisProgressView({
    this.finishing = false,
    this.onFinished,
    super.key,
  });

  final bool finishing;
  final VoidCallback? onFinished;

  @override
  State<AnalysisProgressView> createState() => _AnalysisProgressViewState();
}

/// Where the wait stands, for the page's label.
enum _Status { waiting, long, ready }

class _AnalysisProgressViewState extends State<AnalysisProgressView> {
  _Status _status = _Status.waiting;

  /// The result has arrived: one haptic (F22 #11).
  void _onCheckShown() {
    HapticFeedback.lightImpact();
    setState(() => _status = _Status.ready);
  }

  void _onLongWait() {
    if (_status == _Status.waiting) setState(() => _status = _Status.long);
  }

  String _words(_Status status) {
    final strings = context.strings;
    return switch (status) {
      _Status.waiting => strings.analysisRunningStatus,
      _Status.long => strings.analysisWaitLongAnnouncement,
      _Status.ready => strings.analysisWaitReadyAnnouncement,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.of(context).surface,
      child: SafeArea(
        child: Semantics(
          container: true,
          label: _words(_status),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxHeight;
              // Scrolls only when the words alone outgrow a short screen at
              // the largest text — never at ordinary sizes.
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: height),
                  child: Padding(
                    padding: const EdgeInsets.all(_pagePadding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: height * _sceneHeightShare,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: _sceneInset,
                            ),
                            child: Center(
                              child: ExcludeSemantics(
                                child: ReadingLensScene(
                                  finishing: widget.finishing,
                                  onCheckShown: _onCheckShown,
                                  onFinished: widget.onFinished,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: (height * _gapHeightShare).clamp(
                            0,
                            _sceneToCaption,
                          ),
                        ),
                        WaitCaption(
                          finished: widget.finishing,
                          onLongWait: _onLongWait,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
