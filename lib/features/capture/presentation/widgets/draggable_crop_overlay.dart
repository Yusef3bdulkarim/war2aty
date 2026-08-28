import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/unit_rect.dart';
import '../capture_palette.dart';

// ── Design constants (F15-T05 proposal) ──

/// Edge midpoint pill dimensions — large enough to be easy to spot and grab.
const double _edgePillLength = 40;
const double _edgePillThickness = 6;

/// Touch target for all handles — Material guidelines minimum.
const double _touchTarget = 48;

/// Crop border thickness.
const double _borderWidth = 2;

/// Minimum crop size in logical pixels, so the user can't shrink the
/// selection into an unusable sliver.
const double _minCropExtent = 60;

/// Scrim opacity over the excluded (outside-crop) area.
const double _scrimAlpha = 0.72;

/// Grid line opacity (rule-of-thirds grid inside the crop).
const double _gridAlpha = 0.15;

/// Which edge a handle controls.
enum _HandleType { top, bottom, left, right }

/// Free-form drag-crop overlay for the image preview screen (F15 locked
/// decision #5).
///
/// Replaces the static [CropFrame] brackets. Always active — no "enter crop
/// mode" toggle. Starts at [UnitRect.full] and the user drags the 4 crop edges
/// to refine the selection. Each edge is grabbable along its whole length, not
/// just at the pill that marks it, and drags on a single axis only. The pill
/// sits just inside the crop boundary so it never extends beyond the image
/// frame.
///
/// [cropRect] is a fraction of the **rendered [child]**, not of the space the
/// overlay was offered — the two differ whenever the child is letterboxed
/// inside that space (e.g. an `Image` with `BoxFit.contain`), which is the
/// normal case on the preview screen.
///
/// The widget manages its own local state during a drag gesture (for
/// frame-rate-smooth updates) and reports the final rect to [onCropChanged]
/// on drag end. The external [cropRect] is the authoritative value — when it
/// changes (e.g. cubit resets on rotate), the widget syncs to it.
class DraggableCropOverlay extends StatefulWidget {
  const DraggableCropOverlay({
    required this.cropRect,
    required this.onCropChanged,
    required this.enabled,
    required this.child,
    super.key,
  });

  /// The authoritative crop rect from the cubit.
  final UnitRect cropRect;

  /// Called on drag end with the updated crop rect.
  final ValueChanged<UnitRect>? onCropChanged;

  /// Whether handles are interactive. Disabled during processing.
  final bool enabled;

  /// The image to frame.
  final Widget child;

  @override
  State<DraggableCropOverlay> createState() => _DraggableCropOverlayState();
}

class _DraggableCropOverlayState extends State<DraggableCropOverlay> {
  /// The live crop rect, synced from [widget.cropRect] except during a drag.
  late UnitRect _rect = widget.cropRect;

  /// Whether a handle is actively being dragged.
  bool _dragging = false;

  @override
  void didUpdateWidget(DraggableCropOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync from the cubit when not mid-drag (e.g. rotate reset).
    if (!_dragging && widget.cropRect != _rect) {
      _rect = widget.cropRect;
    }
  }

  void _onDragStart() {
    _dragging = true;
  }

  void _onDragUpdate(_HandleType handle, Offset delta, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final dx = delta.dx / size.width;
    final dy = delta.dy / size.height;

    final minW = _minCropExtent / size.width;
    final minH = _minCropExtent / size.height;

    var left = _rect.left;
    var top = _rect.top;
    var right = _rect.right;
    var bottom = _rect.bottom;

    switch (handle) {
      case _HandleType.top:
        top = (top + dy).clamp(0.0, bottom - minH);
      case _HandleType.bottom:
        bottom = (bottom + dy).clamp(top + minH, 1.0);
      case _HandleType.left:
        left = (left + dx).clamp(0.0, right - minW);
      case _HandleType.right:
        right = (right + dx).clamp(left + minW, 1.0);
    }

    setState(() {
      _rect = UnitRect(left: left, top: top, right: right, bottom: bottom);
    });
  }

