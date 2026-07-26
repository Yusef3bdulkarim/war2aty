import 'package:flutter/widgets.dart';

import 'svg_path.dart';

/// The line icons drawn by [StrokeIcon].
///
/// They live in `core/` because they recur across features — the document
/// kinds appear in onboarding, Home's recent strip, the documents list and
/// result chips; [check] and [shieldCheck] carry the privacy story; the `nav*`
/// glyphs are the bottom bar.
enum StrokeGlyph {
  /// An appointment or booking — a card with two text lines.
  appointment,

  /// A bill — a torn-edge receipt with two text lines.
  invoice,

  /// A government paper — a civic building.
  government,

  /// A school/education paper — a graduation cap.
  education,

  /// A shield with a tick — privacy and safety.
  shieldCheck,

  /// A bare tick, for confirmed points in a list.
  check,

  /// A shield outline on its own — the privacy reassurance line.
  shield,

  /// A camera — the primary "photograph your paper" action.
  camera,

  /// A picture — the "choose from your phone" action.
  gallery,

  /// A clock — the daily usage counter.
  clock,

  /// A chevron pointing toward the start of the line (left in RTL).
  ///
  /// Mirror it for LTR; [StrokeIcon] does not do that for you, since not every
  /// glyph should flip with direction.
  chevronForward,

  navHome,
  navDocuments,
  navReminders,
  navSettings,
}

/// A circle as a path: two same-sweep semicircular arcs.
///
/// The design draws several icons with `<circle>` elements, which have no
/// equivalent in path data — this builds the standard substitute.
String _circle(double cx, double cy, double r) =>
    'M${cx - r} $cy'
    'a$r $r 0 1 0 ${r * 2} 0'
    'a$r $r 0 1 0 ${-r * 2} 0';

/// A rounded `<rect>` as a path, for the same reason as [_circle].
///
/// Walks clockwise from the top-left corner arc: each `a` turns 90° into the
/// next edge.
String _roundedRect(double x, double y, double w, double h, double r) =>
    'M$x ${y + r}'
    'a$r $r 0 0 1 $r ${-r}'
    'h${w - r * 2}'
    'a$r $r 0 0 1 $r $r'
    'v${h - r * 2}'
    'a$r $r 0 0 1 ${-r} $r'
    'h${-(w - r * 2)}'
    'a$r $r 0 0 1 ${-r} ${-r}'
    'z';

/// The document kinds, in the order the onboarding grid shows them.
const List<StrokeGlyph> documentKindGlyphs = [
  StrokeGlyph.appointment,
  StrokeGlyph.invoice,
  StrokeGlyph.government,
  StrokeGlyph.education,
];

/// Each glyph's SVG `d` data, copied verbatim from `Waraqti.dc.html`.
///
/// Kept as strings rather than hand-written [Path] calls so a glyph can be
/// pasted straight out of the design and diffed against it later. All are
/// authored in the design's 24×24 viewBox.
final Map<StrokeGlyph, String> _glyphPaths = {
  // `<rect x=3 y=4 width=18 height=16 rx=3/>` plus two text lines.
  StrokeGlyph.appointment: '${_roundedRect(3, 4, 18, 16, 3)} M8 9h8 M8 13h5',
  StrokeGlyph.invoice: 'M6 3h12v18l-3-2-3 2-3-2-3 2z M9 8h6 M9 12h6',
  StrokeGlyph.government: 'M3 21h18 M5 21V10l7-5 7 5v11 M9 21v-6h6v6',
  StrokeGlyph.education:
      'M22 10 12 5 2 10l10 5 10-5z '
      'M6 12v5c0 1 3 3 6 3s6-2 6-3v-5',
  StrokeGlyph.shieldCheck:
      'M12 3l7 3v5c0 4.5-3 8-7 10-4-2-7-5.5-7-10V6z '
      'M9 12l2 2 4-4',
  StrokeGlyph.check: 'M20 6 9 17l-5-5',
  StrokeGlyph.shield: 'M12 3l7 3v5c0 4.5-3 8-7 10-4-2-7-5.5-7-10V6z',
  // The lens is `<circle cx=12 cy=12.5 r=3.5/>`.
  StrokeGlyph.camera:
      'M3 8a2 2 0 0 1 2-2h1.5l1-2h7l1 2H19a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 '
      '2 0 0 1-2-2z ${_circle(12, 12.5, 3.5)}',
  // `<rect x=3 y=4 .../>`, `<circle cx=8.5 cy=9.5 r=1.5/>`, and the horizon.
  StrokeGlyph.gallery:
      '${_roundedRect(3, 4, 18, 16, 3)} ${_circle(8.5, 9.5, 1.5)} '
      'M21 16l-5-5-9 9',
  // `<circle cx=12 cy=12 r=9/>` plus the hands.
  StrokeGlyph.clock: '${_circle(12, 12, 9)} M12 7v5l3 2',
  StrokeGlyph.chevronForward: 'M15 18l-6-6 6-6',
  StrokeGlyph.navHome: 'M3 10.5 12 3l9 7.5 M5 9.5V20h14V9.5',
  StrokeGlyph.navDocuments:
      'M4 6a2 2 0 0 1 2-2h4l2 2h6a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H6a2 2 0 0 1'
      '-2-2z',
  StrokeGlyph.navReminders:
      'M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9 '
      'M13.7 21a2 2 0 0 1-3.4 0',
  StrokeGlyph.navSettings:
      'M19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 '
      '0 0-2.7 1.1V21a2 2 0 0 1-4 0v-.1A1.6 1.6 0 0 0 7 19.4a1.6 1.6 0 0 0'
      '-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.6 1.6 0 0 0-1.1-2.7H1a2 2 0 0 1 '
      '0-4h.1A1.6 1.6 0 0 0 2.6 7a1.6 1.6 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8'
      '-2.8l.1.1a1.6 1.6 0 0 0 1.8.3H7a1.6 1.6 0 0 0 1-1.5V1a2 2 0 0 1 4 0v.1a'
      '1.6 1.6 0 0 0 2.7 1.1 1.6 1.6 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1'
      '.1a1.6 1.6 0 0 0-.3 1.8V7a1.6 1.6 0 0 0 1.5 1H23a2 2 0 0 1 0 4h-.1a1.6 '
      // The design's separate `<circle cx=12 cy=12 r=3/>`, as the canonical
      // two-semicircle path idiom (both arcs sweeping the same way).
      '1.6 0 0 0-1.5 1z M9 12a3 3 0 1 0 6 0a3 3 0 1 0-6 0',
};

