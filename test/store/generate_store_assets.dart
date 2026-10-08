/// Renders the Play Store graphics: the feature graphic and the eight phone
/// screenshots (F27-T21).
///
///     flutter test test/store/generate_store_assets.dart --update-goldens
///     dart run tool/store/finalize_store_assets.dart
///
/// **Not a test, and deliberately not named like one.** `flutter test` with no
/// arguments collects `*_test.dart`, so this file is invisible to the gate and
/// to CI; naming it explicitly is what runs it. The second command finishes
/// the images into the pixel formats Play accepts — see that file.
///
/// The screenshots come out of two stages, in this order:
///
/// 1. **The journey.** The real app, over the real dependency graph, walked
///    through the invoice journey by `AppHarness` (F27-T17), each screen
///    captured unframed as it is reached, into `store/screenshots/raw/`
///    (gitignored — an intermediate, regenerated every run). What a buyer sees
///    is what the app does.
/// 2. **The panels.** Each raw capture placed in a generic modern phone frame
///    on the brand background, under its tagline from `store_captions.dart`,
///    and written to `store/screenshots/ar/` — the files that are uploaded.
///
/// The frame is deliberately no particular phone (the owner's choice, option
/// B): Google's own guidance advises against device imagery, and an iPhone on
/// a Play listing reads as the wrong platform.
///
/// Without `--update-goldens` it *compares* instead of writing. That is a real
/// check for the feature graphic, which is fixed. **It is not one for the
/// screenshots**: their paper is due a week from the day they are rendered, so
/// the bill always looks current — and so any later run differs on the date
/// alone. Pinning the date would hold until the day it passed, and then the
/// reminder step would refuse a deadline in the past. Regenerate them after a
/// UI change; do not compare them.
///
/// Why Flutter and not the `image` package for anything with text: Arabic
/// needs shaping. «ورقتي» is four glyphs that join, and a bitmap-font blitter
/// prints four disconnected letters in the wrong order. Flutter has HarfBuzz,
/// and the real Cairo font is loaded for every test by `flutter_test_config`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/app/app.dart';
import 'package:war2aty/app/di/service_locator.dart';
import 'package:war2aty/app/router/app_router.dart';
import 'package:war2aty/core/accessibility/text_size.dart';
import 'package:war2aty/core/accessibility/text_size_cubit.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/time/document_date_label.dart';
import 'package:war2aty/core/widgets/result_action_bar.dart';
import 'package:war2aty/features/analysis/data/datasources/edge_function_analysis_remote_data_source.dart';
import 'package:war2aty/features/capture/presentation/camera_preview_port.dart';
import 'package:war2aty/features/settings/presentation/screens/privacy_policy_screen.dart';

import '../support/app_harness.dart';
import 'store_captions.dart';

const _ar = ArStrings();

/// A 1080 x 1920 phone, which is 360 x 640 logical at ratio 3 — the same
/// surface `support/ui_audit.dart` holds every screen to, so a screenshot
/// cannot show a layout the audit has not already checked.
const Size _phonePixels = Size(1080, 1920);
const double _phoneRatio = 3;

/// A status bar, in physical pixels: 24 logical at ratio 3.
const double _statusBar = 72;

/// How long a confirmation SnackBar stays up — the save confirmation and
/// Home's usage hint both use the four-second default — with a second of
/// margin, the same wait `invoice_journey_test` uses.
const Duration _saveFeedback = Duration(seconds: 4);

/// The bundled fixtures name **real** Egyptian institutions — a utility, a
/// hospital, the tax authority. A store listing that shows a real
/// institution's name suggests a relationship that does not exist (the terms
/// page says in so many words that there is none), and for a government body
/// that is the kind of implied affiliation Play's policies single out. So every
/// sample is rewritten through this map before the app sees it, and [_raw]
/// refuses to capture a screen that still shows any of the originals.
const Map<String, String> _realNames = {
  'شركة جنوب القاهرة لتوزيع الكهرباء': _sampleIssuer,
  // Longest forms first: map literals keep their order, and a short rule
  // firing first leaves the rest of a long form behind («…بالعجوزة»).
  'مستشفى الشرطة - العجوزة، الدور الثاني': 'المستشفى، الدور الثاني',
  'مستشفى الشرطة بالعجوزة': 'المستشفى',
  'مستشفى الشرطة': 'المستشفى',
  'إخطار من مصلحة الضرائب': 'إخطار ضريبي',
  'مصلحة الضرائب المصرية': 'الجهة الضريبية',
  'مصلحة الضرائب': 'الجهة الضريبية',
  'مأمورية ضرائب مدينة نصر أول': 'المأمورية المختصة',
};