  void _onDragEnd() {
    _dragging = false;
    widget.onCropChanged?.call(_rect);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The image — the only non-positioned child, so it alone determines
        // the Stack's size. The crop rect is a fraction *of this box*.
        widget.child,
        // Scrim + border + grid.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _CropPainter(
                rect: _rect,
                mint: AppColors.of(context).mint,
              ),
            ),
          ),
        ),
        if (widget.enabled)
          // Interactive edge handles (single-axis drag).
          //
          // The size they are placed and dragged against must be the rendered
          // image box, not the space offered to it: under `BoxFit.contain` the
          // image is letterboxed inside the offered box, so measuring the
          // incoming constraints would put the handles somewhere off the image
          // (and scale drag deltas by the wrong factor). `Positioned.fill`
          // resolves to the Stack's real size and passes it down as tight
          // constraints, so this `LayoutBuilder` reads exactly the box the
          // painter above paints into.
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                // Degenerate while the image decodes — placing handles now
                // would pile all four in the corner until it lands.
                if (size.isEmpty) return const SizedBox.shrink();
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final type in _HandleType.values)
                      _buildEdgeHandle(type, size, context),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  /// Positions one interactive crop edge with a [GestureDetector].
  ///
  /// The touch band spans the edge's whole length — the crop border itself is
  /// what the user grabs, and the pill only marks where it is. It is shortened
  /// by half a touch target at each end so the two perpendicular edges don't
  /// compete for the corners, with a floor so the band never shrinks below the
  /// pill it has to hold at the minimum crop size.
  ///
  /// Across the edge, the anchor is offset inward by half the pill thickness so
  /// that a plain [Center] places the pill with its near edge flush on the crop
  /// border — deterministically, with no fractional-alignment math that can
  /// drift between overlay sizes.
  Widget _buildEdgeHandle(
    _HandleType type,
    Size overlaySize,
    BuildContext context,
  ) {
    final r = _rect;
    final w = overlaySize.width;
    final h = overlaySize.height;

    // Half the pill thickness — used to nudge the anchor inward so the
    // centered pill's near edge lands exactly on the crop border.
    const inset = _edgePillThickness / 2;

    final left = r.left * w;
    final top = r.top * h;
    final right = r.right * w;
    final bottom = r.bottom * h;

    final (anchorX, anchorY) = switch (type) {
      _HandleType.top => ((left + right) / 2, top + inset),
      _HandleType.bottom => ((left + right) / 2, bottom - inset),
      _HandleType.left => (left + inset, (top + bottom) / 2),
      _HandleType.right => (right - inset, (top + bottom) / 2),
    };

    final semanticLabel = switch (type) {
      _HandleType.top => 'مقبض القص أعلى',
      _HandleType.bottom => 'مقبض القص أسفل',
      _HandleType.left => 'مقبض القص يسار',
      _HandleType.right => 'مقبض القص يمين',
    };

    final isHorizontal = type == _HandleType.top || type == _HandleType.bottom;

    final bandLength = math.max(
      (isHorizontal ? right - left : bottom - top) - _touchTarget,
      _edgePillLength,
    );

    return Positioned(
      left: anchorX - (isHorizontal ? bandLength : _touchTarget) / 2,
      top: anchorY - (isHorizontal ? _touchTarget : bandLength) / 2,
      width: isHorizontal ? bandLength : _touchTarget,
      height: isHorizontal ? _touchTarget : bandLength,
      child: Semantics(
        label: semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => _onDragStart(),
          onPanUpdate: (d) => _onDragUpdate(type, d.delta, overlaySize),
          onPanEnd: (_) => _onDragEnd(),
          onPanCancel: _onDragEnd,
          child: Center(
            child: SizedBox(
              width: isHorizontal ? _edgePillLength : _edgePillThickness,
              height: isHorizontal ? _edgePillThickness : _edgePillLength,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.of(context).mint,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the scrim, crop border, and rule-of-thirds grid.
class _CropPainter extends CustomPainter {
  _CropPainter({required this.rect, required this.mint});

  final UnitRect rect;
  final Color mint;

  @override
  void paint(Canvas canvas, Size size) {
    final cropRect = Rect.fromLTRB(
      rect.left * size.width,
      rect.top * size.height,
      rect.right * size.width,
      rect.bottom * size.height,
    );

    // ── Scrim (outside the crop) ──
    if (!rect.isFull) {
      final scrimPaint = Paint()
        ..color = captureBackdrop.withValues(alpha: _scrimAlpha);
      // Top strip.
      canvas.drawRect(
        Rect.fromLTRB(0, 0, size.width, cropRect.top),
        scrimPaint,
      );
      // Bottom strip.
      canvas.drawRect(
        Rect.fromLTRB(0, cropRect.bottom, size.width, size.height),
        scrimPaint,
      );
      // Left strip (between top and bottom).
      canvas.drawRect(
        Rect.fromLTRB(0, cropRect.top, cropRect.left, cropRect.bottom),
        scrimPaint,
      );
      // Right strip (between top and bottom).
      canvas.drawRect(
        Rect.fromLTRB(
          cropRect.right,
          cropRect.top,
          size.width,
          cropRect.bottom,
        ),
        scrimPaint,
      );
    }

    // ── Crop border ──
    final borderPaint = Paint()
      ..color = mint
      ..style = PaintingStyle.stroke
      ..strokeWidth = _borderWidth;
    canvas.drawRect(cropRect.deflate(_borderWidth / 2), borderPaint);

    // ── Rule-of-thirds grid (only when cropped) ──
    if (!rect.isFull) {
      final gridPaint = Paint()
        ..color = mint.withValues(alpha: _gridAlpha)
        ..strokeWidth = 1;

      final thirdW = cropRect.width / 3;
      final thirdH = cropRect.height / 3;

      // Vertical grid lines.
      for (var i = 1; i <= 2; i++) {
        final x = cropRect.left + thirdW * i;
        canvas.drawLine(
          Offset(x, cropRect.top),
          Offset(x, cropRect.bottom),
          gridPaint,
        );
      }
      // Horizontal grid lines.
      for (var i = 1; i <= 2; i++) {
        final y = cropRect.top + thirdH * i;
        canvas.drawLine(
          Offset(cropRect.left, y),
          Offset(cropRect.right, y),
          gridPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) =>
      rect != oldDelegate.rect || mint != oldDelegate.mint;
}
