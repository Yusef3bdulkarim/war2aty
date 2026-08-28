import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/capture/domain/entities/unit_rect.dart';
import 'package:war2aty/features/capture/presentation/widgets/draggable_crop_overlay.dart';

import '../../support/pump_app.dart';

/// Fixed size for the overlay in tests — large enough that handles and minimum
/// crop extents (60 lp) are well within range.
const _overlaySize = Size(400, 600);

/// Pumps a [DraggableCropOverlay] inside a constrained box so [LayoutBuilder]
/// resolves to a known, deterministic size.
Future<void> _pumpOverlay(
  WidgetTester tester, {
  UnitRect cropRect = UnitRect.full,
  ValueChanged<UnitRect>? onCropChanged,
  bool enabled = true,
}) async {
  await pumpApp(
    tester,
    Center(
      child: SizedBox(
        width: _overlaySize.width,
        height: _overlaySize.height,
        child: DraggableCropOverlay(
          cropRect: cropRect,
          onCropChanged: onCropChanged,
          enabled: enabled,
          child: const ColoredBox(color: Colors.grey, child: SizedBox.expand()),
        ),
      ),
    ),
    settle: false,
  );
  await tester.pump();
}

/// Pumps a [DraggableCropOverlay] under **loose** constraints with a child
/// that does not fill them — the real preview-screen shape, where
/// `BoxFit.contain` letterboxes the image inside the offered box.
///
/// With [childAspectRatio] `2.0` the child renders 400×200 inside the offered
/// 400×600; with `0.5` it renders 300×600.
Future<void> _pumpLetterboxed(
  WidgetTester tester, {
  required double childAspectRatio,
  ValueChanged<UnitRect>? onCropChanged,
}) async {
  await pumpApp(
    tester,
    Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: _overlaySize.width,
          maxHeight: _overlaySize.height,
        ),
        child: DraggableCropOverlay(
          cropRect: UnitRect.full,
          onCropChanged: onCropChanged,
          enabled: true,
          child: AspectRatio(
            aspectRatio: childAspectRatio,
            child: const ColoredBox(color: Colors.grey),
          ),
        ),
      ),
    ),
    settle: false,
  );
  await tester.pump();
}

// ── Arabic accessibility labels for the 4 interactive edge handles ──
const _top = 'مقبض القص أعلى';
const _bottom = 'مقبض القص أسفل';
const _left = 'مقبض القص يسار';
const _right = 'مقبض القص يمين';

const _edgeLabels = [_top, _bottom, _left, _right];

