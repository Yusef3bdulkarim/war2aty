/// Spacing scale derived from the Waraqti design's layout rhythm.
///
/// The design leans on a 4-based scale with 16 as the dominant content unit
/// (screen horizontal padding is 16). Use these tokens instead of raw numbers.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Standard horizontal padding for a screen's content.
  static const double screenHorizontal = 16;
}