/// What every check for a leaked name looks for — a fragment of each
/// original, so a reworded or truncated rendering is caught too.
const List<String> _realNameFragments = [
  'جنوب القاهرة',
  'مستشفى الشرطة',
  'العجوزة',
  'مصلحة الضرائب',
  'مدينة نصر',
];

const String _sampleIssuer = 'شركة توزيع الكهرباء';

/// Applies [_realNames] to a whole body, on its encoded form rather than field
/// by field, so a field added to a fixture later cannot leak a name.
Map<String, Object?> _scrubbed(Map<String, Object?> body) {
  var encoded = jsonEncode(body);
  for (final MapEntry(key: real, value: sample) in _realNames.entries) {
    encoded = encoded.replaceAll(real, sample);
  }
  for (final fragment in _realNameFragments) {
    if (encoded.contains(fragment)) {
      fail(
        'A real name survived the rewrite: «$fragment». Add it to _realNames.',
      );
    }
  }
  return jsonDecode(encoded) as Map<String, Object?>;
}

// The brand, from CLAUDE.md's design system (Waraqti.dc.html).
const Color _brandTeal = Color(0xFF0E7C86);
const Color _deepTeal = Color(0xFF0A5C64);
const Color _mint = Color(0xFF34D0B4);
const Color _ink = Color(0xFF1D2B30);

const double _featureWidth = 1024;
const double _featureHeight = 500;

/// A finished panel: Play's portrait screenshot, 9:16 at 1080 px.
const Size _panelSize = Size(1080, 1920);

/// Google's guidance: a tagline takes no more than 20% of the image.
const double _taglineLimit = 1920 * 0.2;

