/// The two final steps both tiers' spans are built with (F37-T07, F37-T18).
///
/// Extracted when T18 needed the second of them. The two tiers place a segment
/// on the timeline from entirely different evidence — Gemini Live matches the
/// service's own transcription against a byte count, device TTS reads the
/// engine's word-boundary offsets against a clock — but both then interpolate
/// what they could not measure, and both have to hand F40 a **partition**.
///
/// That invariant is why this is one implementation rather than a copy in each
/// tier: F40 relies on there being exactly one answer to "which card is being
/// read now", and two copies of the rule could drift into the fallback tier
/// highlighting differently from the primary one.
///
/// Pure arithmetic over integers and ids. Nothing here knows about an engine,
/// an audio format or a page.
library;

import 'dart:math' as math;

import '../entities/spoken_card_span.dart';

/// Linear interpolation of [ys] at [x] over the non-decreasing [xs].
///
/// [xs] and [ys] must be the same length and non-decreasing; outside [xs] the
/// nearest end of [ys] is returned rather than extrapolated, because beyond the
/// known points there is no evidence to extrapolate from.
int interpolateAt(List<int> xs, List<int> ys, int x) {
  if (x <= xs.first) return ys.first;
  if (x >= xs.last) return ys.last;
  var hi = 1;
  while (hi < xs.length - 1 && xs[hi] < x) {
    hi++;
  }
  final lo = hi - 1;
  final run = xs[hi] - xs[lo];
  if (run <= 0) return ys[hi];
  return ys[lo] + (x - xs[lo]) * (ys[hi] - ys[lo]) ~/ run;
}

/// Turns per-segment start times into a partition of the read.
///
/// The first segment starts with the read by construction, each span ends where
/// the next begins, and the last ends at [totalMicros] — so a position anywhere
/// in the read belongs to exactly one segment, and the pause between two cards
/// belongs to the card before it rather than to nothing.
///
/// The monotonic clamp is a guard, not an expectation: a caller that placed its
/// segments out of order gets a degenerate zero-length span rather than a span
/// that runs backwards. A zero-length span is possible where two segments were
/// placed at the same instant, and `SpokenCardSpan.contains` is false
/// throughout it, which is the honest outcome.
///
/// [exact] is carried through untouched — whether a placement was measured is
/// the caller's knowledge, not this function's.
List<SpokenCardSpan> partitionSpans({
  required List<String> segmentIds,
  required List<int> startMicros,
  required List<bool> exact,
  required int totalMicros,
}) {
  final ordered = List<int>.filled(segmentIds.length, 0);
  var previous = 0;
  for (var i = 0; i < segmentIds.length; i++) {
    previous = i == 0
        ? 0
        : math.min(math.max(startMicros[i], previous), totalMicros);
    ordered[i] = previous;
  }

  return List<SpokenCardSpan>.generate(segmentIds.length, (i) {
    final end = i == segmentIds.length - 1 ? totalMicros : ordered[i + 1];
    return SpokenCardSpan(
      segmentId: segmentIds[i],
      start: Duration(microseconds: ordered[i]),
      end: Duration(microseconds: math.max(ordered[i], end)),
      exact: exact[i],
    );
  });
}

/// Which segment [position] falls in, or `null` when no span covers it.
///
/// `null` is not an error and is not "no segment": it is "nothing placed here
/// yet" — the read is before the spans resolved, or the position fell in a gap
/// a degenerate span left — and a position event carrying `null` asks the
/// screen to hold the highlight it has rather than clear it.
///
/// Shared by the two things that have to answer "which card is being spoken
/// now" from a resolved partition: the tier ladder while a paper is being read,
/// and the replay of a saved one (CLAUDE.md §2).
String? segmentAt(List<SpokenCardSpan> spans, Duration position) {
  for (final span in spans) {
    if (span.contains(position)) return span.segmentId;
  }
  return null;
}
