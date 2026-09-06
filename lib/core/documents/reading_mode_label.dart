import '../localization/app_strings.dart';
import 'reading_mode.dart';

/// What to call [mode] on screen — the mini-player's option rows and its
/// «بيقرأ: …» line share this rather than each switching on the enum
/// themselves.
///
/// A function rather than an extension on the enum: [ReadingMode] lives in
/// the domain, which must not reach for localization (or anything else
/// outside itself).
String readingModeLabel(AppStrings strings, ReadingMode mode) => switch (mode) {
  ReadingMode.summaryOnly => strings.audioReaderModeSummary,
  ReadingMode.summaryAndKeyInformation =>
    strings.audioReaderModeSummaryAndKeyInformation,
  ReadingMode.fullExplanation => strings.audioReaderModeFull,
  ReadingMode.readAll => strings.audioReaderModeReadAll,
  ReadingMode.extractedText => strings.audioReaderModeExtractedText,
};
