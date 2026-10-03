import 'app_strings.dart';
import 'ar_strings.dart';
import 'en_strings.dart';

/// The strings for a saved language code, for text built outside the widget
/// tree — an OS notification, its buttons — where there is no
/// `context.strings` to read. Arabic unless the user chose English, the same
/// default the app itself launches in.
AppStrings appStringsForSavedLocale(String? languageCode) =>
    languageCode == 'en' ? const EnStrings() : const ArStrings();
