import 'dart:ui';

/// Builds a [Path] from an SVG `d` attribute.
///
/// The Waraqti design ships every icon as an inline SVG. Transcribing those
/// paths into `Path` calls by hand is slow and easy to get subtly wrong —
/// especially arcs and the "smooth" curve commands, whose first control point
/// is implied rather than written. Parsing the string instead means an icon can
/// be pasted verbatim from the design and is far harder to get wrong.
///
/// Supports the full path grammar the design uses: `M L H V C S Q T A Z`, in
/// both absolute (uppercase) and relative (lowercase) form, including repeated
/// parameter sets after a single command letter.
///
/// One known limitation: arc flags must be separated from the numbers around
/// them (`a2 2 0 1 1-3 2`, as the design writes them). SVG also permits them
/// glued together (`a2 2 0 11-3 2`); that compact form is not parsed.
Path parseSvgPath(String d) {
  // Catch stray characters up front. Without this the tokenizer would simply
  // skip an unrecognised letter and silently draw a subtly wrong shape, which
  // is far harder to notice than an outright failure.
  final stray = _strayPattern.firstMatch(d);
  if (stray != null) {
    throw FormatException('Unexpected character "${stray[0]}" in SVG path', d);
  }

  final path = Path();

  // Sub-path start, current point, and the previous curve's second control
  // point — the last of these is what makes `S`/`T` reflection possible.
  var start = Offset.zero;
  var current = Offset.zero;
  Offset? lastCubicControl;
  Offset? lastQuadControl;

  for (final (command, args) in _tokenize(d)) {
    final relative = command.toLowerCase() == command;
    final op = command.toUpperCase();

    // Resolves a coordinate pair against the current point when relative.
    Offset point(double x, double y) =>
        relative ? current + Offset(x, y) : Offset(x, y);

    var i = 0;
    // A command letter may be followed by several parameter sets; each loop
    // consumes one set. `M` is special: extra sets are implicit line-tos.
    var first = true;

    while (i < args.length || (first && args.isEmpty)) {
      switch (op) {
        case 'M':
          final target = point(args[i], args[i + 1]);
          if (first) {
            path.moveTo(target.dx, target.dy);
            start = target;
          } else {
            path.lineTo(target.dx, target.dy);
          }
          current = target;
          lastCubicControl = lastQuadControl = null;
          i += 2;

        case 'L':
          final target = point(args[i], args[i + 1]);
          path.lineTo(target.dx, target.dy);
          current = target;
          lastCubicControl = lastQuadControl = null;
          i += 2;

        case 'H':
          final x = relative ? current.dx + args[i] : args[i];
          path.lineTo(x, current.dy);
          current = Offset(x, current.dy);
          lastCubicControl = lastQuadControl = null;
          i += 1;

        case 'V':
          final y = relative ? current.dy + args[i] : args[i];
          path.lineTo(current.dx, y);
          current = Offset(current.dx, y);
          lastCubicControl = lastQuadControl = null;
          i += 1;

        case 'C':
          final c1 = point(args[i], args[i + 1]);
          final c2 = point(args[i + 2], args[i + 3]);
          final end = point(args[i + 4], args[i + 5]);
          path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
          current = end;
          lastCubicControl = c2;
          lastQuadControl = null;
          i += 6;

        case 'S':
          // The implied control point is the previous one mirrored about the
          // current point; with no previous cubic it collapses onto it.
          final c1 = _reflect(lastCubicControl, current);
          final c2 = point(args[i], args[i + 1]);
          final end = point(args[i + 2], args[i + 3]);
          path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
          current = end;
          lastCubicControl = c2;
          lastQuadControl = null;
          i += 4;

        case 'Q':
          final c = point(args[i], args[i + 1]);
          final end = point(args[i + 2], args[i + 3]);
          path.quadraticBezierTo(c.dx, c.dy, end.dx, end.dy);
          current = end;
          lastQuadControl = c;
          lastCubicControl = null;
          i += 4;

        case 'T':
          final c = _reflect(lastQuadControl, current);
          final end = point(args[i], args[i + 1]);
          path.quadraticBezierTo(c.dx, c.dy, end.dx, end.dy);
          current = end;
          lastQuadControl = c;
          lastCubicControl = null;
          i += 2;

        case 'A':
          // SVG's arc parameters map one-to-one onto `arcToPoint`, so no
          // endpoint-to-centre conversion is needed.
          final end = point(args[i + 5], args[i + 6]);
          path.arcToPoint(
            end,
            radius: Radius.elliptical(args[i], args[i + 1]),
            rotation: args[i + 2],
            largeArc: args[i + 3] != 0,
            clockwise: args[i + 4] != 0,
          );
          current = end;
          lastCubicControl = lastQuadControl = null;
          i += 7;

        case 'Z':
          path.close();
          current = start;
          lastCubicControl = lastQuadControl = null;

        default:
          throw FormatException('Unsupported SVG path command "$command"');
      }

      first = false;
      if (op == 'Z') break;
    }
  }

  return path;
}

/// Mirrors [control] about [current]; returns [current] when there is none.
Offset _reflect(Offset? control, Offset current) =>
    control == null ? current : current * 2 - control;

final RegExp _commandPattern = RegExp('[MmLlHhVvCcSsQqTtAaZz]');

/// Anything that is neither a supported command, a number, nor a separator.
final RegExp _strayPattern = RegExp(r'[^MmLlHhVvCcSsQqTtAaZz0-9eE.,+\-\s]');
final RegExp _numberPattern = RegExp(r'-?\d*\.?\d+(?:[eE][-+]?\d+)?');

/// Splits a `d` string into (command letter, numbers) pairs.
Iterable<(String, List<double>)> _tokenize(String d) sync* {
  final matches = _commandPattern.allMatches(d).toList();

  for (var index = 0; index < matches.length; index++) {
    final match = matches[index];
    final end = index + 1 < matches.length
        ? matches[index + 1].start
        : d.length;
    final args = _numberPattern
        .allMatches(d.substring(match.end, end))
        .map((m) => double.parse(m[0]!))
        .toList();

    yield (match[0]!, args);
  }
}
