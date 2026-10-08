import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/bootstrap/presentation/widgets/launch_hand_off.dart';

/// F28-T07. These cover the two defects the hand-off exists to prevent, not
/// the shape of the code that prevents them:
///
/// 1. the launch screen cutting straight to the app;
/// 2. the app being revealed before its first screen has anything to show.
///
/// Both were real: F27-P01 recorded the cut, and the two long frames Home
/// costs while it builds and takes its first data.
void main() {
  // Not 'launch'/'app': the hand-off keys its own subtrees with those exact
  // ValueKey<String>s, so a finder would match two widgets.
  const launchKey = Key('test.launchScreen');
  const appKey = Key('test.app');

  var contentReady = false;
  var revealed = 0;

  setUp(() {
    contentReady = false;
    revealed = 0;
  });

  /// Pumps the hand-off with [app] (null until launch is done).
  Future<void> pumpHandOff(
    WidgetTester tester, {
    Widget? app,
    bool reducedMotion = false,
    bool withContentGate = true,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: LaunchHandOff(
            launchScreen: const ColoredBox(
              color: Color(0xFF0A6C76),
              child: SizedBox.expand(child: Placeholder(key: launchKey)),
            ),
            app: app,
            isContentReady: withContentGate ? () => contentReady : null,
            onRevealed: () => revealed++,
          ),
        ),
      ),
    );
  }

  Widget theApp() => const ColoredBox(
    color: Color(0xFFFFFFFF),
    child: SizedBox.expand(child: Placeholder(key: appKey)),
  );

  /// The launch screen's current opacity, 1 until the reveal starts.
  double launchOpacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find.ancestor(
          of: find.byKey(launchKey),
          matching: find.byType(FadeTransition),
        ),
      )
      .opacity
      .value;

  /// Drives a reveal whose conditions are already met through to the end.
  ///
  /// One pump for the post-frame callback to notice and start the reveal, then
  /// `pumpAndSettle` for the rest. Counting the frames by hand is a trap here:
  /// the reveal is started from a post-frame callback, the fade runs on a
  /// ticker, and the completed status calls `setState`, so the number of pumps
  /// differs depending on what started the reveal.
  Future<void> finishReveal(WidgetTester tester) async {
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('shows only the launch screen until launch is done', (
    tester,
  ) async {
    await pumpHandOff(tester);
    await tester.pump();

    expect(find.byKey(launchKey), findsOneWidget);
    expect(find.byKey(appKey), findsNothing);
    expect(revealed, 0);
  });

  testWidgets('builds the app under the launch screen, not instead of it', (
    tester,
  ) async {
    await pumpHandOff(tester, app: theApp());
    await tester.pump();

    expect(
      find.byKey(appKey),
      findsOneWidget,
      reason: 'the app must be built while it is still covered',
    );
    expect(find.byKey(launchKey), findsOneWidget);
    expect(
      launchOpacity(tester),
      1,
      reason:
          'the launch screen stays fully opaque while the app takes its two '
          'long frames — this is what stops the user seeing a half-drawn Home',
    );
  });

  testWidgets('waits for the first screen to have its content', (tester) async {
    await pumpHandOff(tester, app: theApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      launchOpacity(tester),
      1,
      reason: 'content has not been reported, so nothing may be revealed',
    );

    contentReady = true;
    await tester.pump();
    await tester.pump();
    await tester.pump(kLaunchRevealDuration ~/ 2);
    expect(launchOpacity(tester), lessThan(1));
  });

  testWidgets('reveals anyway once the cap runs out', (tester) async {
    await pumpHandOff(tester, app: theApp());
    await tester.pump();
    // Content is never reported: the cap is the only way out, and without it
    // the user is stranded on the mark.
    await tester.pump(kLaunchRevealCap);
    await finishReveal(tester);

    expect(find.byKey(launchKey), findsNothing);
    expect(revealed, 1);
  });

  testWidgets('fades rather than cuts, then leaves the tree', (tester) async {
    contentReady = true;
    await pumpHandOff(tester, app: theApp());
    await tester.pump();
    await tester.pump();

    // Mid-fade: both layers on screen, the launch screen part-way out.
    await tester.pump(kLaunchRevealDuration ~/ 2);
    final mid = launchOpacity(tester);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));
    expect(find.byKey(appKey), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(launchKey), findsNothing);
    expect(revealed, 1);
  });

  testWidgets('keeps both layers mounted across the hand-off', (tester) async {
    contentReady = true;
    await pumpHandOff(tester, app: theApp());
    final appElement = tester.element(find.byKey(appKey));

    await finishReveal(tester);

    expect(
      tester.element(find.byKey(appKey)),
      same(appElement),
      reason: 'the app must never be rebuilt from scratch by the reveal',
    );
  });

  testWidgets('lets touches through to the app once the reveal starts', (
    tester,
  ) async {
    contentReady = true;
    await pumpHandOff(tester, app: theApp());
    await tester.pump();
    await tester.pump();
    await tester.pump(kLaunchRevealDuration ~/ 2);

    final ignoring = tester
        .widget<IgnorePointer>(
          find.ancestor(
            of: find.byKey(launchKey),
            matching: find.byType(IgnorePointer),
          ),
        )
        .ignoring;
    expect(ignoring, isTrue);
  });

  testWidgets('hides the launch screen from screen readers as it goes', (
    tester,
  ) async {
    contentReady = true;
    await pumpHandOff(tester, app: theApp());
    await tester.pump();
    await tester.pump();
    await tester.pump(kLaunchRevealDuration ~/ 2);

    final excluding = tester
        .widget<ExcludeSemantics>(
          find.ancestor(
            of: find.byKey(launchKey),
            matching: find.byType(ExcludeSemantics),
          ),
        )
        .excluding;
    expect(excluding, isTrue);
  });

  testWidgets('under reduced motion the fade is short, but still a fade', (
    tester,
  ) async {
    contentReady = true;
    await pumpHandOff(tester, app: theApp(), reducedMotion: true);
    await tester.pump();
    await tester.pump();

    await tester.pump(kLaunchRevealDurationReduced ~/ 2);
    expect(launchOpacity(tester), lessThan(1));

    await tester.pumpAndSettle();
    expect(find.byKey(launchKey), findsNothing);
    expect(revealed, 1);
  });

  testWidgets('with no content gate, reveals as soon as the app is built', (
    tester,
  ) async {
    await pumpHandOff(tester, app: theApp(), withContentGate: false);
    await finishReveal(tester);

    expect(find.byKey(launchKey), findsNothing);
    expect(revealed, 1);
  });

  testWidgets('reports the hand-off exactly once', (tester) async {
    contentReady = true;
    await pumpHandOff(tester, app: theApp());
    await finishReveal(tester);
    await tester.pump(const Duration(seconds: 2));

    expect(revealed, 1);
  });

  testWidgets('holds no minimum display time of its own', (tester) async {
    // F28-T07 dropped the planned ~500 ms floor: the native splash already
    // drew this frame, so there is no moment at which the launch screen
    // appears, and a floor would only delay an app that was ready.
    contentReady = true;
    await pumpHandOff(tester, app: theApp());
    await tester.pump();
    await tester.pump(kLaunchRevealDuration);

    expect(
      launchOpacity(tester),
      0,
      reason:
          'the whole hand-off is over one fade after the app had its content. '
          'With the planned floor it would still have been fully opaque here, '
          'and for another 200 ms after that',
    );
  });
}
