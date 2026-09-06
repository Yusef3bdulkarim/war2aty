import '../localization/app_strings.dart';

/// A money figure read off a paper — `750 جنيه`, `250.50 جنيه`.
///
/// Whole pounds are written without a decimal part, the way a bill prints
/// them; anything with piastres keeps both digits so `250.5` never reads as
/// two hundred and fifty pounds five.
///
/// [currency] is the code the analysis reported. An unknown one is shown as it
/// arrived rather than dropped: the number on the paper still means something
/// with an unfamiliar code beside it, and nothing with none.
String formatDocumentAmount(AppStrings s, double value, String currency) {
  final isWhole = value == value.roundToDouble();
  final amount = isWhole ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

  return '$amount ${s.currencyName(currency)}';
}
