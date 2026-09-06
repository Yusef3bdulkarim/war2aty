/// Timing shared between the splash animation and the launch sequence.
///
/// It lives on its own so the composition root can wire the launch hold without
/// importing the widget that draws the mark.
library;

/// How long the splash entrance takes to play out end to end.
///
/// Single source of truth: the splash's animation controller runs for exactly
/// this long, and the launch hold's escape hatch is derived from it, so the mark
/// and the launch sequence can never drift apart.
const Duration kLogoEntranceDuration = Duration(milliseconds: 6000);
