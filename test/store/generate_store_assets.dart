/// Renders the Play Store graphics: the feature graphic, and the eight phone
/// screenshots framed for the listing (F27-T21).
///
///     flutter test test/store/generate_store_assets.dart --update-goldens
///     dart run tool/store/finalize_store_assets.dart
///
/// **Not a test, and deliberately not named like one.** `flutter test` with no
/// arguments collects `*_test.dart`, so this file is invisible to the gate and
/// to CI; naming it explicitly is what runs it. The second command finishes
/// the images into the pixel formats Play accepts — see that file.
///
/// ## Where the screens come from
///
/// The owner's own screenshots, taken on the phone (owner, 2026-10-10), saved
/// as `store/screenshots/raw/<file>.{png,jpg,jpeg}` under the names in
/// `store_captions.dart`. That folder is **gitignored, and must stay so**: the
/// repository is public, and a device screenshot can carry anything that was
/// on the phone — one of the first batch showed a stranger's name on a
/// marriage certificate. Each one is looked at before it is framed; only the
/// framed panels, which are published anyway, are committed.
///
/// Each is placed in a generic modern phone frame on the brand background,
/// under its tagline. The frame is deliberately no particular phone (the
/// owner's choice, option B): Google's guidance advises against device
/// imagery, and an iPhone on a Play listing reads as the wrong platform. The
/// screen keeps the source's own proportions — the RMX2001 is 9:20, taller
/// than the 9:16 panel — so nothing is stretched or cropped.
///
/// A missing source is reported by name at the end of the run, after every
/// panel that *can* be framed has been: a half-finished set is more useful to
/// look at than none.
///
/// Why Flutter and not the `image` package for anything with text: Arabic
/// needs shaping. «ورقتي» is four glyphs that join, and a bitmap-font blitter
/// prints four disconnected letters in the wrong order. Flutter has HarfBuzz,
/// and the real Cairo font is loaded for every test by `flutter_test_config`.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'store_captions.dart';

// The brand, from CLAUDE.md's design system (Waraqti.dc.html).
const Color _brandTeal = Color(0xFF0E7C86);
const Color _deepTeal = Color(0xFF0A5C64);
const Color _mint = Color(0xFF34D0B4);

const double _featureWidth = 1024;
const double _featureHeight = 500;

/// A finished panel: Play's portrait screenshot, 9:16 at 1080 px — the size
/// that keeps the listing eligible for Play's large-format recommendations.
const Size _panelSize = Size(1080, 1920);

/// Google's guidance: a tagline takes no more than 20% of the image.
const double _taglineLimit = 1920 * 0.2;

const String _rawDirectory = 'store/screenshots/raw';
const List<String> _rawExtensions = ['png', 'jpg', 'jpeg'];

void main() {
  testWidgets('feature graphic (1024 x 500)', (tester) async {
    // Exactly Play's size, scaled down for several placements — so device
    // pixel ratio 1 and no retina trickery.
    tester.view.physicalSize = const Size(_featureWidth, _featureHeight);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final mark = await _decode(
      tester,
      File('assets/images/3.0x/brand_mark.png'),
    );

    await tester.pumpWidget(_FeatureGraphic(mark: mark));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(_FeatureGraphic),
      matchesGoldenFile('../../store/feature-graphic.png'),
    );
  });

  testWidgets('the eight framed screenshots', (tester) async {
    tester.view.physicalSize = _panelSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final missing = <String>[];
    for (final caption in kStoreCaptions) {
      final source = _rawSource(caption.file);
      if (source == null) {
        missing.add(caption.file);
        continue;
      }
      final shot = await _decode(tester, source);
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

    expect(
      missing,
      isEmpty,
      reason:
          'No device screenshot for: ${missing.join(', ')}. Save each as '
          '$_rawDirectory/<name>.png (or .jpg/.jpeg); every other panel has '
          'been written.',
    );

    // Exactly the eight, and nothing left over from an earlier set: Play
    // shows whatever is uploaded, and a stale file in this folder is one
    // drag-and-drop away from being uploaded.
    final onDisk = Directory('store/screenshots/ar')
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .toSet();
    expect(onDisk, {for (final c in kStoreCaptions) '${c.file}.png'});
  });
}

/// The owner's screenshot for [name], whichever image format it was saved in.
File? _rawSource(String name) {
  for (final extension in _rawExtensions) {
    final file = File('$_rawDirectory/$name.$extension');
    if (file.existsSync()) return file;
  }
  return null;
}

/// Decodes an image off disk into a `ui.Image`.
///
/// Read as a file rather than through `Image.file` on purpose: an image
/// decodes asynchronously, and in a widget test that decode never completes
/// unless it is driven inside `runAsync` — the trap that makes golden tests
/// render a blank box where a picture should be. Decoding here, once, and
/// handing the finished image to `RawImage` leaves nothing asynchronous in the
/// widget tree at all.
Future<ui.Image> _decode(WidgetTester tester, File file) async {
  final bytes = file.readAsBytesSync();
  late ui.Image image;
  await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(bytes);
    image = (await codec.getNextFrame()).image;
  });
  return image;
}

// ── The framed panel (option B) ───────────────────────────────────────────

/// One finished screenshot: a tagline, and the real screen in a generic phone.
///
/// The phone is no particular model — a thin bezel and a punch-hole camera,
/// the shape of most current Android phones and the trade dress of none.
class _Panel extends StatelessWidget {
  const _Panel({required this.shot, required this.caption});

  /// Measured against Google's 20% guidance as each panel is rendered.
  static const Key taglineKey = Key('store-panel-tagline');

  final ui.Image shot;
  final StoreCaption caption;

  static const double _phoneTop = 400;
  static const double _phoneBottomMargin = 64;
  static const double _maxScreenWidth = 700;
  static const double _bezel = 16;

  /// The screen at the source's own proportions, as large as the space under
  /// the tagline allows.
  Size get _screen {
    final aspect = shot.height / shot.width;
    final maxHeight =
        _panelSize.height - _phoneTop - _phoneBottomMargin - 2 * _bezel;
    final width = (maxHeight / aspect).clamp(0, _maxScreenWidth).toDouble();
    return Size(width, width * aspect);
  }

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
                top: _phoneTop,
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

  Widget _phone() {
    final screen = _screen;
    // Corners in proportion to the screen, so a narrower screen does not
    // look rounder than a wide one.
    final radius = screen.width * 0.07;

    return Container(
      padding: const EdgeInsets.all(_bezel),
      decoration: BoxDecoration(
        color: const Color(0xFF15191B),
        borderRadius: BorderRadius.circular(radius + _bezel),
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
            borderRadius: BorderRadius.circular(radius),
            child: SizedBox.fromSize(
              size: screen,
              child: RawImage(
                image: shot,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          // The punch-hole camera, over the middle of the status bar — the
          // one part of a real status bar that shows nothing.
          Container(
            margin: EdgeInsets.only(top: screen.height * 0.012),
            width: screen.width * 0.032,
            height: screen.width * 0.032,
            decoration: const BoxDecoration(
              color: Color(0xFF0B0D0E),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
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
