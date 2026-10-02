import 'lens_timeline.dart';
import 'paper_layout.dart';

/// How one word is inked: [read] mixes its unread colour towards the read
/// one, then [lit] mixes that towards the lens's teal.
typedef WordInk = ({double lit, double read});

/// A key word's mint underline: how opaque, and how much of the word it spans.
typedef Underline = ({double opacity, double width});

/// A key word's sparkle: its size (1 = full), turn and opacity.
typedef Sparkle = ({double scale, double degrees, double opacity});

/// A line's review check: its size (1 = full) and opacity.
typedef Check = ({double scale, double opacity});

/// How far along each of the paper's reactions to the lens is at one moment
/// (F22 #18, the C+ design).
///
/// Each reaction runs its own cycle, one pass long, from the moment the lens
/// first reaches its part: a word flashes teal, settles to «read», and fades
/// back to unread at the end of the pass, ready to be read again. A pure
/// function of the clock ([PaperFrame.at]), so the painter keeps no state and
/// every fade is exact on any frame.
final class PaperFrame {
  const PaperFrame({
    required this.words,
    required this.underlines,
    required this.sparkles,
    required this.checks,
  });

  /// The paper at [seconds] since the page appeared, the lens moving.
  factory PaperFrame.at(double seconds) {
    return PaperFrame(
      words: [
        for (final at in LensTimeline.wordReadAt) _wordInk(_phase(seconds, at)),
      ],
      underlines: [
        for (final (i, word) in PaperLayout.words.indexed)
          word.isKey
              ? _underline(_phase(seconds, LensTimeline.wordReadAt[i]))
              : _noUnderline,
      ],
      sparkles: [
        for (final (i, word) in PaperLayout.words.indexed)
          word.isKey
              ? _sparkle(
                  _phase(seconds, LensTimeline.wordReadAt[i] + _sparkleDelay),
                )
              : _noSparkle,
      ],
      checks: [
        for (final end in LensTimeline.lineEnds)
          // From the second pass on: the paper is being re-checked (F22 #8).
          _check(_phase(seconds, LensTimeline.pass + end)),
      ],
    );
  }

  /// Under reduced motion: nothing read or lit, the key words underlined.
  static final PaperFrame resting = PaperFrame(
    words: List.filled(PaperLayout.words.length, _unread),
    underlines: [
      for (final word in PaperLayout.words)
        word.isKey ? _fullUnderline : _noUnderline,
    ],
    sparkles: List.filled(PaperLayout.words.length, _noSparkle),
    checks: List.filled(LensTimeline.lineEnds.length, _noCheck),
  );

  /// The paper once the result has arrived: every word read, nothing lit,
  /// no underlines, sparkles or checks.
  static final PaperFrame finished = PaperFrame(
    words: List.filled(PaperLayout.words.length, (lit: 0.0, read: 1.0)),
    underlines: List.filled(PaperLayout.words.length, _noUnderline),
    sparkles: List.filled(PaperLayout.words.length, _noSparkle),
    checks: List.filled(LensTimeline.lineEnds.length, _noCheck),
  );

  /// Per word, in [PaperLayout.words] order.
  final List<WordInk> words;
  final List<Underline> underlines;
  final List<Sparkle> sparkles;

  /// Per line, in [PaperLayout.lineCentres] order.
  final List<Check> checks;

  static const WordInk _unread = (lit: 0, read: 0);
  static const Underline _noUnderline = (opacity: 0, width: 0);
  static const Underline _fullUnderline = (opacity: 1, width: 1);
  static const Sparkle _noSparkle = (scale: 0, degrees: 0, opacity: 0);
  static const Check _noCheck = (scale: 0, opacity: 0);

  /// The sparkle bursts a beat after the lens reaches its word.
  static const double _sparkleDelay = 0.1;

  /// Where in its cycle a reaction started at [startAt] is (0 → 1), or null
  /// before it first starts.
  static double? _phase(double seconds, double startAt) {
    if (seconds < startAt) return null;
    return ((seconds - startAt) % LensTimeline.pass) / LensTimeline.pass;
  }

  /// Teal while the lens is on it, settling to read, fading back to unread
  /// as the pass ends.
  static WordInk _wordInk(double? phase) {
    if (phase == null) return _unread;
    if (phase < 0.06) return (lit: 1, read: 1);
    if (phase < 0.14) return (lit: 1 - _within(phase, 0.06, 0.14), read: 1);
    if (phase < 0.92) return (lit: 0, read: 1);
    return (lit: 0, read: 1 - _within(phase, 0.92, 1));
  }

  static Underline _underline(double? phase) {
    if (phase == null) return _noUnderline;
    if (phase < 0.04) {
      final k = _within(phase, 0, 0.04);
      return (opacity: k, width: k);
    }
    if (phase < 0.92) return _fullUnderline;
    return (opacity: 1 - _within(phase, 0.92, 1), width: 1);
  }

  /// Bursts to 1.3 while turning 45°, then shrinks away through 90°.
  static Sparkle _sparkle(double? phase) {
    if (phase == null || phase >= 0.07) return _noSparkle;
    if (phase < 0.02) {
      final k = _within(phase, 0, 0.02);
      return (scale: 1.3 * k, degrees: 45 * k, opacity: k);
    }
    final k = _within(phase, 0.02, 0.07);
    return (scale: 1.3 * (1 - k), degrees: 45 + 45 * k, opacity: 1 - k);
  }

  /// Pops in past full size, settles, and fades as the pass ends.
  static Check _check(double? phase) {
    if (phase == null) return _noCheck;
    if (phase < 0.03) {
      final k = _within(phase, 0, 0.03);
      return (scale: 1.2 * k, opacity: k);
    }
    if (phase < 0.05) {
      return (scale: 1.2 - 0.2 * _within(phase, 0.03, 0.05), opacity: 1);
    }
    if (phase < 0.94) return (scale: 1, opacity: 1);
    return (scale: 1, opacity: 1 - _within(phase, 0.94, 1));
  }

  static double _within(double phase, double from, double to) =>
      ((phase - from) / (to - from)).clamp(0.0, 1.0);
}
