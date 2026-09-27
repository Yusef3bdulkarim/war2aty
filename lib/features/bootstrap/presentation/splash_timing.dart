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
///
/// ## Why this is 2.6s and not 6s
///
/// Every stage in `PaperPlaneLogo` is a *fraction* of this duration, so the
/// number here decides how long the empty part of the timeline lasts. At 6s the
/// dart spent its first 630ms entirely off-screen (it starts 2.3 logo-widths
/// outside the corner and the painter does not clip), was still under 40px wide
/// at 1.2s, and did not unfold into the page until 3.5s — with the app name at
/// 4.5s and the dots at 5.3s. On a real device that reads as a frozen teal
/// screen, because the launch window, the Android 12+ system splash and the
/// splash's own gradient are all the same colour: there is nothing to tell the
/// user the app has started.
///
/// At 2.6s the same choreography plays out with the first pixel on screen at
/// ~270ms and a clearly readable mark by ~530ms, which is below the point where
/// a wait reads as a hang. The stages are unchanged — only the clock is.
///
/// Raising this again re-introduces the dead opening; if it ever needs to be
/// *lowered* past 2.5s, `splash_screen_test.dart`'s `bootGap` constant has to
/// come down with it, or `kLogoEntranceDuration - bootGap` goes negative.
const Duration kLogoEntranceDuration = Duration(milliseconds: 2600);
