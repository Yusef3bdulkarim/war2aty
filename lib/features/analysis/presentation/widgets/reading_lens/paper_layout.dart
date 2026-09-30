import 'dart:ui';

/// A word on the drawn paper: a rounded bar with nothing written on it.
final class PaperWord {
  const PaperWord(this.rect, {this.isKey = false});

  final Rect rect;

  /// The one body word the lens pauses on. It keeps a mint underline once
  /// read — a visual beat, never a claim that something was found (F22 #3).
  final bool isKey;
}

/// One of the two boxed fields at the bottom of the paper.
final class PaperField {
  const PaperField({required this.box, required this.label});

  final Rect box;

  /// The small caption bar in the field's top corner.
  final Rect label;
}

/// The geometry of the paper the magnifier reads, in paper units.
///
/// Fixed physical coordinates, not directional ones: the paper is a drawing,
/// and the lens always reads it right to left (the app is Arabic only). The
/// scene scales the whole thing to fit, so these are proportions as much as
/// sizes. From the approved C★ mockup (F22).
abstract final class PaperLayout {
  static const Size size = Size(260, 340);

  static const double cornerRadius = 16;

  /// A circle: the letterhead's mark.
  static const Rect logo = Rect.fromLTWH(212, 20, 30, 30);

  static const Rect title = Rect.fromLTWH(104, 28, 96, 12);

  /// Drawn around [title] once the lens has paused on it.
  static const Rect titleOutline = Rect.fromLTWH(96, 20, 112, 28);

  static const Rect subtitle = Rect.fromLTWH(140, 52, 60, 8);

  static const Rect divider = Rect.fromLTWH(24, 76, 212, 1);

  static const List<PaperField> fields = [
    PaperField(
      box: Rect.fromLTWH(140, 222, 96, 48),
      label: Rect.fromLTWH(196, 229, 32, 6),
    ),
    PaperField(
      box: Rect.fromLTWH(24, 222, 96, 48),
      label: Rect.fromLTWH(80, 229, 32, 6),
    ),
  ];

  static const List<Rect> footer = [
    Rect.fromLTWH(136, 294, 100, 8),
    Rect.fromLTWH(176, 310, 60, 8),
  ];

  /// Where each body line's words sit vertically (their centre), and their
  /// widths from the right margin leftwards.
  static const List<(double, List<double>)> _lines = [
    (104, [46, 30, 54, 40]),
    (140, [30, 56, 34, 44]),
    (176, [52, 28, 46, 36]),
  ];

  static const double _rightMargin = 236;
  static const double _wordGap = 8;
  static const double _wordHeight = 12;

  /// The body words, line by line and right to left, then each field's value.
  static final List<PaperWord> words = [
    for (final (line, (centreY, widths)) in _lines.indexed)
      ..._lineWords(line, centreY, widths),
    const PaperWord(Rect.fromLTWH(150, 243, 60, 10)),
    const PaperWord(Rect.fromLTWH(34, 243, 56, 10)),
  ];

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
          Rect.fromLTWH(
            right - width,
            centreY - _wordHeight / 2,
            width,
            _wordHeight,
          ),
          // The second word of the second line: where the lens pauses.
          isKey: line == 1 && index == 1,
        ),
      );
      right -= width + _wordGap;
    }
    return words;
  }

  /// The size of a review check (a green disc with a tick).
  static const double checkSize = 16;
}
