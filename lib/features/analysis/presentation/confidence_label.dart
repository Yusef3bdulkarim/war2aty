import '../../../core/localization/app_strings.dart';
import '../domain/entities/confidence_band.dart';

/// The caveat to show beside a value of this [band], or `null` when the
/// analysis is sure enough to let the value stand on its own.
///
/// The wording is fixed by API_CONTRACT §30.5 and by UX rule §5.11: an
/// uncertain reading is never shown as fact, and the caveat belongs to the one
/// value it is about — the app never labels a whole document "clear".
String? confidenceLabel(AppStrings strings, ConfidenceBand band) =>
    switch (band) {
      ConfidenceBand.high => null,
      ConfidenceBand.medium => strings.confidenceReview,
      ConfidenceBand.low => strings.confidenceUncertain,
    };
