import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/reading_speed.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/theme/app_colors.dart';
import 'package:war2aty/features/paper/presentation/models/paper_player_view.dart';
import 'package:war2aty/features/paper/presentation/widgets/paper_player_bar.dart';

import '../../../../support/pump_app.dart';

const _strings = ArStrings();
const _colors = AppColors.light;

const _preparing = PaperPlayerView(
  action: PaperPlayerAction.resume,
  enabled: false,
  preparing: true,
  fill: 0,
);
const _streaming = PaperPlayerView(
  action: PaperPlayerAction.pause,
  enabled: true,
  animated: true,
  elapsed: Duration(seconds: 42),
);
const _paused = PaperPlayerView(
  action: PaperPlayerAction.resume,
  enabled: true,
  elapsed: Duration(seconds: 42),
);
const _file = PaperPlayerView(
  action: PaperPlayerAction.pause,
  enabled: true,
  fill: 0.5,
  canSeek: true,
  elapsed: Duration(seconds: 40),
  duration: Duration(seconds: 80),
);
const _finished = PaperPlayerView(
  action: PaperPlayerAction.replay,
  enabled: true,
  fill: 1,
  elapsed: Duration(seconds: 75),
);
const _failed = PaperPlayerView(
  action: PaperPlayerAction.resume,
  enabled: false,
  fill: 0,
);

Future<void> _pumpBar(
  WidgetTester tester,
  PaperPlayerView view, {
  ReadingSpeed speed = ReadingSpeed.normal,
  VoidCallback? onPressed,
  ValueChanged<double>? onSeek,
  VoidCallback? onSpeedTap,
  TextScaler? textScaler,
  Locale locale = const Locale('ar'),
}) async {
  tester.view
    ..physicalSize = const Size(400, 200)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await pumpApp(
    tester,
    Align(
      alignment: Alignment.bottomCenter,
      child: PaperPlayerBar(
        view: view,
        speed: speed,
        onPressed: onPressed,
        onSeek: onSeek,
        onSpeedTap: onSpeedTap,
      ),
    ),
    settle: false,
    textScaler: textScaler,
    locale: locale,
  );
}

Color _barColor(WidgetTester tester, int index) =>
    (tester
                .widget<Container>(
                  find.byKey(ValueKey('paper-player-bar-$index')),
                )
                .decoration!
            as BoxDecoration)
        .color!;

Color _buttonColor(WidgetTester tester) => tester
    .widget<Material>(find.byKey(const ValueKey('paper-player-button')))
    .color!;

double _barHeight(WidgetTester tester, int index) =>
    tester.getSize(find.byKey(ValueKey('paper-player-bar-$index'))).height;

int _filledBars(WidgetTester tester) => [
  for (var i = 0; i < 30; i++) _barColor(tester, i),
].where((color) => color == _colors.brandPrimary).length;

