import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/theme/app_colors.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/lens_timeline.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/paper_frame.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/paper_layout.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/paper_painting.dart';

const _pass = LensTimeline.pass;
final int _key = PaperLayout.words.indexWhere((w) => w.isKey);
final double _keyAt = LensTimeline.wordReadAt[_key];

void main() {
  group('PaperFrame.at — words', () {
    test('start unread', () {
      final frame = PaperFrame.at(0.01);
      expect(frame.words.skip(1), everyElement((lit: 0.0, read: 0.0)));
    });

    test('flash teal as the lens reaches them, then settle to read', () {
      final at = LensTimeline.wordReadAt[5];
      expect(PaperFrame.at(at - 0.01).words[5], (lit: 0.0, read: 0.0));
      expect(PaperFrame.at(at).words[5], (lit: 1.0, read: 1.0));
      expect(PaperFrame.at(at + 0.4).words[5], (lit: 1.0, read: 1.0));
      expect(PaperFrame.at(at + 0.8).words[5].lit, inExclusiveRange(0, 1));
      expect(PaperFrame.at(at + 1.2).words[5], (lit: 0.0, read: 1.0));
    });

    test('fade back to unread as their pass ends, ready to be read again', () {
      final at = LensTimeline.wordReadAt[5];
      expect(PaperFrame.at(at + 7.5).words[5].read, inExclusiveRange(0, 1));
      expect(PaperFrame.at(at + _pass).words[5], (lit: 1.0, read: 1.0));
    });
  });

  group('PaperFrame.at — key words', () {
    test('underline as the lens arrives, and keep it for the pass', () {
      expect(PaperFrame.at(_keyAt - 0.01).underlines[_key].opacity, 0);
      final growing = PaperFrame.at(_keyAt + 0.16).underlines[_key];
      expect(growing.width, closeTo(0.5, 1e-9));
      expect(PaperFrame.at(_keyAt + 1).underlines[_key], (
        opacity: 1.0,
        width: 1.0,
      ));
      expect(
        PaperFrame.at(_keyAt + 7.7).underlines[_key].opacity,
        inExclusiveRange(0, 1),
      );
    });

    test('burst a sparkle a beat later, gone within half a second', () {
      final at = _keyAt + 0.1;
      expect(PaperFrame.at(at - 0.01).sparkles[_key].opacity, 0);
      final peak = PaperFrame.at(at + 0.16).sparkles[_key];
      expect(peak.scale, closeTo(1.3, 1e-9));
      expect(peak.degrees, closeTo(45, 1e-9));
      expect(PaperFrame.at(at + 0.3).sparkles[_key].degrees, greaterThan(45));
      expect(PaperFrame.at(at + 0.6).sparkles[_key].opacity, 0);
    });

    test('other words get no underline or sparkle', () {
      for (var t = 0.0; t < _pass; t += 0.1) {
        final frame = PaperFrame.at(t);
        for (final (i, word) in PaperLayout.words.indexed) {
          if (word.isKey) continue;
          expect(frame.underlines[i].opacity, 0);
          expect(frame.sparkles[i].opacity, 0);
        }
      }
    });
  });

  group('PaperFrame.at — review checks', () {
    test('none during the first pass', () {
      for (var t = 0.0; t < _pass + LensTimeline.lineEnds.first; t += 0.05) {
        expect(
          PaperFrame.at(t).checks,
          everyElement((scale: 0.0, opacity: 0.0)),
          reason: 't = $t',
        );
      }
    });

    test('pop in past full size as the lens finishes each line', () {
      for (final (line, end) in LensTimeline.lineEnds.indexed) {
        final start = _pass + end;
        expect(PaperFrame.at(start - 0.01).checks[line].opacity, 0);
        expect(
          PaperFrame.at(start + 0.24).checks[line].scale,
          closeTo(1.2, 1e-9),
        );
        expect(PaperFrame.at(start + 1).checks[line], (
          scale: 1.0,
          opacity: 1.0,
        ));
      }
    });

    test('fade as their pass ends, and pop in again the next', () {
      final end = LensTimeline.lineEnds.first;
      expect(
        PaperFrame.at(_pass + end + 7.8).checks.first.opacity,
        inExclusiveRange(0, 1),
      );
      expect(PaperFrame.at(2 * _pass + end + 1).checks.first.opacity, 1);
    });
  });

  group('PaperFrame.resting and .finished', () {
    test('resting: nothing read or lit, the key words underlined', () {
      final frame = PaperFrame.resting;
      expect(frame.words, everyElement((lit: 0.0, read: 0.0)));
      expect(frame.underlines[_key], (opacity: 1.0, width: 1.0));
      expect(
        frame.sparkles,
        everyElement((scale: 0.0, degrees: 0.0, opacity: 0.0)),
      );
      expect(frame.checks, everyElement((scale: 0.0, opacity: 0.0)));
    });

    test('finished: every word read, nothing lit, no marks', () {
      final frame = PaperFrame.finished;
      expect(frame.words, everyElement((lit: 0.0, read: 1.0)));
      expect(frame.underlines[_key].opacity, 0);
      expect(frame.checks, everyElement((scale: 0.0, opacity: 0.0)));
    });
  });

  group('PaperPainting', () {
    test('paints every kind of frame in both palettes', () {
      for (final colors in [AppColors.light, AppColors.highContrast]) {
        for (final frame in [
          PaperFrame.at(_keyAt + 0.2),
          PaperFrame.at(_pass + 3),
          PaperFrame.resting,
          PaperFrame.finished,
        ]) {
          final recorder = PictureRecorder();
          final canvas = Canvas(recorder);
          PaperPainting.paintStack(canvas, colors, finish: 0.5);
          PaperPainting.paintContent(canvas, frame, colors);
          PaperPainting.paintMarks(canvas, frame, colors);
          recorder.endRecording().dispose();
        }
      }
    });

    test('read, unread and lit words are told apart in both palettes', () {
      for (final colors in [AppColors.light, AppColors.highContrast]) {
        final inks = {colors.border, colors.iconMuted, colors.brandPrimary};
        expect(inks, hasLength(3));
        expect(
          colors.iconMuted.computeLuminance(),
          lessThan(colors.border.computeLuminance()),
        );
      }
    });

    test('easeOutBack overshoots and settles on 1', () {
      expect(PaperPainting.easeOutBack(0), closeTo(0, 1e-9));
      expect(PaperPainting.easeOutBack(0.7), greaterThan(1));
      expect(PaperPainting.easeOutBack(1), closeTo(1, 1e-9));
    });
  });
}