void main() {
  setUpAll(_loadMaterialIcons);
  setUp(getIt.reset);
  tearDown(getIt.reset);

  group('store graphics', () {
    testWidgets('feature graphic (1024 x 500)', (tester) async {
      // Exactly Play's size, scaled down for several placements — so device
      // pixel ratio 1 and no retina trickery.
      tester.view.physicalSize = const Size(_featureWidth, _featureHeight);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final mark = await _decode(tester, 'assets/images/3.0x/brand_mark.png');

      await tester.pumpWidget(_FeatureGraphic(mark: mark));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(_FeatureGraphic),
        matchesGoldenFile('../../store/feature-graphic.png'),
      );
    });
  });

  group('phone screenshots', () {
    // ── Stage 1 ──────────────────────────────────────────────────────────
    //
    // In the order the journey reaches each screen, not the listing's order:
    // Home is shot near the end, because only then has it a paper to show.
    journeyTest(
      'stage 1 — the journey, captured raw',
      (harness) async {
        final tester = harness.tester;

        // Two other papers scanned and saved first, through the same screens,
        // so My papers and Home show an archive rather than a single item —
        // and the invoice, scanned last, is the newest. Three scans in all,
        // inside the real limit of three a day, so nothing on screen has to
        // misstate it.
        for (final fixture in const ['appointment', 'government']) {
          harness.backend.reply(
            kAnalyzeDocumentPath,
            EdgeReply.json(200, _otherPaper(fixture)),
          );
          await _scanAndSave(tester);
          harness.router.go(AppRoutes.home);
          await tester.pumpAndSettle();
          await tester.pump(_saveFeedback);
          await tester.pumpAndSettle();
        }

        harness.backend.reply(
          kAnalyzeDocumentPath,
          EdgeReply.json(200, _sampleInvoice(harness.deadline)),
        );

        // The viewfinder, with the sample paper in it.
        await tester.tap(find.text(_ar.homeScanTitle));
        await tester.pumpAndSettle();
        await _raw(tester, '2-camera');

        await tester.tap(find.bySemanticsLabel(_ar.cameraShutterLabel));
        await tester.pumpAndSettle();
        await tester.tap(find.text(_ar.previewUseImage));
        await tester.pumpAndSettle();

        // The paper, read and explained.
        await tester.tap(find.text(_ar.ocrContinue));
        await tester.pumpAndSettle();
        await _raw(tester, '3-result');

        // Scrolled down to the extracted facts.
        await tester.ensureVisible(find.text(_ar.resultKeyInformationTitle));
        await tester.pumpAndSettle();
        // `ensureVisible` parks the card's title at the very top, which is
        // under the screen's own overlaid header. Back off by the header's
        // height so the title shows.
        await tester.dragFrom(const Offset(180, 320), const Offset(0, 90));
        await tester.pumpAndSettle();
        await _raw(tester, '4-details');

        // Read aloud.
        await tester.tap(
          find.descendant(
            of: find.byType(ResultActionBar),
            matching: find.text(_ar.resultListen),
          ),
        );
        await tester.pumpAndSettle();
        await _raw(tester, '6-listen');
        // Closed by its barrier, the way a user dismisses it.
        await tester.tapAt(const Offset(180, 40));
        await tester.pumpAndSettle();

        // Saved, so Home and My papers have it — then the confirmation is
        // waited out, because it covers the action bar the next tap needs.
        await tester.tap(find.text(_ar.resultSavePaper));
        await tester.pumpAndSettle();
        await tester.tap(find.text(_ar.actionSave));
        await tester.pumpAndSettle();
        await tester.pump(_saveFeedback);
        await tester.pumpAndSettle();

        // A reminder for the deadline the paper carries.
        await tester.tap(
          find.descendant(
            of: find.byType(ResultActionBar),
            matching: find.text(_ar.resultCreateReminder),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(_ar.resultDateReminderWorthy));
        await tester.pumpAndSettle();
        await _raw(tester, '5-reminder');
        await tester.tap(find.text(_ar.reminderSaveAction));
        await tester.pumpAndSettle();

        // Home, with the paper and the count the journey earned. It greets a
        // returning user with a four-second usage hint over the very paper
        // this shot is meant to show, so that is waited out too.
        await tester.tap(find.text(_ar.actionBack));
        await tester.pumpAndSettle();
        await tester.pump(_saveFeedback);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        await _raw(tester, '1-home');

        await tester.tap(find.text(_ar.navDocuments));
        await tester.pumpAndSettle();
        await _raw(tester, '7-papers');

        // The privacy promises at the app's «large» text size — the largest
        // at which the first promise still fits whole in the frame.
        unawaited(harness.router.push(AppRoutes.settingsPrivacyPolicy));
        await tester.pumpAndSettle();
        // `setTextSize` emits before it persists, so the screen updates even
        // though the write itself is real I/O this clock never completes.
        unawaited(
          tester
              .element(find.byType(PrivacyPolicyScreen))
              .read<TextSizeCubit>()
              .setTextSize(TextSize.large),
        );
        await tester.pumpAndSettle();
        await _raw(tester, '8-privacy');
      },
      boot: (tester) {
        tester.view.physicalSize = _phonePixels;
        tester.view.devicePixelRatio = _phoneRatio;
        // A phone reserves the status bar, and the app lays itself out around
        // it. Without this the captures start at pixel 0, and the frame's
        // punch-hole camera lands on the app's own titles.
        tester.view.padding = const FakeViewPadding(top: _statusBar);
        tester.view.viewPadding = const FakeViewPadding(top: _statusBar);
        addTearDown(tester.view.reset);

        final deadline = journeyDeadline();
        return bootApp(
          tester,
          deadline: deadline,
          ocrText: _realNames.entries.fold(
            kDeviceOcrText,
            (text, name) => text.replaceAll(name.key, name.value),
          ),
          cameraPreview: _SamplePaperPreview(deadline),
        );
      },
    );

    // ── Stage 2 ──────────────────────────────────────────────────────────
    testWidgets('stage 2 — the framed panels', (tester) async {
      tester.view.physicalSize = _panelSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final caption in kStoreCaptions) {
        final shot = await _decode(
          tester,
          'store/screenshots/raw/${caption.file}.png',
        );
        await tester.pumpWidget(_Panel(shot: shot, caption: caption));
        await tester.pumpAndSettle();

        expect(
          tester.getSize(find.byKey(_Panel.taglineKey)).height,
          lessThanOrEqualTo(_taglineLimit),
          reason:
              '${caption.file}: the tagline is over 20% of the image, the '
              'limit Google asks screenshots to keep to',
        );
        await expectLater(
          find.byType(_Panel),
          matchesGoldenFile('../../store/screenshots/ar/${caption.file}.png'),
        );
      }

      // Exactly the approved eight, and nothing left over from an earlier
      // set: Play shows whatever is uploaded, and a stale file in this folder
      // is one drag-and-drop away from being uploaded.
      final onDisk = Directory('store/screenshots/ar')
          .listSync()
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          .toSet();
      expect(onDisk, {for (final c in kStoreCaptions) '${c.file}.png'});
    });
  });
}