void main() {
  group('PaperPlayerBar', () {
    testWidgets('draws thirty bars, the clock and the speed pill', (
      tester,
    ) async {
      await _pumpBar(tester, _file);

      for (var i = 0; i < 30; i++) {
        expect(find.byKey(ValueKey('paper-player-bar-$i')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('paper-player-bar-30')), findsNothing);
      expect(find.text('0:40'), findsOneWidget);
      expect(find.text('1x'), findsOneWidget);
    });

    group('preparing', () {
      testWidgets('shows a disabled button, a spinner and empty bars', (
        tester,
      ) async {
        var pressed = false;
        await _pumpBar(tester, _preparing, onPressed: () => pressed = true);

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
        expect(_filledBars(tester), 0);

        await tester.tap(find.byKey(const ValueKey('paper-player-button')));
        expect(pressed, isFalse);
      });

      testWidgets('says it is getting the reading ready', (tester) async {
        await _pumpBar(tester, _preparing);

        expect(
          find.bySemanticsLabel(_strings.paperPlayerPreparingLabel),
          findsOneWidget,
        );
      });

      testWidgets('keeps the full brand colour so the spinner stays visible', (
        tester,
      ) async {
        await _pumpBar(tester, _preparing);

        expect(_buttonColor(tester), _colors.brandPrimary);
      });
    });

    group('streaming', () {
      testWidgets('shows pause, every bar in the brand colour', (tester) async {
        await _pumpBar(tester, _streaming);

        expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
        expect(
          find.bySemanticsLabel(_strings.audioReaderPauseLabel),
          findsOneWidget,
        );
        expect(_filledBars(tester), 30);
        expect(find.text('0:42'), findsOneWidget);
      });

      testWidgets('animates the bars over time', (tester) async {
        await _pumpBar(tester, _streaming);

        final before = _barHeight(tester, 3);
        await tester.pump(const Duration(milliseconds: 250));
        final after = _barHeight(tester, 3);

        expect(after, isNot(before));
      });

      testWidgets('stops animating under reduced motion', (tester) async {
        tester.view
          ..physicalSize = const Size(400, 200)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpApp(
          tester,
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const PaperPlayerBar(
                view: _streaming,
                speed: ReadingSpeed.normal,
              ),
            ),
          ),
          settle: false,
        );

        final before = _barHeight(tester, 3);
        await tester.pump(const Duration(milliseconds: 250));

        expect(_barHeight(tester, 3), before);
      });

      testWidgets('tapping the waveform does not seek', (tester) async {
        double? sought;
        await _pumpBar(tester, _streaming, onSeek: (value) => sought = value);

        await tester.tap(find.byKey(const ValueKey('paper-player-waveform')));

        expect(sought, isNull);
      });

      testWidgets('the button calls onPressed', (tester) async {
        var pressed = false;
        await _pumpBar(tester, _streaming, onPressed: () => pressed = true);

        await tester.tap(find.byKey(const ValueKey('paper-player-button')));

        expect(pressed, isTrue);
      });

      testWidgets('a tier that cannot pause shows a disabled button', (
        tester,
      ) async {
        var pressed = false;
        await _pumpBar(
          tester,
          const PaperPlayerView(
            action: PaperPlayerAction.pause,
            enabled: false,
            animated: true,
          ),
          onPressed: () => pressed = true,
        );

        await tester.tap(find.byKey(const ValueKey('paper-player-button')));

        expect(pressed, isFalse);
      });
    });

    group('paused', () {
      testWidgets('shows play and holds the bars still', (tester) async {
        await _pumpBar(tester, _paused);

        final before = _barHeight(tester, 3);
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
        expect(
          find.bySemanticsLabel(_strings.audioReaderResumeLabel),
          findsOneWidget,
        );
        expect(_barHeight(tester, 3), before);
        expect(_barHeight(tester, 3), 12);
      });
    });

    group('file', () {
      testWidgets('fills the bars by the played fraction', (tester) async {
        await _pumpBar(tester, _file);

        expect(_filledBars(tester), 15);
        expect(_barColor(tester, 14), _colors.brandPrimary);
        expect(_barColor(tester, 15), _colors.borderStrong);
      });

      testWidgets('fills from the start side, which is the right in RTL', (
        tester,
      ) async {
        await _pumpBar(tester, _file);

        final first = tester.getCenter(
          find.byKey(const ValueKey('paper-player-bar-0')),
        );
        final last = tester.getCenter(
          find.byKey(const ValueKey('paper-player-bar-29')),
        );

        expect(first.dx, greaterThan(last.dx));
      });

      testWidgets('fills from the left in LTR', (tester) async {
        await _pumpBar(tester, _file, locale: const Locale('en'));

        final first = tester.getCenter(
          find.byKey(const ValueKey('paper-player-bar-0')),
        );
        final last = tester.getCenter(
          find.byKey(const ValueKey('paper-player-bar-29')),
        );

        expect(first.dx, lessThan(last.dx));
      });

      testWidgets('tapping the start of the waveform seeks to the start', (
        tester,
      ) async {
        double? sought;
        await _pumpBar(tester, _file, onSeek: (value) => sought = value);

        final rect = tester.getRect(
          find.byKey(const ValueKey('paper-player-waveform')),
        );
        await tester.tapAt(Offset(rect.right - 1, rect.center.dy));

        expect(sought, isNotNull);
        expect(sought!, closeTo(0, 0.02));
      });

      testWidgets('tapping the end of the waveform seeks to the end', (
        tester,
      ) async {
        double? sought;
        await _pumpBar(tester, _file, onSeek: (value) => sought = value);

        final rect = tester.getRect(
          find.byKey(const ValueKey('paper-player-waveform')),
        );
        await tester.tapAt(Offset(rect.left + 1, rect.center.dy));

        expect(sought!, closeTo(1, 0.02));
      });

      testWidgets('tapping the middle seeks to the middle', (tester) async {
        double? sought;
        await _pumpBar(tester, _file, onSeek: (value) => sought = value);

        await tester.tap(find.byKey(const ValueKey('paper-player-waveform')));

        expect(sought!, closeTo(0.5, 0.02));
      });

      testWidgets('in LTR the left edge is the start', (tester) async {
        double? sought;
        await _pumpBar(
          tester,
          _file,
          onSeek: (value) => sought = value,
          locale: const Locale('en'),
        );

        final rect = tester.getRect(
          find.byKey(const ValueKey('paper-player-waveform')),
        );
        await tester.tapAt(Offset(rect.left + 1, rect.center.dy));

        expect(sought!, closeTo(0, 0.02));
      });

      testWidgets('a file whose length is unknown ignores taps', (
        tester,
      ) async {
        double? sought;
        await _pumpBar(
          tester,
          const PaperPlayerView(
            action: PaperPlayerAction.pause,
            enabled: true,
            fill: 0,
          ),
          onSeek: (value) => sought = value,
        );

        await tester.tap(find.byKey(const ValueKey('paper-player-waveform')));

        expect(sought, isNull);
      });
    });

    group('finished', () {
      testWidgets('shows a full waveform and a replay button', (tester) async {
        var pressed = false;
        await _pumpBar(tester, _finished, onPressed: () => pressed = true);

        expect(_filledBars(tester), 30);
        expect(find.text('1:15'), findsOneWidget);
        expect(
          find.bySemanticsLabel(_strings.paperPlayerReplayLabel),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('paper-player-button')));
        expect(pressed, isTrue);
      });

      testWidgets('is told apart from a paused reading by its own icon', (
        tester,
      ) async {
        await _pumpBar(tester, _finished);
        expect(find.byIcon(Icons.replay_rounded), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

        await _pumpBar(tester, _paused);
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
        expect(find.byIcon(Icons.replay_rounded), findsNothing);
      });

      testWidgets('without a saved file the replay is disabled', (
        tester,
      ) async {
        var pressed = false;
        await _pumpBar(
          tester,
          const PaperPlayerView(
            action: PaperPlayerAction.replay,
            enabled: false,
            fill: 1,
            elapsed: Duration(seconds: 75),
          ),
          onPressed: () => pressed = true,
        );

        await tester.tap(find.byKey(const ValueKey('paper-player-button')));

        expect(pressed, isFalse);
        expect(_filledBars(tester), 30);
      });
    });

    group('failed', () {
      testWidgets('shows a disabled button and an empty waveform', (
        tester,
      ) async {
        var pressed = false;
        await _pumpBar(tester, _failed, onPressed: () => pressed = true);

        await tester.tap(find.byKey(const ValueKey('paper-player-button')));

        expect(pressed, isFalse);
        expect(_filledBars(tester), 0);
        expect(find.text('0:00'), findsOneWidget);
      });

      testWidgets('dims the button, unlike preparing', (tester) async {
        await _pumpBar(tester, _failed);

        expect(_buttonColor(tester), isNot(_colors.brandPrimary));
      });
    });

    group('speed pill', () {
      testWidgets('shows the current speed and reports taps', (tester) async {
        var taps = 0;
        await _pumpBar(
          tester,
          _file,
          speed: ReadingSpeed.faster,
          onSpeedTap: () => taps++,
        );

        expect(find.text('1.25x'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('paper-player-speed')));

        expect(taps, 1);
      });

      testWidgets('is labelled for screen readers', (tester) async {
        await _pumpBar(tester, _file, onSpeedTap: () {});

        expect(
          find.bySemanticsLabel(_strings.paperPlayerSpeedLabel),
          findsOneWidget,
        );
      });
    });

    testWidgets('survives Large Text without overflowing', (tester) async {
      await _pumpBar(
        tester,
        _file,
        speed: ReadingSpeed.fastest,
        textScaler: const TextScaler.linear(2),
        onSpeedTap: () {},
      );

      expect(tester.takeException(), isNull);
      expect(find.text('1.5x'), findsOneWidget);
    });
  });
}
