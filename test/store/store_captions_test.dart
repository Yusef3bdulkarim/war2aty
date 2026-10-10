import 'package:flutter_test/flutter_test.dart';

import 'store_captions.dart';

/// F27-T21 · The Play Store taglines are user-facing copy, and are held to the
/// same rules as the app's own.
void main() {
  String all(StoreCaption c) => '${c.headline} ${c.subline}';

  test("there are eight, in the listing's order", () {
    // Play takes at most eight phone screenshots. The sequence follows the
    // owner's device screenshots (2026-10-10); a reorder is a change to ask
    // about, not to slip in.
    expect(kStoreCaptions.map((c) => c.file), [
      '1-home',
      '2-reading',
      '3-result',
      '4-reminder',
      '5-reminders',
      '6-listen',
      '7-papers',
      '8-privacy',
    ]);
  });

  test('no tagline claims the photo or the text goes unseen (§7)', () {
    // The same retired claims `app_strings_test` and `legal_pages_test` ban.
    const banned = [
      'محدش بيشوف',
      'محدش بيقرا',
      'مايشوفهاش حد',
      'مايقراهوش حد',
      'مش بتطلع من الموبايل',
      'متطلعش من الموبايل',
    ];
    for (final caption in kStoreCaptions) {
      for (final phrase in banned) {
        expect(all(caption), isNot(contains(phrase)), reason: caption.file);
      }
    }
  });

  test('no tagline names a provider (§7)', () {
    const providers = [
      'Azure',
      'Google',
      'Gemini',
      'Mistral',
      'Groq',
      'OpenAI',
    ];
    for (final caption in kStoreCaptions) {
      for (final name in providers) {
        expect(
          all(caption).toLowerCase(),
          isNot(contains(name.toLowerCase())),
          reason: caption.file,
        );
      }
    }
  });

  test('no tagline makes a claim Google asks screenshots not to make', () {
    // Play's screenshot guidelines: avoid content suggesting store
    // performance, rankings, testimonials or pricing. «مجاني» is pricing.
    const promotional = ['مجان', 'الأفضل', 'أفضل', 'رقم 1', '#1', 'الأول'];
    for (final caption in kStoreCaptions) {
      for (final word in promotional) {
        expect(all(caption), isNot(contains(word)), reason: caption.file);
      }
    }
  });

  test('every tagline has a headline and a line under it', () {
    for (final caption in kStoreCaptions) {
      expect(caption.headline.trim(), isNotEmpty, reason: caption.file);
      expect(caption.subline.trim(), isNotEmpty, reason: caption.file);
    }
  });
}