/// Registers the Material Icons font with the test binding.
///
/// The app ships it (`uses-material-design: true`) and a phone always has it,
/// but `flutter_test` does not load it — so any `Icons.*` glyph renders as an
/// empty box, which is what the listening sheet's play and skip buttons first
/// showed. Loaded here rather than in `flutter_test_config`, because nothing in
/// the suite asserts on icon glyphs and this is the one place that renders
/// them for people to look at.
Future<void> _loadMaterialIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final font = File(
    '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  );
  if (root == null || !font.existsSync()) {
    fail(
      'Material Icons not found under FLUTTER_ROOT ($root). Run this with '
      '`flutter test`, which sets it.',
    );
  }
  final bytes = await font.readAsBytes();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future.value(bytes.buffer.asByteData()))).load();
}

/// Scans a paper and saves the result, through the same taps a user makes.
Future<void> _scanAndSave(WidgetTester tester) async {
  await tester.tap(find.text(_ar.homeScanTitle));
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel(_ar.cameraShutterLabel));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_ar.previewUseImage));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_ar.ocrContinue));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_ar.resultSavePaper));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_ar.actionSave));
  await tester.pumpAndSettle();
}

/// Captures the whole screen, unframed, into `store/screenshots/raw/`.
Future<void> _raw(WidgetTester tester, String name) async {
  for (final fragment in _realNameFragments) {
    expect(
      find.textContaining(fragment),
      findsNothing,
      reason: '$name shows a real institution («$fragment») — see _realNames',
    );
  }
  await expectLater(
    find.byType(WaraqtiApp),
    matchesGoldenFile('../../store/screenshots/raw/$name.png'),
  );
}

/// The journey's invoice, made fit for a public listing.
///
/// Two changes, and only two. The prose the bundled fixture dates 2024 is moved
/// to [deadline] — through the app's own formatter, so the headline, the action
/// and the structured date agree. And the real issuer is replaced everywhere it
/// appears, on the encoded body rather than field by field, so a field added
/// to the fixture later cannot leak it.
Map<String, Object?> _sampleInvoice(DateTime deadline) {
  final body = journeyInvoiceBody(deadline: deadline);
  final on = formatDocumentDate(_ar, deadline);

  body['summary'] = {
    ...body['summary']! as Map<String, Object?>,
    'short': 'فاتورة كهرباء بمبلغ 850.50 جنيه، آخر موعد للسداد $on.',
    'detailed':
        'دي فاتورة كهرباء من $_sampleIssuer. الاستهلاك 320 كيلو وات، '
        'والمطلوب منك 850.50 جنيه شامل رسوم الخدمة والنظافة. لازم تسددها '
        'قبل $on، وبعد التاريخ ده بتتحسب غرامة تأخير ومن الممكن يتقطع '
        'التيار.',
  };

  final actions = List<Object?>.from(body['actions_required']! as List);
  actions[0] = {
    ...actions.first! as Map<String, Object?>,
    'description': 'سدد مبلغ 850.50 جنيه قبل $on.',
  };
  body['actions_required'] = actions;

  return _scrubbed(body);
}

