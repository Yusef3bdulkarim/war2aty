/// Renders the Play Store graphics that have to contain Arabic, and the
/// phone screenshots (F27-T21).
///
///     flutter test test/store/generate_store_assets.dart --update-goldens
///
/// **Not a test, and deliberately not named like one.** `flutter test` with no
/// arguments collects `*_test.dart`, so this file is invisible to the gate and
/// to CI; naming it explicitly is what runs it.
///
/// Without `--update-goldens` it *compares* against the committed PNGs
/// instead of writing them. That is a real regression check for the feature
/// graphic, which is fixed. **It is not one for the screenshots**: their
/// paper is due a week from the day they are rendered, so the bill on screen
/// always looks current — and so any later run differs on the date alone.
/// Pinning the date would make them comparable until the day it passed, and
/// then the reminder step would refuse a deadline in the past. Regenerate
/// them after a UI change; do not compare them.
///
/// Why Flutter and not the `image` package, which draws the icon
/// (`tool/store/generate_store_icon.dart`): Arabic needs shaping. «ورقتي» is
/// four glyphs that join, and a bitmap-font blitter produces four disconnected
/// letters in the wrong order. Flutter already has HarfBuzz and the real Cairo
/// font is loaded for every test by `flutter_test_config.dart`, so rendering
/// the text through the framework is the only way to get it right — and it is
/// the same text stack the app itself uses.
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/app/app.dart';
import 'package:war2aty/app/di/service_locator.dart';
import 'package:war2aty/app/router/app_router.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/time/document_date_label.dart';
import 'package:war2aty/core/widgets/result_action_bar.dart';
import 'package:war2aty/features/analysis/data/datasources/edge_function_analysis_remote_data_source.dart';

import '../support/app_harness.dart';

const _ar = ArStrings();

/// A 1080 x 1920 phone, which is 360 x 640 logical at ratio 3 — the same
/// surface `support/ui_audit.dart` holds every screen to, so a screenshot
/// cannot show a layout the audit has not already checked.
const Size _phonePixels = Size(1080, 1920);
const double _phoneRatio = 3;

/// How long a confirmation SnackBar stays up — the save confirmation
/// (`SaveDocumentListener`) and Home's usage hint both use the four-second
/// default — with a second of margin, the same wait `invoice_journey_test`
/// uses.
const Duration _saveFeedback = Duration(seconds: 4);

void main() {
  setUp(getIt.reset);
  tearDown(getIt.reset);

  group('store graphics', () {
    testWidgets('feature graphic (1024 x 500)', (tester) async {
      // Play's feature graphic is exactly this size, and is scaled down for
      // several placements — so device pixel ratio 1 and no retina trickery.
      tester.view.physicalSize = const Size(_featureWidth, _featureHeight);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final mark = await _loadMark(tester);

      await tester.pumpWidget(_FeatureGraphic(mark: mark));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(_FeatureGraphic),
        matchesGoldenFile('../../store/feature-graphic.png'),
      );
    });
  });

  // ── Phone screenshots ──────────────────────────────────────────────────
  //
  // Not mock-ups: the real app, over the real dependency graph, walked through
  // the real invoice journey by `AppHarness` (F27-T17). What a buyer sees in
  // the listing is therefore what the app does, including the real fixture's
  // own figures — 850.50 جنيه and a real deadline — laid out by the real
  // formatters in the real Cairo font.
  //
  // The order is the order of the journey, and the filenames carry it because
  // Play uploads and displays them in filename order.
  group('phone screenshots', () {
    journeyTest(
      'the invoice journey, captured as it goes',
      (harness) async {
        final tester = harness.tester;

        // The bundled fixture's prose is dated 2024 — «آخر موعد للسداد 15
        // أبريل 2024» — and that sentence is the headline of the screenshot
        // the listing leads with. `journeyInvoiceBody` moves the structured
        // date to a week out but cannot rewrite prose, and 13 journey tests
        // assert against the fixture as it stands, so the fixture is left
        // alone and only this run's response carries a current-looking bill.
        harness.backend.reply(
          kAnalyzeDocumentPath,
          EdgeReply.json(200, _currentInvoice(harness.deadline)),
        );

        await tester.tap(find.text(_ar.homeScanTitle));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel(_ar.cameraShutterLabel));
        await tester.pumpAndSettle();
        await tester.tap(find.text(_ar.previewUseImage));
        await tester.pumpAndSettle();

        // The paper, read and explained: the screenshot the listing leads with.
        await tester.tap(find.text(_ar.ocrContinue));
        await tester.pumpAndSettle();
        await _capture(tester, '2-result');

        // Saved, so Home has a paper to show — then the confirmation is
        // waited out, because it covers the action bar the next tap needs.
        await tester.tap(find.text(_ar.resultSavePaper));
        await tester.pumpAndSettle();
        await tester.tap(find.text(_ar.actionSave));
        await tester.pumpAndSettle();
        await tester.pump(_saveFeedback);
        await tester.pumpAndSettle();

        // The reminder form, opened for the deadline the paper carries.
        await tester.tap(
          find.descendant(
            of: find.byType(ResultActionBar),
            matching: find.text(_ar.resultCreateReminder),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(_ar.resultDateReminderWorthy));
        await tester.pumpAndSettle();
        await _capture(tester, '3-reminder');

        await tester.tap(find.text(_ar.reminderSaveAction));
        await tester.pumpAndSettle();

        // Home, with the saved paper, the upcoming reminder and the count the
        // journey earned — the screen the user comes back to every time.
        await tester.tap(find.text(_ar.actionBack));
        await tester.pumpAndSettle();
        // Home greets a returning user with «متبقي لك تحليلان النهارده» — a
        // default four-second SnackBar that sits over the very paper this shot
        // exists to show. Waited out, the same way the save confirmation is.
        await tester.pump(_saveFeedback);
        await tester.pumpAndSettle();
        await _capture(tester, '1-home');

        // The four privacy promises, as the app states them (§7 wording).
        unawaited(harness.router.push(AppRoutes.settingsPrivacyPolicy));
        await tester.pumpAndSettle();
        await _capture(tester, '4-privacy');
      },
      boot: (tester) {
        tester.view.physicalSize = _phonePixels;
        tester.view.devicePixelRatio = _phoneRatio;
        addTearDown(tester.view.reset);
        return bootApp(tester);
      },
    );
  });
}

