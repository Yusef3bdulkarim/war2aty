import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/widgets/skeleton.dart';

import '../../support/pump_app.dart';

void main() {
  group('Shimmer', () {
    testWidgets('animates its subtree', (tester) async {
      await pumpApp(
        tester,
        const Shimmer(child: SkeletonBox(width: 100, height: 20)),
        // A repeating animation never settles.
        settle: false,
      );

      expect(find.byType(ShaderMask), findsOneWidget);
      // Frames keep coming while it is on screen.
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('stands still when the platform asks for reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Shimmer(child: SkeletonBox(width: 100, height: 20)),
          ),
        ),
      );

      // The placeholders still show; only the movement is dropped.
      expect(find.byType(SkeletonBox), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('releases its controller when it leaves the tree', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const Shimmer(child: SkeletonBox(height: 20)),
        settle: false,
      );
      expect(tester.hasRunningAnimations, isTrue);

      // Replacing it must stop the ticker; a leaked repeating controller would
      // keep the device redrawing frames nobody is looking at.
      await pumpApp(tester, const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('announces its label instead of the placeholder shapes', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const Shimmer(
          label: 'لحظة...',
          child: Column(
            children: [SkeletonBox(height: 20), SkeletonBox(height: 20)],
          ),
        ),
        settle: false,
      );

      expect(find.bySemanticsLabel('لحظة...'), findsOneWidget);
    });

    testWidgets('is silent to screen readers without a label', (tester) async {
      await pumpApp(
        tester,
        const Shimmer(child: SkeletonBox(height: 20)),
        settle: false,
      );

      expect(find.byType(ExcludeSemantics), findsWidgets);
    });
  });
}
