import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/bootstrap/presentation/widgets/splash_hand_off.dart';

void main() {
  /// Counts how often each layer's state is created, to prove the hand-off
  /// never remounts either of them.
  final inits = <String, int>{};
  final taps = <String>[];
  var contentReady = false;
  var revealedCount = 0;

  setUp(() {
    inits.clear();
    taps.clear();
    contentReady = false;
    revealedCount = 0;
  });

  Widget layer(String name) => _Layer(
    name: name,
    onInit: () => inits[name] = (inits[name] ?? 0) + 1,
    onTap: () => taps.add(name),
  );

  Widget handOff({required bool ready}) => SplashHandOff(
    splash: layer('splash'),
    app: ready ? layer('app') : null,
    isContentReady: () => contentReady,
    onRevealed: () => revealedCount++,
  );

  const frame = Duration(milliseconds: 16);

  final splash = find.text('splash');
  final app = find.text('app');

  double splashOpacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find.ancestor(of: splash, matching: find.byType(FadeTransition)).first,
      )
      .opacity
      .value;

  SplashPhases phases(WidgetTester tester) =>
      tester.widget<SplashPhases>(find.byType(SplashPhases));

  /// Launch completes, and the rings have settled: the app is mounted.
  /// (An animation counts from the frame after it starts, and completes only
  /// once time has passed its end — hence the extra frames.)
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpWidget(handOff(ready: false));
    await tester.pumpWidget(handOff(ready: true));
    await tester.pump();
    await tester.pump(kSplashSettleDuration);
    await tester.pump(frame);
  }

  /// The content check after a frame, then the reveal's first tick.
  Future<void> startReveal(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows only the splash until the app is ready', (tester) async {
    await tester.pumpWidget(handOff(ready: false));

    expect(splash, findsOneWidget);
    expect(app, findsNothing);
    expect(splashOpacity(tester), 1);
  });

  testWidgets('settles the rings before building the app', (tester) async {
    await tester.pumpWidget(handOff(ready: false));
    await tester.pumpWidget(handOff(ready: true));

    // Settling: the splash's parts are told, and the app is not built yet —
    // its first, expensive frame must not land while the rings still move.
    await tester.pump(kSplashSettleDuration ~/ 2);
    expect(phases(tester).settle.value, inExclusiveRange(0, 1));
    expect(app, findsNothing);

    await tester.pump(kSplashSettleDuration ~/ 2);
    await tester.pump(frame);
    expect(phases(tester).settle.value, 1);
    expect(app, findsOneWidget);
    expect(splashOpacity(tester), 1);
  });

  testWidgets('keeps the motionless splash up until the app has its content', (
    tester,
  ) async {
    await settle(tester);

    // The app is building under the splash, which still covers it fully.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(splashOpacity(tester), 1);
      expect(phases(tester).exit.value, 0);
    }

    // The first screen reports its content: the reveal starts.
    contentReady = true;
    await startReveal(tester);
    await tester.pump(kSplashExitDuration ~/ 2);
    expect(splashOpacity(tester), inExclusiveRange(0, 1));
    expect(phases(tester).exit.value, inExclusiveRange(0, 1));

    // And the splash leaves the tree, once.
    await tester.pump(kSplashExitDuration);
    await tester.pump();
    expect(splash, findsNothing);
    expect(app, findsOneWidget);
    expect(revealedCount, 1);
  });

  testWidgets('reveals anyway once the cap runs out', (tester) async {
    await settle(tester);

    // Content never arrives. The hand-off keeps asking for frames, so it
    // never stalls behind an idle screen.
    await tester.pumpAndSettle();

    expect(splash, findsNothing);
    expect(app, findsOneWidget);
    expect(revealedCount, 1);
  });

  testWidgets('keeps both layers mounted across the hand-off', (tester) async {
    contentReady = true;
    await settle(tester);
    await tester.pumpAndSettle();

    // The splash's animation never restarted, and the app was never rebuilt
    // from scratch when the splash above it left.
    expect(inits, {'splash': 1, 'app': 1});
  });

  testWidgets('lets touches through to the app once the reveal starts', (
    tester,
  ) async {
    contentReady = true;
    await settle(tester);
    await startReveal(tester);
    await tester.pump(kSplashExitDuration ~/ 4);

    await tester.tapAt(tester.getCenter(find.byType(SplashHandOff)));
    expect(taps, ['app']);
  });

  testWidgets('hides the splash from screen readers once the reveal starts', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    contentReady = true;
    await tester.pumpWidget(handOff(ready: false));
    expect(find.semantics.byLabel('splash'), findsOne);

    await settle(tester);
    await startReveal(tester);

    expect(find.semantics.byLabel('splash'), findsNothing);
    expect(find.semantics.byLabel('app'), findsOne);
    semantics.dispose();
  });

  testWidgets('under reduced motion, skips the settle and fades out quickly', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    contentReady = true;

    await tester.pumpWidget(handOff(ready: false));
    await tester.pumpWidget(handOff(ready: true));
    // Built at once: there was nothing moving to settle.
    expect(app, findsOneWidget);
    expect(phases(tester).settle.value, 0);

    await tester.pump();
    await tester.pump(kSplashExitDurationReduced);
    await tester.pump();
    expect(splash, findsNothing);
  });

  testWidgets('starts the hand-off when launch was already done', (
    tester,
  ) async {
    contentReady = true;
    await tester.pumpWidget(handOff(ready: true));
    await tester.pumpAndSettle();

    expect(splash, findsNothing);
    expect(app, findsOneWidget);
  });

  testWidgets('outside a hand-off, both phases stay at zero', (tester) async {
    late ({Animation<double> settle, Animation<double> exit}) found;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          found = SplashPhases.of(context);
          return const SizedBox();
        },
      ),
    );

    expect(found.settle.value, 0);
    expect(found.exit.value, 0);
  });
}

class _Layer extends StatefulWidget {
  const _Layer({required this.name, required this.onInit, required this.onTap});

  final String name;
  final VoidCallback onInit;
  final VoidCallback onTap;

  @override
  State<_Layer> createState() => _LayerState();
}

class _LayerState extends State<_Layer> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Center(child: Text(widget.name)),
      ),
    );
  }
}
