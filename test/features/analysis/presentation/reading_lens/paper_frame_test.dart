import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/theme/app_colors.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/lens_timeline.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/paper_frame.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/paper_layout.dart';
import 'package:war2aty/features/analysis/presentation/widgets/reading_lens/paper_painting.dart';

const _pass = LensTimeline.pass;
final int _key = PaperLayout.words.indexWhere((w) => w.isKey);

void main() {
  group('PaperFrame.at — the first pass', () {
    test('starts with nothing read, outlined, underlined or checked', () {
      final frame = PaperFrame.at(0);
      expect(frame.wordRead, everyElement(isFalse));
      expect(frame.titleOutline, 0);
      expect(frame.keyUnderline, 0);
      expect(frame.fieldVisited, everyElement(isFalse));
      expect(frame.checks, everyElement(0));
    });

    test('lights a word only while the lens is on it', () {
      final readAt = LensTimeline.wordReadAt[0];
      expect(PaperFrame.at(readAt).wordLit[0], 1);
      expect(PaperFrame.at(0).wordLit[0], 0);
      expect(PaperFrame.at(readAt + 0.6).wordLit[0], 0);
    });

    test('marks a word read from the moment the lens reaches it', () {
      for (final (i, at) in LensTimeline.wordReadAt.indexed) {
        expect(PaperFrame.at(at - 0.02).wordRead[i], isFalse, reason: '$i');
        expect(PaperFrame.at(at).wordRead[i], isTrue, reason: '$i');
      }
    });

    test('draws the title outline once the lens reaches the title', () {
      expect(PaperFrame.at(LensTimeline.titleReachedAt).titleOutline, 0);
      expect(PaperFrame.at(0.6).titleOutline, inExclusiveRange(0, 1));
      expect(PaperFrame.at(1).titleOutline, 1);
      expect(PaperFrame.at(0.7).titleLit, 1);
    });

    test('underlines the key word once the lens reaches it, and keeps it', () {
      expect(PaperFrame.at(2.3).keyUnderline, 0);
      expect(PaperFrame.at(2.6).keyUnderline, inExclusiveRange(0, 1));
      expect(PaperFrame.at(3).keyUnderline, 1);
      expect(PaperFrame.at(_pass - 0.01).keyUnderline, 1);
      expect(PaperFrame.at(2.55).wordLit[_key], 1);
    });

    test('glows each field only around its pause, then keeps it visited', () {
      for (final (i, (start, end)) in LensTimeline.fieldPauses.indexed) {
        expect(PaperFrame.at(start - 0.05).fieldActive[i], 0);
        expect(PaperFrame.at(end).fieldActive[i], closeTo(1, 1e-9));
        expect(PaperFrame.at(end + 0.35).fieldActive[i], 0);
        expect(PaperFrame.at(end - 0.01).fieldVisited[i], isFalse);
        expect(PaperFrame.at(end).fieldVisited[i], isTrue);
      }
    });

    test('shows no review checks', () {
      for (var t = 0.0; t < _pass; t += 0.05) {
        expect(PaperFrame.at(t).checks, everyElement(0), reason: 't = $t');
      }
    });
  });

  group('PaperFrame.at — later passes', () {
    test('keeps everything read, outlined and underlined', () {
      final frame = PaperFrame.at(_pass + 0.1);
      expect(frame.wordRead, everyElement(isTrue));
      expect(frame.titleOutline, 1);
      expect(frame.keyUnderline, 1);
      expect(frame.fieldVisited, everyElement(isTrue));
    });

    test('pops each check in as the lens leaves its part', () {
      for (final (i, check) in LensTimeline.reviewChecks.indexed) {
        expect(PaperFrame.at(_pass + check.at - 0.01).checks[i], 0);
        expect(PaperFrame.at(_pass + check.at + 0.4).checks[i], 1);
      }
    });

    test('clears the checks at the start of every pass', () {
      final lastPassEnd = PaperFrame.at(2 * _pass - 0.01);
      expect(lastPassEnd.checks, everyElement(1));
      final fading = PaperFrame.at(2 * _pass + 0.1);
      expect(fading.checks.first, inExclusiveRange(0, 1));
      expect(fading.checks.last, inExclusiveRange(0, 1));
      final cleared = PaperFrame.at(2 * _pass + 0.3);
      expect(cleared.checks, everyElement(0));
    });
  });

  group('PaperFrame.resting and .finished', () {
    test('resting: the title marked, the underline drawn, nothing moving', () {
      final frame = PaperFrame.resting;
      expect(frame.titleOutline, 1);
      expect(frame.keyUnderline, 1);
      expect(frame.wordLit, everyElement(0));
      expect(frame.checks, everyElement(0));
    });

    test('finished: every word read, nothing lit, no checks', () {
      final frame = PaperFrame.finished;
      expect(frame.wordRead, everyElement(isTrue));
      expect(frame.wordLit, everyElement(0));
      expect(frame.titleLit, 0);
      expect(frame.checks, everyElement(0));
      expect(frame.keyUnderline, 1);
    });
  });

  group('PaperPainting', () {
    test('paints every kind of frame in both palettes', () {
      for (final colors in [AppColors.light, AppColors.highContrast]) {
        for (final frame in [
          PaperFrame.at(0.7),
          PaperFrame.at(4.4),
          PaperFrame.at(2 * _pass + 0.1),
          PaperFrame.resting,
          PaperFrame.finished,
        ]) {
          final recorder = PictureRecorder();
          final canvas = Canvas(recorder);
          PaperPainting.paintStack(canvas, colors, finish: 0.5);
          PaperPainting.paintContent(canvas, frame, colors);
          PaperPainting.paintChecks(canvas, frame, colors);
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
