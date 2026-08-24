import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/unit_rect.dart';
import '../capture_palette.dart';

// ── Design constants (F15-T05 proposal) ──

/// Corner bracket arm length, matching the existing CropFrame/ViewfinderFrame
/// brackets for visual continuity.
const double _bracketArm = 20;

/// Corner bracket stroke.
const double _bracketStroke = 3;

/// Edge midpoint pill dimensions.
const double _edgePillLength = 28;
const double _edgePillThickness = 4;

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

/// Which edge/corner a handle controls.
enum _HandleType {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  top,
  bottom,
  left,
  right,
}

/// Free-form drag-crop overlay for the image preview screen (F15 locked
/// decision #5).
///
/// Replaces the static [CropFrame] brackets. Always active — no "enter crop
/// mode" toggle. Starts at [UnitRect.full] and the user drags the 4 corner
/// brackets + 4 edge midpoint pills to refine the selection.
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
      case _HandleType.topLeft:
        left = (left + dx).clamp(0.0, right - minW);
        top = (top + dy).clamp(0.0, bottom - minH);
      case _HandleType.topRight:
        right = (right + dx).clamp(left + minW, 1.0);
        top = (top + dy).clamp(0.0, bottom - minH);
      case _HandleType.bottomLeft:
        left = (left + dx).clamp(0.0, right - minW);
        bottom = (bottom + dy).clamp(top + minH, 1.0);
      case _HandleType.bottomRight:
        right = (right + dx).clamp(left + minW, 1.0);
        bottom = (bottom + dy).clamp(top + minH, 1.0);
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // The image.
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
            // Drag handles.
            if (widget.enabled) ...[
              for (final type in _HandleType.values)
                _buildHandle(type, size, context),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHandle(
    _HandleType type,
    Size overlaySize,
    BuildContext context,
  ) {
    final r = _rect;
    final w = overlaySize.width;
    final h = overlaySize.height;

    // Pixel position of the handle's anchor point.
    final (anchorX, anchorY) = switch (type) {
      _HandleType.topLeft => (r.left * w, r.top * h),
      _HandleType.topRight => (r.right * w, r.top * h),
      _HandleType.bottomLeft => (r.left * w, r.bottom * h),
      _HandleType.bottomRight => (r.right * w, r.bottom * h),
      _HandleType.top => ((r.left + r.right) / 2 * w, r.top * h),
      _HandleType.bottom => ((r.left + r.right) / 2 * w, r.bottom * h),
      _HandleType.left => (r.left * w, (r.top + r.bottom) / 2 * h),
      _HandleType.right => (r.right * w, (r.top + r.bottom) / 2 * h),
    };

    final semanticLabel = switch (type) {
      _HandleType.topLeft => 'مقبض القص أعلى يسار',
      _HandleType.topRight => 'مقبض القص أعلى يمين',
      _HandleType.bottomLeft => 'مقبض القص أسفل يسار',
      _HandleType.bottomRight => 'مقبض القص أسفل يمين',
      _HandleType.top => 'مقبض القص أعلى',
      _HandleType.bottom => 'مقبض القص أسفل',
      _HandleType.left => 'مقبض القص يسار',
      _HandleType.right => 'مقبض القص يمين',
    };

    return Positioned(
      left: anchorX - _touchTarget / 2,
      top: anchorY - _touchTarget / 2,
      width: _touchTarget,
      height: _touchTarget,
      child: Semantics(
        label: semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => _onDragStart(), // ignore DragStartDetails
          onPanUpdate: (d) => _onDragUpdate(type, d.delta, overlaySize),
          onPanEnd: (_) => _onDragEnd(),
          onPanCancel: _onDragEnd,
          child: _HandleVisual(type: type, mint: AppColors.of(context).mint),
        ),
      ),
    );
  }
}

/// The visible part of a handle — a corner L-bracket or an edge pill.
/// Centered inside the 48 dp touch target.
class _HandleVisual extends StatelessWidget {
  const _HandleVisual({required this.type, required this.mint});

  final _HandleType type;
  final Color mint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: switch (type) {
        _HandleType.topLeft ||
        _HandleType.topRight ||
        _HandleType.bottomLeft ||
        _HandleType.bottomRight => _CornerBracket(type: type, mint: mint),
        _HandleType.top || _HandleType.bottom => SizedBox(
          width: _edgePillLength,
          height: _edgePillThickness,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: mint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        _HandleType.left || _HandleType.right => SizedBox(
          width: _edgePillThickness,
          height: _edgePillLength,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: mint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      },
    );
  }
}

/// One mint L-bracket, matching the CropFrame/ViewfinderFrame bracket style.
class _CornerBracket extends StatelessWidget {
  const _CornerBracket({required this.type, required this.mint});

  final _HandleType type;
  final Color mint;

  @override
  Widget build(BuildContext context) {
    final isTop = type == _HandleType.topLeft || type == _HandleType.topRight;
    final isLeft =
        type == _HandleType.topLeft || type == _HandleType.bottomLeft;

    final side = BorderSide(color: mint, width: _bracketStroke);

    return SizedBox(
      width: _bracketArm,
      height: _bracketArm,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? side : BorderSide.none,
            bottom: isTop ? BorderSide.none : side,
            left: isLeft ? side : BorderSide.none,
            right: isLeft ? BorderSide.none : side,
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