/// Parsed once per glyph — [Path] construction is not free, and these are
/// rebuilt on every frame of a scrolling list otherwise.
final Map<StrokeGlyph, Path> _pathCache = {};

/// The parsed outline of [glyph], in the design's 24×24 coordinate space.
///
/// Public so tests can assert a glyph's geometry directly — a typo in the path
/// data is otherwise invisible until someone looks at the running app.
Path strokeGlyphPath(StrokeGlyph glyph) =>
    _pathCache[glyph] ??= _fitToViewBox(parseSvgPath(_glyphPaths[glyph]!));

/// Shrinks a glyph that is drawn larger than the viewBox so it fits inside it.
///
/// The design's settings gear spans roughly 26×24 inside a 24×24 viewBox, so a
/// browser clips its outer teeth. Clipping here would look like a rendering
/// bug, and letting it overflow would make it visibly larger than its
/// neighbours in the nav bar and able to overlap them — so it is scaled about
/// its centre to fit instead. Glyphs that already fit are returned untouched.
Path _fitToViewBox(Path path) {
  const viewBox = _StrokeIconPainter._viewBox;
  final bounds = path.getBounds();

  final overflow = [
    bounds.width / viewBox,
    bounds.height / viewBox,
    if (bounds.left < 0) 1 - bounds.left / viewBox,
    if (bounds.top < 0) 1 - bounds.top / viewBox,
    if (bounds.right > viewBox) bounds.right / viewBox,
    if (bounds.bottom > viewBox) bounds.bottom / viewBox,
  ].reduce((a, b) => a > b ? a : b);

  if (overflow <= 1) return path;

  const centre = viewBox / 2;
  final scale = 1 / overflow;
  // Scale about the viewBox centre: move the glyph's centre to the origin,
  // shrink, then push it back out to the middle of the box.
  final matrix =
      (Matrix4.identity()
            ..translateByDouble(centre, centre, 0, 1)
            ..scaleByDouble(scale, scale, 1, 1)
            ..translateByDouble(-bounds.center.dx, -bounds.center.dy, 0, 1))
          .storage;

  return path.transform(matrix);
}

/// A stroke icon rendered from the Waraqti design's inline SVG data.
///
/// The design draws its icons as 24×24 outline paths (round caps and joins).
/// They are rendered from their path data rather than pulled in as an icon font
/// or SVG asset: no icon font matches these exact shapes, and an SVG runtime
/// would be a dependency for what amounts to a few dozen small drawings.
///
/// Decorative by default — every place the design uses one, a text label sits
/// beside it, so the icon is hidden from assistive technology unless the caller
/// passes a [semanticLabel].
class StrokeIcon extends StatelessWidget {
  const StrokeIcon(
    this.glyph, {
    required this.color,
    this.size = 24,
    this.strokeWidth = 1.8,
    this.semanticLabel,
    super.key,
  });

  final StrokeGlyph glyph;
  final Color color;
  final double size;

  /// Stroke width in the design's 24×24 coordinate space. Like an SVG, it is
  /// scaled along with the artwork, so a glyph drawn small gets a thinner line.
  final double strokeWidth;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final icon = CustomPaint(
      size: Size.square(size),
      painter: _StrokeIconPainter(
        glyph: glyph,
        color: color,
        strokeWidth: strokeWidth,
      ),
    );

    return semanticLabel == null
        ? ExcludeSemantics(child: icon)
        : Semantics(label: semanticLabel, image: true, child: icon);
  }
}

class _StrokeIconPainter extends CustomPainter {
  const _StrokeIconPainter({
    required this.glyph,
    required this.color,
    required this.strokeWidth,
  });

  /// The design's SVG viewBox; all glyph data is authored in these coordinates.
  static const double _viewBox = 24;

  final StrokeGlyph glyph;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.shortestSide / _viewBox);

    canvas.drawPath(
      strokeGlyphPath(glyph),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_StrokeIconPainter old) =>
      old.glyph != glyph ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