/// Another bundled sample, scrubbed, for the papers list. Only its title and
/// type reach a screenshot — the list shows nothing else — so its own dates
/// are left as they are.
Map<String, Object?> _otherPaper(String fixture) => _scrubbed(
  jsonDecode(File('assets/fixtures/analysis/$fixture.json').readAsStringSync())
      as Map<String, Object?>,
);

/// Decodes a PNG off disk into a `ui.Image`.
///
/// Read as a file rather than through `Image.asset` on purpose: an image
/// decodes asynchronously, and in a widget test that decode never completes
/// unless it is driven inside `runAsync` — the trap that makes golden tests
/// render a blank box where a picture should be. Decoding here, once, and
/// handing the finished image to `RawImage` leaves nothing asynchronous in the
/// widget tree at all.
Future<ui.Image> _decode(WidgetTester tester, String path) async {
  final bytes = File(path).readAsBytesSync();
  late ui.Image image;
  await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(bytes);
    image = (await codec.getNextFrame()).image;
  });
  return image;
}

// ── The sample paper in the viewfinder ─────────────────────────────────────

/// What the camera "sees" in the screenshot: a printed electricity bill on a
/// desk.
///
/// Drawn, never photographed. A real bill carries a real person's name,
/// address and account, and has no business in a public store listing. The
/// figures match the sample invoice the result screen explains — the same
/// amount, account and deadline — so the camera shot and the result shot show
/// one paper.
final class _SamplePaperPreview implements CameraPreviewPort {
  const _SamplePaperPreview(this.deadline);

  final DateTime deadline;

  @override
  Widget build(BuildContext context) => _SamplePaper(deadline: deadline);
}

class _SamplePaper extends StatelessWidget {
  const _SamplePaper({required this.deadline});

  final DateTime deadline;

