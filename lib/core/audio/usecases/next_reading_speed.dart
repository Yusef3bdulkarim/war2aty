import '../reading_speed.dart';

final class NextReadingSpeed {
  const NextReadingSpeed();

  ReadingSpeed call(ReadingSpeed current) => switch (current) {
    ReadingSpeed.normal => ReadingSpeed.faster,
    ReadingSpeed.faster => ReadingSpeed.fastest,
    ReadingSpeed.fastest => ReadingSpeed.slower,
    ReadingSpeed.slower => ReadingSpeed.normal,
  };
}
