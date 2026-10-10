/// The taglines printed above each Play Store screenshot (F27-T21).
///
/// Data only, in a file of its own, for one reason: these are user-facing
/// words in a public listing, so the privacy contract (CLAUDE.md §7) binds
/// them exactly as it binds `AppStrings`. `store_captions_test.dart` enforces
/// it — and, unlike the generator that renders them, that test runs in the
/// suite.
///
/// Order is the listing's order. [StoreCaption.file] names both the owner's
/// device screenshot in `store/screenshots/raw/` (gitignored — see
/// `generate_store_assets.dart`) and the framed result in
/// `store/screenshots/ar/`. Play shows screenshots in upload order.
library;

/// One screenshot's tagline: a short headline and the line under it.
final class StoreCaption {
  const StoreCaption(this.file, this.headline, this.subline);

  /// The screenshot's file name, without the extension.
  final String file;

  final String headline;
  final String subline;
}

const List<StoreCaption> kStoreCaptions = [
  StoreCaption(
    '1-home',
    'عندك ورقة مش فاهمها؟',
    'صوّرها، والتطبيق يشرحهالك بكلام بسيط',
  ),
  StoreCaption(
    '2-reading',
    'التطبيق بيقرا ورقتك',
    'ويطلّعلك المهم فيها بالعربي',
  ),
  StoreCaption(
    '3-result',
    'اعرف ورقتك بتقول إيه',
    'المطلوب منك، وآخر ميعاد، والمبلغ',
  ),
  StoreCaption(
    '4-reminder',
    'متفوّتش ميعاد',
    'تذكير بالموعد، بتظبطه انت بنفسك',
  ),
  StoreCaption(
    '5-reminders',
    'كل مواعيدك قدامك',
    'القادمة والفائتة واللي خلصت',
  ),
  StoreCaption(
    '6-listen',
    'اسمع الشرح بصوت عالي',
    'لو القراية صعبة، التطبيق يقرالك',
  ),
  StoreCaption('7-papers', 'ورقك كله في مكان واحد', 'محفوظ على موبايلك انت'),
  StoreCaption(
    '8-privacy',
    'انت اللي بتتحكم',
    'توقف إرسال النص أو تحذف بياناتك في أي وقت',
  ),
];