  /// Where the paper sits in the preview, in logical pixels. The viewfinder
  /// overlays its own hint («المس الورقة…», white text) about 420 px below it,
  /// and the shutter capsule below that; a paper running under the hint
  /// swallows it, so the paper ends above it.
  static const double _top = 16;
  static const double _height = 356;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // A warm, dark desk: enough contrast that the paper reads as a paper.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A3F38), Color(0xFF2B2420)],
        ),
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: _top),
          child: Transform.rotate(
            angle: -0.035,
            child: SizedBox(
              width: _height * 0.72,
              height: _height,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xFFFBFAF6),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x88000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: _content(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    TextStyle style(double size, [FontWeight weight = FontWeight.w500]) =>
        TextStyle(
          fontFamily: 'Cairo',
          fontSize: size,
          fontWeight: weight,
          color: _ink,
          height: 1.4,
          decoration: TextDecoration.none,
        );

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: style(10)),
          const Spacer(),
          Text(value, style: style(10, FontWeight.w700)),
        ],
      ),
    );

    const rule = Divider(color: Color(0xFF9AA5A9), height: 14);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _sampleIssuer,
          textAlign: TextAlign.center,
          style: style(13, FontWeight.w800),
        ),
        Text(
          'فاتورة استهلاك كهرباء',
          textAlign: TextAlign.center,
          style: style(10.5),
        ),
        rule,
        row('رقم الفاتورة', '20260915'),
        row('رقم الحساب', '12345678'),
        row('رقم العداد', '4402991'),
        row('الاستهلاك', '320 ك.و.س'),
        row('رسوم خدمة ونظافة', '18.00'),
        rule,
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          color: const Color(0xFFEDEBE4),
          child: Row(
            children: [
              Text('المبلغ المطلوب', style: style(10.5, FontWeight.w700)),
              const Spacer(),
              Text('850.50 جنيه', style: style(13.5, FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        row('آخر موعد للسداد', formatDocumentDate(_ar, deadline)),
        const SizedBox(height: 10),
        Text(
          'برجاء السداد قبل آخر موعد لتجنب غرامة التأخير.',
          style: style(8.5),
        ),
        const Spacer(),
        // A barcode, because every Egyptian utility bill has one.
        SizedBox(
          height: 28,
          child: Row(
            children: [
              for (var i = 0; i < 46; i++)
                Expanded(
                  flex: const [1, 2, 1, 3, 1, 1, 2][i % 7],
                  // A `ColoredBox` with no child collapses to zero height
                  // inside a `Row`; the bars need something to fill.
                  child: ColoredBox(
                    color: i.isEven ? _ink : const Color(0x00000000),
                    child: const SizedBox.expand(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── The framed panel (option B) ───────────────────────────────────────────

/// One finished screenshot: a tagline, and the real screen in a generic phone.
///
/// The phone is no particular model — a thin bezel and a punch-hole camera,
/// the shape of most current Android phones and the trade dress of none.
class _Panel extends StatelessWidget {
  const _Panel({required this.shot, required this.caption});

  /// Measured by stage 2 against Google's 20% guidance.
  static const Key taglineKey = Key('store-panel-tagline');

  final ui.Image shot;
  final StoreCaption caption;

  static const double _screenWidth = 760;
  static const double _screenHeight = _screenWidth * 1920 / 1080;
  static const double _bezel = 16;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox.fromSize(
        size: _panelSize,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_brandTeal, _deepTeal],
            ),
          ),
          child: Stack(
            children: [
              Positioned(top: -160, left: -120, child: _glow(760, 0.20)),
              Positioned(
                top: 104,
                left: 64,
                right: 64,
                child: Column(
                  key: taglineKey,
                  children: [
                    Text(
                      caption.headline,
                      textAlign: TextAlign.center,
                      style: _text(76, FontWeight.w800, Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      caption.subline,
                      textAlign: TextAlign.center,
                      style: _text(
                        38,
                        FontWeight.w600,
                        Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 440,
                left: 0,
                right: 0,
                child: Center(child: _phone()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phone() => Container(
    padding: const EdgeInsets.all(_bezel),
    decoration: BoxDecoration(
      color: const Color(0xFF15191B),
      borderRadius: BorderRadius.circular(68),
      boxShadow: const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 60,
          offset: Offset(0, 30),
        ),
      ],
    ),
    child: Stack(
      alignment: Alignment.topCenter,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(52),
          child: SizedBox(
            width: _screenWidth,
            height: _screenHeight,
            child: RawImage(image: shot, fit: BoxFit.cover),
          ),
        ),
        // The punch-hole camera.
        Container(
          margin: const EdgeInsets.only(top: 22),
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: Color(0xFF0B0D0E),
            shape: BoxShape.circle,
          ),
        ),
      ],
    ),
  );
}

// ── The feature graphic ───────────────────────────────────────────────────

/// The mark, the name, and what the app is for.
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
              // A soft glow behind the mark, the device the launch screen
              // uses, so the two read as one brand rather than two designs.
              Positioned(right: 60, top: 40, child: _glow(420, 0.22)),
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
                            style: _text(68, FontWeight.w800, Colors.white),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'صوّر ورقتك، والتطبيق يقراها ويشرحهالك',
                            style: _text(
                              32,
                              FontWeight.w600,
                              Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'المواعيد والمبالغ والمطلوب منك، بالعربي',
                            style: _text(
                              26,
                              FontWeight.w500,
                              Colors.white.withValues(alpha: 0.8),
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

/// The soft mint glow both the feature graphic and the panels use.
Widget _glow(double size, double strength) => Container(
  width: size,
  height: size,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: RadialGradient(
      colors: [
        _mint.withValues(alpha: strength),
        _mint.withValues(alpha: 0),
      ],
    ),
  ),
);

TextStyle _text(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: 'Cairo',
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: 1.4,
  // No `MaterialApp` above these widgets, so nothing else would turn the
  // underline off.
  decoration: TextDecoration.none,
);
