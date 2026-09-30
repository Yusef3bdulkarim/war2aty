import 'dart:ui';

/// A word on the drawn paper: a rounded bar with nothing written on it.
final class PaperWord {
  const PaperWord(this.rect, {this.isKey = false});

  final Rect rect;

  /// One of the two words the lens pauses on. It gets a mint underline and a
  /// sparkle as the lens reaches it — a visual beat, never a claim that
  /// something was found (F22 #3).
  final bool isKey;
}

/// The geometry of the paper the magnifier reads, in paper units.
///
/// Fixed physical coordinates, not directional ones: the paper is a drawing,
/// and the lens always reads it right to left (the app is Arabic only). The
/// scene scales the whole thing to fit, so these are proportions as much as
/// sizes. From the approved C+ mockup (F22 #18).
abstract final class PaperLayout {
  static const Size size = Size(260, 360);

  static const double cornerRadius = 16;

  /// A circle: the letterhead's mark, with a bolt in it.
  static const Rect logo = Rect.fromLTWH(206, 20, 30, 30);

  static const Rect title = Rect.fromLTWH(100, 22, 96, 12);

  static const Rect subtitle = Rect.fromLTWH(136, 40, 60, 8);

  static const Rect divider = Rect.fromLTWH(24, 66, 212, 1);

  /// The boxed field at the bottom; its label and value are the last line of
  /// [words].
  static const Rect field = Rect.fromLTWH(24, 248, 212, 44);

  static const double fieldRadius = 10;

  /// A faint round stamp in the bottom corner, drawn tilted.
  static const Rect stamp = Rect.fromLTWH(30, 304, 42, 42);

  static const double stampTiltDegrees = -12;

  static const Rect footer = Rect.fromLTWH(150, 318, 86, 8);

  /// Where each line's words sit vertically (their centre): the four body
  /// lines, then the field's line.
  static const List<double> lineCentres = [96, 138, 180, 222, 270];

  /// The body lines' word widths, from the right margin leftwards.
  static const List<List<double>> _bodyLines = [
    [44, 30, 52, 36],
    [28, 60, 34, 40],
    [50, 26, 44, 38],
    [36, 48, 30, 52],
  ];

  static const double _rightMargin = 236;
  static const double _wordGap = 8;
  static const double wordHeight = 12;

  /// The body words, line by line and right to left, then the field's label
  /// and value.
  static final List<PaperWord> words = [
    for (final (line, widths) in _bodyLines.indexed)
      ..._lineWords(line, lineCentres[line], widths),
    PaperWord(_wordAt(178, lineCentres[4], 48)),
    PaperWord(_wordAt(34, lineCentres[4], 64), isKey: true),
  ];

  /// The line each of [words] is on, in the same order.
  static final List<int> wordLines = [
    for (final (line, widths) in _bodyLines.indexed)
      for (final _ in widths) line,
    4,
    4,
  ];

  static Rect _wordAt(double left, double centreY, double width) =>
      Rect.fromLTWH(left, centreY - wordHeight / 2, width, wordHeight);

  static List<PaperWord> _lineWords(
    int line,
    double centreY,
    List<double> widths,
  ) {
    final words = <PaperWord>[];
    var right = _rightMargin;
    for (final (index, width) in widths.indexed) {
      words.add(
        PaperWord(
          _wordAt(right - width, centreY, width),
          // The second word of the second line: where the lens pauses.
          isKey: line == 1 && index == 1,
        ),
      );
      right -= width + _wordGap;
    }
    return words;
  }

  /// The mint underline under a key word.
  static Rect underlineOf(Rect word) =>
      Rect.fromLTWH(word.left, word.top + 16, word.width, 4);

  /// The centre of a key word's sparkle: above the word and to the right of
  /// it, where the lens has just come from, so the glass does not hide it.
  static Offset sparkleOf(Rect word) =>
      Offset(word.center.dx + 31, word.center.dy - 35);

  static const double sparkleSize = 18;

  /// The size of a review check (a green disc with a tick), and the left
  /// edge they share, in the margin beside each line.
  static const double checkSize = 16;
  static const double checkLeft = 6;
}
