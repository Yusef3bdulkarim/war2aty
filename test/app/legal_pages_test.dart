import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// F27-T20 · The public policy pages, under the same §7 rules as the app's own
/// copy.
///
/// `app_strings_test` enforces the privacy contract on every string in
/// `AppStrings`, and `native_permission_copy_test` does it for the native
/// permission prompts. The pages at the public URL are the third surface, and
/// the one a store reviewer and every user actually reads — they say far more
/// than the four in-app promises, in HTML nothing in `lib/` imports, so nothing
/// in this suite would notice them drifting.
///
/// The rules are not about tone. Each one is a claim the app is **not
/// permitted to make** because it would be false:
///
/// - The photo goes to an outside reader on a free tier that may keep it for a
///   while and let staff review it (F20-T24), so "nobody sees it" is false,
///   and an unscoped "not saved" is false too.
/// - The extracted text goes to an analysis provider on a free tier that
///   permits content review (F18-T02), so "nobody reads it" is false.
/// - No provider may be named, in any user-facing text (§7).
///
/// The last group is the publish gate: the pages carry two values only the
/// owner can supply, and they must not reach a public URL as placeholders.
void main() {
  /// The pages, with every run of whitespace collapsed to one space.
  ///
  /// Without this, every phrase assertion below is a coin toss: the HTML wraps
  /// sentences across lines with indentation, so «ممكن تحتفظ بيها فترة» is
  /// broken by a newline and an indent on disk, so a plain `contains` fails on
  /// copy that is perfectly correct. Collapsing reads the text the way a
  /// browser renders it, which is the thing being asserted about.
  final pages = {
    for (final name in const ['index.html', 'privacy.html', 'terms.html'])
      name: File(
        'legal/$name',
      ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' '),
  };

  group('the policy pages exist and are what they claim to be', () {
    test('all three pages and the stylesheet are present', () {
      for (final MapEntry(key: name, value: html) in pages.entries) {
        expect(html, isNotEmpty, reason: 'legal/$name is empty');
        expect(
          html,
          contains('<!doctype html>'),
          reason: 'legal/$name must be a complete document',
        );
      }
      expect(File('legal/style.css').existsSync(), isTrue);
    });

    test('they are Arabic and right-to-left', () {
      // The audience is Egyptian, and the app is RTL throughout. A policy page
      // that renders left-to-right is unreadable for the reader it is for.
      for (final MapEntry(key: name, value: html) in pages.entries) {
        expect(
          html,
          contains('<html lang="ar" dir="rtl">'),
          reason: 'legal/$name must open as an Arabic RTL document',
        );
      }
    });

    test('each page links to the other two', () {
      // A store reviewer lands on one of them; both others have to be
      // reachable from it, or the terms page effectively does not exist.
      expect(pages['index.html'], contains('privacy.html'));
      expect(pages['index.html'], contains('terms.html'));
      expect(pages['privacy.html'], contains('terms.html'));
      expect(pages['terms.html'], contains('privacy.html'));
    });
  });

  group('the pages tell the truth about the photo and the text (§7)', () {
    test('no page claims the photo or the text goes unseen', () {
      const bannedArabic = [
        'محدش بيشوفها', // the photo — retired by F20-T24
        'محدش بيشوفه', // the text — retired by F18-T02
        'محدش بيقرا',
        'مايشوفهاش حد',
        'مايقراهوش حد',
      ];
      const bannedEnglish = [
        'nobody sees',
        'no one sees',
        'nobody reads',
        'no one reads',
        'no person ever sees',
      ];

      for (final MapEntry(key: name, value: html) in pages.entries) {
        for (final phrase in bannedArabic) {
          expect(
            html,
            isNot(contains(phrase)),
            reason: 'legal/$name: «$phrase» is a claim the app cannot keep',
          );
        }
        for (final phrase in bannedEnglish) {
          expect(
            html.toLowerCase(),
            isNot(contains(phrase)),
            reason: 'legal/$name: "$phrase" is a claim the app cannot keep',
          );
        }
      }
    });

    test(
      'the photo paragraph states both halves, not just the comfortable one',
      () {
        // "We don't keep it" on its own reads as a promise about the whole
        // journey. It is only true of our own servers, so the retention and
        // human review at the outside reader have to be on the same page.
        final privacy = pages['privacy.html']!;
        expect(privacy, contains('مابنحفظش الصورة'));
        expect(privacy, contains('ممكن تحتفظ بيها فترة'));
        expect(privacy, contains('يراجعها موظفين'));
        expect(privacy, contains('على موبايلك بس'));

        final english = privacy.toLowerCase();
        expect(english, contains("we don't keep the photo"));
        expect(english, contains('keep content for a while'));
        expect(english, contains('staff review it'));
        expect(privacy, contains('مانقدرش نضمنلك إن الصورة'));
        expect(english, contains('we cannot promise the photo stays unseen'));
      },
    );

    test('the text paragraph says both what we promise and what we cannot', () {
      final privacy = pages['privacy.html']!;
      expect(privacy, contains('مانحفظش النص عندنا'));
      // Stated positively rather than by quoting the claim it denies: a page
      // that prints «محدش بيقرا» in order to deny it still prints it, and the
      // guard above cannot tell a denial from an assertion. The app's own
      // copy manages without the quote, so the page does too.
      expect(privacy, contains('مانقدرش نضمنلك إن النص'));
      expect(
        privacy.toLowerCase(),
        contains('we cannot promise the text goes unread'),
      );
    });

    test('saving on the phone is scoped to consent, never stated unscoped', () {
      // «مش هتتحفظ» without «على موبايلك» would read as "never saved
      // anywhere", which is not what happens online.
      final privacy = pages['privacy.html']!;
      expect(privacy, contains('الصورة مش هتتحفظ على موبايلك إلا بعد موافقتك'));
    });

    test('no page names a provider', () {
      // §7, binding since F13-T18 and the reason the in-app copy says "an
      // outside service" rather than who it is.
      const providers = [
        'azure',
        'gemini',
        'mistral',
        'groq',
        'openai',
        'tesseract',
        'supabase',
      ];

      for (final MapEntry(key: name, value: html) in pages.entries) {
        final lower = html.toLowerCase();
        for (final provider in providers) {
          expect(
            lower,
            isNot(contains(provider)),
            reason: 'legal/$name must not name $provider',
          );
        }
      }
    });
  });

  group('the pages say what the app actually does', () {
    test('the terms carry the disclaimer M5 asked for', () {
      // The audit finding (M5) is specifically that no page says this. The app
      // reads court notices, lab results and bills; a user acting on a
      // misread number is the worst outcome it has.
      final terms = pages['terms.html']!;
      expect(terms, contains('مش استشارة قانونية'));
      expect(terms, contains('ولا طبية'));
      expect(terms, contains('ولا مالية'));
      expect(terms, contains('راجع الورقة الأصلية'));

      final english = terms.toLowerCase();
      expect(english, contains('not legal, medical, financial or tax advice'));
    });

    test('the retention windows match the ones actually implemented', () {
      // 90 days for attempts and error reports, 12 months for an idle
      // anonymous identifier — `supabase/migrations/20261006100000` and
      // `20261006150000`. A policy that states a different number is a false
      // statement about the system, not a drafting choice.
      final privacy = pages['privacy.html']!;
      expect(privacy, contains('90 يوم'));
      expect(privacy, contains('12 شهر'));
      expect(privacy.toLowerCase(), contains('90 days'));
      expect(privacy.toLowerCase(), contains('12 months'));
    });

    test('the daily limit matches the runtime config', () {
      // `daily_limit` is 3 in `20260726124644_create_runtime_config.sql`.
      expect(pages['terms.html'], contains('3 تحليلات ناجحة في اليوم'));
    });

    test('the deletion routes are the ones the app really offers', () {
      // Every one of these is a real row in the settings screen; a policy
      // promising a control that does not exist is worse than silence.
      final privacy = pages['privacy.html']!;
      for (final control in const [
        'حذف كل المستندات',
        'حذف كل التذكيرات',
        'حذف كل بيانات التطبيق',
      ]) {
        expect(
          privacy,
          contains(control),
          reason: '$control is a real settings row and should be named',
        );
      }
    });

    test('the permissions named are the ones the app requests', () {
      // Camera and notifications are the only two runtime permissions
      // `PermissionHandlerService` maps. The microphone was removed in
      // T16, and saying so is worth more than silence for an app that
      // photographs private documents.
      final privacy = pages['privacy.html']!;
      expect(privacy, contains('الكاميرا'));
      expect(privacy, contains('الإشعارات'));
      expect(privacy, contains('الميكروفون مش مطلوب ولا مستخدم'));
    });
  });

  group('the age the documents state is the one the owner chose', () {
    // 15 and over (owner, 2026-10-08). The privacy page, the terms and the
    // Play Console instructions each state it; a mismatch between what the
    // listing declares and what the policy says is exactly what a reviewer
    // compares, so all three are held to the same number here.
    test('the privacy page says 15 and over, in both languages', () {
      final privacy = pages['privacy.html']!;
      expect(privacy, contains('15 سنة فأكتر'));
      expect(privacy.toLowerCase(), contains('aged 15 and over'));
    });

    test('the terms make it a condition of use, in both languages', () {
      final terms = pages['terms.html']!;
      expect(terms, contains('15 سنة أو أكتر'));
      expect(terms.toLowerCase(), contains('aged 15'));
    });

    test('both ask an under-18 to use it with a guardian', () {
      for (final name in const ['privacy.html', 'terms.html']) {
        expect(pages[name], contains('بمعرفة ولي أمرك'), reason: name);
        expect(
          pages[name]!.toLowerCase(),
          contains("parent's or guardian's knowledge"),
          reason: name,
        );
      }
    });

    test('no page still states the old age of 13', () {
      for (final MapEntry(key: name, value: html) in pages.entries) {
        expect(html, isNot(contains('تحت 13')), reason: name);
        expect(html.toLowerCase(), isNot(contains('under 13')), reason: name);
      }
    });

    test('the console instructions declare the same audience', () {
      // Play has no 15+ band, so the instructions map it to the narrowest
      // set that declares nobody under 15. If they drift from the pages,
      // this fails rather than the store review.
      final console = File(
        'docs/features/F27-T21-play-console.md',
      ).readAsStringSync();
      expect(console, contains('15 and over'));
      expect(console, contains('**16–17** and **18 and over**'));
    });
  });

  group('each document says which version it is', () {
    // The first release ships version 1.0 of both documents. Stating it is
    // what makes a later change visible: without a number and an effective
    // date, an edited policy looks identical to the one a user agreed to.
    for (final name in const ['privacy.html', 'terms.html']) {
      test(
        '$name states version 1.0 and its effective date, in both languages',
        () {
          final html = pages[name]!;
          expect(html, contains('الإصدار الأول (1.0)'));
          expect(html, contains('ساري من 8 أكتوبر 2026'));
          expect(html, contains('Version 1.0'));
          expect(html, contains('effective 8 October 2026'));
        },
      );

      test('$name promises a new version, not a silently edited date', () {
        // «آخر تحديث» invited exactly the edit-in-place this rules out.
        final html = pages[name]!;
        expect(html, isNot(contains('آخر تحديث')));
        expect(html.toLowerCase(), isNot(contains('last updated')));
        expect(html, contains('هننشر إصدار جديد'));
        expect(html, contains('publish a new version'));
      });
    }
  });

  group('publish gate: nothing reaches the public URL as a placeholder', () {
    // These two values are the owner's to give (Q17: the company as developer
    // of record, and the support address). Until they land, the pages are
    // drafts — and a draft with «TODO_OWNER_COMPANY» printed where the
    // responsible party should be is worse than no page at all, because it is
    // published and wrong.
    test('no page still carries an owner placeholder', () {
      for (final MapEntry(key: name, value: html) in pages.entries) {
        expect(
          html,
          isNot(contains('TODO_OWNER_')),
          reason:
              'legal/$name still has a placeholder: fill the company name and '
              'the support address before GitHub Pages is enabled (F27-T20)',
        );
      }
    });

    test('every page names the responsible party and a way to reach it', () {
      // Both stores ask who is behind the app and how a user contacts them,
      // and a user who lands on the terms page alone must not have to hunt.
      for (final MapEntry(key: name, value: html) in pages.entries) {
        expect(
          html,
          contains('war2aty.support@gmail.com'),
          reason: 'legal/$name must carry the support address',
        );
        expect(
          html,
          contains('كيان وطموح'),
          reason: 'legal/$name must name the company that operates the app',
        );
      }
    });

    test('the support address is a mailto link, not just text', () {
      // The in-app support row opens it with url_launcher; on the page a
      // reader should be able to tap it too.
      for (final MapEntry(key: name, value: html) in pages.entries) {
        expect(
          html,
          contains('href="mailto:war2aty.support@gmail.com"'),
          reason: 'legal/$name should make the address tappable',
        );
      }
    });
  });
}
