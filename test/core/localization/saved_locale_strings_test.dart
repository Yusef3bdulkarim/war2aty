import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/localization/saved_locale_strings.dart';

void main() {
  test('English only when the user chose it', () {
    expect(appStringsForSavedLocale('en'), isA<EnStrings>());
  });

  test('Arabic when chosen, and when nothing was ever saved', () {
    expect(appStringsForSavedLocale('ar'), isA<ArStrings>());
    expect(appStringsForSavedLocale(null), isA<ArStrings>());
  });
}
