import 'package:flutter/material.dart';

import 'caveat_badge.dart';

// The owner's result-screen review (F21 locked decision #1).
const double _chipGap = 8;
const double _runGap = 6;

/// A value with its cautions beside it — «راجع المعلومة», «قراءة غير مؤكدة»,
/// «استنتاج من محتوى الورقة» — as compact chips on the value's own line.
///
/// Always visible words, never a tap-only hint: an uncertain reading must not
/// look like fact at first glance (UX rules §5.11 and §5.16, CLAUDE.md §7).
/// The chips wrap under the value when the line has no room for them (Large
/// Text, a long value), rather than squeezing either.
///
/// With no [caveats] this is just the value.
class CaveatedValue extends StatelessWidget {
  const CaveatedValue({required this.value, required this.caveats, super.key});

  /// The value as the row styles it.
  final Widget value;

  /// Zero or more cautions, each its own chip, announced as its own sentence
  /// after the value.
  final List<String> caveats;

  @override
  Widget build(BuildContext context) {
    if (caveats.isEmpty) return value;

    return Wrap(
      spacing: _chipGap,
      runSpacing: _runGap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        value,
        for (final caveat in caveats) CaveatBadge(text: caveat),
      ],
    );
  }
}