void main() {
  group('DraggableCropOverlay', () {
    // ── Render & structure ──

    testWidgets('renders 4 interactive edge handles with Arabic semantics', (
      tester,
    ) async {
      await _pumpOverlay(tester);

      for (final label in _edgeLabels) {
        expect(
          find.bySemanticsLabel(label),
          findsOneWidget,
          reason: 'edge handle "$label" should be present',
        );
      }
    });

    testWidgets('renders the child widget', (tester) async {
      await _pumpOverlay(tester);

      expect(find.byType(ColoredBox), findsWidgets);
    });

    // ── Disabled state ──

    testWidgets('hides all handles when disabled', (tester) async {
      await _pumpOverlay(tester, enabled: false);

      for (final label in _edgeLabels) {
        expect(
          find.bySemanticsLabel(label),
          findsNothing,
          reason: 'edge handle "$label" should be hidden when disabled',
        );
      }
    });

    // ── Edge handle drags (single-axis) ──

    testWidgets('dragging the top edge moves only the top boundary', (
      tester,
    ) async {
      UnitRect? reported;
      await _pumpOverlay(tester, onCropChanged: (r) => reported = r);

      final handle = find.bySemanticsLabel(_top);
      // Drag down 120px → 120/600 = 0.2 fractional.
      await tester.drag(handle, const Offset(0, 120));
      await tester.pump();

      expect(reported, isNotNull);
      expect(reported!.top, closeTo(0.2, 0.01));
      // Left, right, bottom unchanged.
      expect(reported!.left, closeTo(0.0, 0.01));
      expect(reported!.right, closeTo(1.0, 0.01));
      expect(reported!.bottom, closeTo(1.0, 0.01));
    });

    testWidgets('dragging the bottom edge moves only the bottom boundary', (
      tester,
    ) async {
      UnitRect? reported;
      // Start with bottom at 0.8 so the handle is within the test surface.
      const initial = UnitRect(left: 0.0, top: 0.0, right: 1.0, bottom: 0.8);
      await _pumpOverlay(
        tester,
        cropRect: initial,
        onCropChanged: (r) => reported = r,
      );

      final handle = find.bySemanticsLabel(_bottom);
      // Drag up 60px → 60/600 = 0.1 fractional → bottom from 0.8 to 0.7.
      await tester.drag(handle, const Offset(0, -60));
      await tester.pump();

      expect(reported, isNotNull);
      expect(reported!.bottom, closeTo(0.7, 0.01));
      expect(reported!.left, closeTo(0.0, 0.01));
      expect(reported!.right, closeTo(1.0, 0.01));
      expect(reported!.top, closeTo(0.0, 0.01));
    });

    testWidgets('dragging the left edge moves only the left boundary', (
      tester,
    ) async {
      UnitRect? reported;
      await _pumpOverlay(tester, onCropChanged: (r) => reported = r);

      final handle = find.bySemanticsLabel(_left);
      // Drag right 80px → 80/400 = 0.2 fractional.
      await tester.drag(handle, const Offset(80, 0));
      await tester.pump();

      expect(reported, isNotNull);
      expect(reported!.left, closeTo(0.2, 0.01));
      // Top, right, bottom unchanged.
      expect(reported!.top, closeTo(0.0, 0.01));
      expect(reported!.right, closeTo(1.0, 0.01));
      expect(reported!.bottom, closeTo(1.0, 0.01));
    });

    testWidgets('dragging the right edge moves only the right boundary', (
      tester,
    ) async {
      UnitRect? reported;
      // Start with right at 0.8 so the handle is within the test surface.
      const initial = UnitRect(left: 0.0, top: 0.0, right: 0.8, bottom: 1.0);
      await _pumpOverlay(
        tester,
        cropRect: initial,
        onCropChanged: (r) => reported = r,
      );

      final handle = find.bySemanticsLabel(_right);
      // Drag left 40px → 40/400 = 0.1 fractional → right from 0.8 to 0.7.
      await tester.drag(handle, const Offset(-40, 0));
      await tester.pump();

      expect(reported, isNotNull);
      expect(reported!.right, closeTo(0.7, 0.01));
      expect(reported!.left, closeTo(0.0, 0.01));
      expect(reported!.top, closeTo(0.0, 0.01));
      expect(reported!.bottom, closeTo(1.0, 0.01));
    });

    // ── Clamping / bounds enforcement ──

    testWidgets('handles clamp to 0..1 — cannot drag beyond image bounds', (
      tester,
    ) async {
      UnitRect? reported;
      await _pumpOverlay(tester, onCropChanged: (r) => reported = r);

      // Try to drag top edge way above the top of the image.
      final handle = find.bySemanticsLabel(_top);
      await tester.drag(handle, const Offset(0, -300));
      await tester.pump();

      expect(reported, isNotNull);
      expect(reported!.top, closeTo(0.0, 0.01));
    });

    testWidgets('minimum crop extent is enforced — cannot shrink below 60lp', (
      tester,
    ) async {
      UnitRect? reported;
      await _pumpOverlay(tester, onCropChanged: (r) => reported = r);

      // Try to drag top edge almost all the way to the bottom.
      // min extent = 60lp → in a 400×600 box: minH=0.10.
      final handle = find.bySemanticsLabel(_top);
      await tester.drag(handle, const Offset(0, 590));
      await tester.pump();

      expect(reported, isNotNull);
      // top should be clamped to at most bottom - minH = 1.0 - 0.10 = 0.90.
      expect(reported!.top, closeTo(0.90, 0.01));
    });

    // ── External state sync ──

    testWidgets('syncs to a new cropRect from outside (e.g. rotate reset)', (
      tester,
    ) async {
      UnitRect? reported;
      final cropRect = ValueNotifier(
        const UnitRect(left: 0.1, top: 0.1, right: 0.9, bottom: 0.9),
      );

      await pumpApp(
        tester,
        Center(
          child: SizedBox(
            width: _overlaySize.width,
            height: _overlaySize.height,
            child: ValueListenableBuilder<UnitRect>(
              valueListenable: cropRect,
              builder: (_, rect, _) => DraggableCropOverlay(
                cropRect: rect,
                onCropChanged: (r) => reported = r,
                enabled: true,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        settle: false,
      );
      await tester.pump();

      // Now simulate an external reset (rotate) to full.
      cropRect.value = UnitRect.full;
      await tester.pump();

      // Drag top edge inward — should start from 0.0 not from 0.1.
      final handle = find.bySemanticsLabel(_top);
      await tester.drag(handle, const Offset(0, 60));
      await tester.pump();

      expect(reported, isNotNull);
      expect(reported!.top, closeTo(0.1, 0.01));
    });

    // ── Mid-drag sync guard ──

    testWidgets('does not sync from outside while a drag is in progress', (
      tester,
    ) async {
      UnitRect? reported;
      final cropRect = ValueNotifier(UnitRect.full);

      await pumpApp(
        tester,
        Center(
          child: SizedBox(
            width: _overlaySize.width,
            height: _overlaySize.height,
            child: ValueListenableBuilder<UnitRect>(
              valueListenable: cropRect,
              builder: (_, rect, _) => DraggableCropOverlay(
                cropRect: rect,
                onCropChanged: (r) => reported = r,
                enabled: true,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        settle: false,
      );
      await tester.pump();

      // Start a drag on the top edge.
      final handle = find.bySemanticsLabel(_top);
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump();

      // While dragging, push an external update.
      cropRect.value = const UnitRect(
        left: 0.5,
        top: 0.5,
        right: 1.0,
        bottom: 1.0,
      );
      await tester.pump();

      // Continue dragging — should still be relative to the original full rect.
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      // The reported rect should reflect the drag from top=0.0, not from
      // the externally-pushed top=0.5.
      expect(reported, isNotNull);
      expect(reported!.top, closeTo(0.2, 0.01));
    });

    // ── Non-full initial rect ──

    testWidgets('handles start at the correct position for a non-full rect', (
      tester,
    ) async {
      UnitRect? reported;
      const initial = UnitRect(left: 0.2, top: 0.1, right: 0.8, bottom: 0.9);
      await _pumpOverlay(
        tester,
        cropRect: initial,
        onCropChanged: (r) => reported = r,
      );

      // Drag top edge down 60px = 0.1 fractional of 600.
      final handle = find.bySemanticsLabel(_top);
      await tester.drag(handle, const Offset(0, 60));
      await tester.pump();

      expect(reported, isNotNull);
      // top was 0.1, dragged down 0.1 → 0.2.
      expect(reported!.top, closeTo(0.2, 0.01));
      // left and right unchanged.
      expect(reported!.left, closeTo(0.2, 0.01));
      expect(reported!.right, closeTo(0.8, 0.01));
      expect(reported!.bottom, closeTo(0.9, 0.01));
    });

    // ── onCropChanged not called during drag, only on end ──

    testWidgets('onCropChanged fires only on drag end, not during updates', (
      tester,
    ) async {
      final calls = <UnitRect>[];
      await _pumpOverlay(tester, onCropChanged: calls.add);

      final handle = find.bySemanticsLabel(_top);
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump();

      // Several intermediate moves.
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();

      // Should not have fired yet.
      expect(calls, isEmpty);

      // End the drag.
      await gesture.up();
      await tester.pump();

      // Now it should fire exactly once.
      expect(calls, hasLength(1));
    });

    // ── Letterboxed child (regression) ──
    //
    // The handles must measure the *rendered child*, not the space offered to
    // it. Every test above pumps a child that fills its box, so the two sizes
    // coincide and the distinction is invisible; on the preview screen an
    // `Image` with `BoxFit.contain` is letterboxed inside a taller/wider box,
    // and measuring the offered box pushed the handles off the image.

    testWidgets('side handles stay on a wide letterboxed child', (
      tester,
    ) async {
      // 400×200 child inside a 400×600 box — 400lp of vertical slack.
      await _pumpLetterboxed(tester, childAspectRatio: 2);

      final image = tester.getRect(find.byType(DraggableCropOverlay));
      expect(image.height, closeTo(200, 0.5), reason: 'child is letterboxed');

      for (final label in [_left, _right]) {
        expect(
          tester.getCenter(find.bySemanticsLabel(label)).dy,
          closeTo(image.center.dy, 0.5),
          reason: '$label should sit at the image midpoint, not the box one',
        );
      }
    });

    testWidgets('end handles stay on a tall letterboxed child', (tester) async {
      // 300×600 child inside a 400×600 box — 100lp of horizontal slack.
      await _pumpLetterboxed(tester, childAspectRatio: 0.5);

      final image = tester.getRect(find.byType(DraggableCropOverlay));
      expect(image.width, closeTo(300, 0.5), reason: 'child is letterboxed');

      for (final label in [_top, _bottom]) {
        expect(
          tester.getCenter(find.bySemanticsLabel(label)).dx,
          closeTo(image.center.dx, 0.5),
          reason: '$label should sit at the image midpoint, not the box one',
        );
      }
    });

    testWidgets('drag deltas scale by the child width, not the box width', (
      tester,
    ) async {
      UnitRect? reported;
      // 300×600 child inside a 400×600 box.
      await _pumpLetterboxed(
        tester,
        childAspectRatio: 0.5,
        onCropChanged: (r) => reported = r,
      );

      // Drag right 60px → 60/300 = 0.2 of the image (not 60/400 = 0.15).
      await tester.drag(find.bySemanticsLabel(_left), const Offset(60, 0));
      await tester.pump();

      expect(reported, isNotNull);
      expect(reported!.left, closeTo(0.2, 0.01));
    });

    // ── Whole-edge grab ──
    //
    // The crop border itself is the handle; the pill only marks where it is.
    // Grabbing an edge away from its midpoint must drag it just the same.

    testWidgets('the top edge can be grabbed away from its midpoint', (
      tester,
    ) async {
      UnitRect? reported;
      await _pumpOverlay(tester, onCropChanged: (r) => reported = r);

      final box = tester.getRect(find.byType(DraggableCropOverlay));
      // 10% along the top edge — nowhere near the pill.
      final offEdge = Offset(box.left + box.width * 0.1, box.top + 3);
      await tester.dragFrom(offEdge, const Offset(0, 120));
      await tester.pump();

      expect(reported, isNotNull, reason: 'the whole edge should be grabbable');
      expect(reported!.top, closeTo(0.2, 0.01));
    });

    testWidgets('the left edge can be grabbed away from its midpoint', (
      tester,
    ) async {
      UnitRect? reported;
      await _pumpOverlay(tester, onCropChanged: (r) => reported = r);

      final box = tester.getRect(find.byType(DraggableCropOverlay));
      // 10% down the left edge — nowhere near the pill.
      final offEdge = Offset(box.left + 3, box.top + box.height * 0.1);
      await tester.dragFrom(offEdge, const Offset(80, 0));
      await tester.pump();

      expect(reported, isNotNull, reason: 'the whole edge should be grabbable');
      expect(reported!.left, closeTo(0.2, 0.01));
    });

    // ── RTL layout ──

    testWidgets('all 4 edge handles are present under RTL layout', (
      tester,
    ) async {
      // pumpApp defaults to Arabic locale → RTL.
      await _pumpOverlay(tester);

      for (final label in _edgeLabels) {
        expect(
          find.bySemanticsLabel(label),
          findsOneWidget,
          reason: '$label should be present in RTL',
        );
      }
    });

    // ── Large Text ──

    testWidgets('renders without overflow under large text scaling', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Center(
          child: SizedBox(
            width: _overlaySize.width,
            height: _overlaySize.height,
            child: DraggableCropOverlay(
              cropRect: UnitRect.full,
              onCropChanged: (_) {},
              enabled: true,
              child: const SizedBox.expand(),
            ),
          ),
        ),
        settle: false,
        textScaler: const TextScaler.linear(2.0),
      );
      await tester.pump();

      // The overlay is purely graphical (no text), so it should render fine.
      expect(find.byType(DraggableCropOverlay), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