/// The journey's invoice with its prose moved to [deadline].
///
/// Only the three sentences that name a date are rewritten, and each gets the
/// date through the app's own formatter — so the headline, the action and the
/// structured date on screen all agree, as they would for a real paper.
Map<String, Object?> _currentInvoice(DateTime deadline) {
  final body = journeyInvoiceBody(deadline: deadline);
  final on = formatDocumentDate(_ar, deadline);

  body['summary'] = {
    ...body['summary']! as Map<String, Object?>,
    'short': 'فاتورة كهرباء بمبلغ 850.50 جنيه، آخر موعد للسداد $on.',
    'detailed':
        'دي فاتورة كهرباء من شركة جنوب القاهرة لتوزيع الكهرباء. الاستهلاك '
        '320 كيلو وات، والمطلوب منك 850.50 جنيه شامل رسوم الخدمة والنظافة. '
        'لازم تسددها قبل $on، وبعد التاريخ ده بتتحسب غرامة تأخير ومن الممكن '
        'يتقطع التيار.',
  };

  final actions = List<Object?>.from(body['actions_required']! as List);
  actions[0] = {
    ...actions.first! as Map<String, Object?>,
    'description': 'سدد مبلغ 850.50 جنيه قبل $on.',
  };
  body['actions_required'] = actions;

  return body;
}

/// Writes the whole screen to `store/screenshots/ar/<name>.png`.
Future<void> _capture(WidgetTester tester, String name) => expectLater(
  find.byType(WaraqtiApp),
  matchesGoldenFile('../../store/screenshots/ar/$name.png'),
);

const double _featureWidth = 1024;
const double _featureHeight = 500;

// The brand, from CLAUDE.md's design system (Waraqti.dc.html).
const Color _brandTeal = Color(0xFF0E7C86);
const Color _deepTeal = Color(0xFF0A5C64);
const Color _mint = Color(0xFF34D0B4);

/// Decodes the brand mark off disk into a `ui.Image`.
///
/// Read as a file rather than through `Image.asset` on purpose: an asset image
/// decodes asynchronously, and in a widget test that decode never completes
/// unless it is driven inside `runAsync` — which is exactly the trap that makes
/// golden tests render a blank box where a logo should be. Decoding it here,
/// once, and handing the finished `ui.Image` to `RawImage` leaves nothing
/// asynchronous in the widget tree at all.
///
/// The 3.0x variant is the largest the project ships (384 px).
Future<ui.Image> _loadMark(WidgetTester tester) async {
  final bytes = File('assets/images/3.0x/brand_mark.png').readAsBytesSync();
  late ui.Image image;
  await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(bytes);
    image = (await codec.getNextFrame()).image;
  });
  return image;
}

/// The feature graphic: the mark, the name, and what the app is for.
///
/// Right-to-left, because the listing it heads is Arabic. Everything is kept
/// well inside the edges: Play crops this image differently in different
/// placements, and anything near a border is the first thing to be lost.
class _FeatureGraphic extends StatelessWidget {
  const _FeatureGraphic({required this.mark});

  final ui.Image mark;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        width: _featureWidth,
        height: _featureHeight,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [_brandTeal, _deepTeal],
            ),
          ),
          child: Stack(
            children: [
              // A soft glow behind the mark, the same device the launch screen
              // uses, so the two read as one brand rather than two designs.
              Positioned(
                right: 60,
                top: 40,
                child: Container(
                  width: 420,
                  height: 420,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _mint.withValues(alpha: 0.22),
                        _mint.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(72, 56, 72, 56),
                child: Row(
                  children: [
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: RawImage(image: mark, fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 56),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ورقتي بتقول إيه؟',
                            style: _text(
                              size: 68,
                              weight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'صوّر ورقتك، والتطبيق يقراها ويشرحهالك',
                            style: _text(
                              size: 32,
                              weight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.92),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'المواعيد والمبالغ والمطلوب منك، بالعربي',
                            style: _text(
                              size: 26,
                              weight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.8),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _text({
  required double size,
  required FontWeight weight,
  required Color color,
  required double height,
}) => TextStyle(
  fontFamily: 'Cairo',
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  // The test binding has no `MaterialApp` above this widget, so nothing else
  // would turn the underline off.
  decoration: TextDecoration.none,
);
