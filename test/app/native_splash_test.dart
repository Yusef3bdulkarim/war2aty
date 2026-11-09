import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// F28-T05: the native splashes carry the mark, and every layer agrees.
///
/// This is a regression guard rather than a unit test. The launch is drawn by
/// four things that never see each other — Android's pre-12 `launch_background`,
/// Android 12+'s `windowSplashScreen*`, the iOS storyboard, and Flutter's own
/// first frame — and the whole point of F28 is that a user cannot tell where
/// one ends and the next begins. Nothing else in the suite reads that XML, so a
/// merge, a Flutter template update, or someone regenerating assets could put
/// the flicker back without a single test going red.
///
/// The failure these exist to catch is not a crash. It is a mark that is 128 dp
/// in one layer and 288 dp in the next, or a teal that is one hex here and
/// another there — which looks like a flash at ~440 ms and reads, to a user, as
/// the app stuttering on launch (F27-T18, D-2).
///
/// F33 is the proof that the shape of these guards matters as much as their
/// existence. The Android 12+ check used to read the icon drawable's XML and
/// assert it said `128dp`, which is exactly what the shipped bug said; the
/// mark reached real Android 12+ phones at ~227 dp, masked, and the suite
/// stayed green. The checks below measure the generated bitmaps instead —
/// canvas, ink and the mask circle — because those are what the platform
/// actually reads.
void main() {
  String read(String path) => File(path).readAsStringSync();

  /// The box the non-transparent pixels of [path] occupy, as
  /// (left, top, width, height).
  (int, int, int, int) inkBox(String path) {
    final im = img.decodeImage(File(path).readAsBytesSync())!;
    var minX = im.width, minY = im.height, maxX = -1, maxY = -1;
    for (var y = 0; y < im.height; y++) {
      for (var x = 0; x < im.width; x++) {
        if (im.getPixel(x, y).a <= 8) continue;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    return (minX, minY, maxX - minX + 1, maxY - minY + 1);
  }

  /// Width and height out of a PNG's IHDR, without decoding the image.
  (int, int) pngSize(String path) {
    final b = File(path).readAsBytesSync();
    int at(int o) =>
        (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
    return (at(16), at(20));
  }

  /// `kLaunchBackground`, read out of the Dart source — the value every other
  /// layer is checked against.
  final launchScreen = read(
    'lib/features/bootstrap/presentation/screens/launch_screen.dart',
  );
  final dartHex = RegExp(
    r'kLaunchBackground = Color\(0x([0-9A-Fa-f]{8})\)',
  ).firstMatch(launchScreen)?.group(1)?.toUpperCase();

  /// 128 dp, at each Android density bucket.
  const markPx = {
    'mdpi': 128,
    'hdpi': 192,
    'xhdpi': 256,
    'xxhdpi': 384,
    'xxxhdpi': 512,
  };

  group('the layers agree on one colour', () {
    test('Flutter, Android and iOS all paint the same teal', () {
      expect(
        dartHex,
        isNotNull,
        reason: 'kLaunchBackground must stay findable',
      );
      expect(dartHex, 'FF0A6C76');

      final colors = read('android/app/src/main/res/values/colors.xml');
      final androidHex = RegExp(
        r'name="splash_bg">#([0-9A-Fa-f]{8})<',
      ).firstMatch(colors)?.group(1)?.toUpperCase();
      expect(
        androidHex,
        dartHex,
        reason:
            'Android draws splash_bg for ~440 ms and Flutter draws '
            'kLaunchBackground after it; if they differ the swap is a visible '
            'flash of colour',
      );

      // The storyboard stores the same colour as sRGB floats.
      final board = read('ios/Runner/Base.lproj/LaunchScreen.storyboard');
      final bg = RegExp(
        r'<color key="backgroundColor" red="([\d.]+)" green="([\d.]+)" blue="([\d.]+)"',
      ).firstMatch(board);
      expect(bg, isNotNull, reason: 'the launch screen needs a background');
      final channels = [
        1,
        2,
        3,
      ].map((i) => (double.parse(bg!.group(i)!) * 255).round()).toList();
      final iosHex =
          'FF${channels.map((c) => c.toRadixString(16).padLeft(2, '0')).join()}'
              .toUpperCase();
      expect(iosHex, dartHex, reason: 'the iOS launch screen must match too');
    });
  });

  group('Android before 12', () {
    for (final dir in ['drawable', 'drawable-v21']) {
      test('$dir/launch_background.xml paints the teal and the mark', () {
        final xml = read('android/app/src/main/res/$dir/launch_background.xml');
        expect(xml, contains('@color/splash_bg'));
        expect(
          xml,
          contains('@drawable/splash_mark'),
          reason:
              'P01 showed the teal alone here, which left ~440 ms of empty '
              'screen before Flutter could draw anything (F27-T18, D-2)',
        );
        expect(
          xml,
          contains('android:gravity="center"'),
          reason: 'off-centre here is a jump when Flutter draws it centred',
        );
      });
    }
  });

  group('Android 12 and up', () {
    test('both themes set the splash background and icon', () {
      for (final dir in ['values-v31', 'values-night-v31']) {
        final xml = read('android/app/src/main/res/$dir/styles.xml');
        expect(xml, contains('@color/splash_bg'), reason: dir);
        expect(
          xml,
          contains('windowSplashScreenAnimatedIcon">@drawable/splash_icon'),
          reason: '$dir: without an icon the system shows the launcher icon',
        );
      }
    });

    test('the icon is a 288 dp canvas at every density', () {
      expect(
        File('android/app/src/main/res/drawable/splash_icon.xml').existsSync(),
        isFalse,
        reason:
            'F33: an XML drawable here pinned the mark to a size the platform '
            'ignores. The icon is a bitmap on the canvas the platform does '
            'measure, so the XML must not come back',
      );
      markPx.forEach((bucket, px) {
        final path =
            'android/app/src/main/res/drawable-$bucket/splash_icon.png';
        expect(File(path).existsSync(), isTrue, reason: '$path is missing');
        // 288/128 of the mark, because the platform stretches whatever it is
        // handed across a 288 dp viewport: only this ratio sets the size on
        // screen.
        final canvas = px * 288 ~/ 128;
        expect(
          pngSize(path),
          (canvas, canvas),
          reason:
              'a canvas of any other size rescales the mark on every '
              'Android 12+ phone — at 128 dp it reached the screen at ~227 dp',
        );
      });
    });

    test(
      'the mark inside it is Flutter\'s mark, centred, clear of the mask',
      () {
        const canvas = 288;
        final (left, top, width, height) = inkBox(
          'android/app/src/main/res/drawable-mdpi/splash_icon.png',
        );
        final (_, _, markWidth, markHeight) = inkBox(
          'assets/images/brand_mark.png',
        );

        expect(
          (width, height),
          (markWidth, markHeight),
          reason:
              'the mark on the system splash and the mark Flutter draws over it '
              'are one image at one size, or the handover is a jump',
        );

        const offCentre =
            'off-centre here moves the mark when Flutter takes '
            'over';
        expect(left + width / 2, closeTo(canvas / 2, 1), reason: offCentre);
        expect(top + height / 2, closeTo(canvas / 2, 1), reason: offCentre);

        // The platform clips the icon to the device's icon mask — the inner
        // 192 dp of the canvas, a circle in the tightest case. The shipped bug
        // was the mark's sides being cut flat by it.
        final far =
            [
                  (left, top),
                  (left + width, top),
                  (left, top + height),
                  (left + width, top + height),
                ]
                .map((c) {
                  final dx = c.$1 - canvas / 2;
                  final dy = c.$2 - canvas / 2;
                  return dx * dx + dy * dy;
                })
                .reduce((a, b) => a > b ? a : b);
        expect(
          far,
          lessThan(96 * 96),
          reason: 'the ink must stay inside the 192 dp mask circle',
        );
      },
    );

    test('the system splash leaves without animating the mark away', () {
      final kt = read(
        'android/app/src/main/kotlin/com/war2aty/app/MainActivity.kt',
      );
      expect(
        kt,
        contains('setOnExitAnimationListener'),
        reason:
            'by default the system plays its icon out, fading and scaling it, '
            'which undoes every other layer of this launch',
      );
      expect(kt, contains('remove()'));
      expect(
        kt,
        contains('Build.VERSION_CODES.S'),
        reason: 'getSplashScreen() only exists from API 31',
      );
    });
  });

  group('the mark itself', () {
    markPx.forEach((bucket, px) {
      test('drawable-$bucket/splash_mark.png is $px px (128 dp)', () {
        final path =
            'android/app/src/main/res/drawable-$bucket/splash_mark.png';
        expect(File(path).existsSync(), isTrue, reason: '$path is missing');
        expect(pngSize(path), (px, px));
      });
    });

    test('iOS LaunchImage is the mark, not the old 1x1 placeholder', () {
      const dir = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
      for (final (suffix, px) in [('', 128), ('@2x', 256), ('@3x', 384)]) {
        final path = '$dir/LaunchImage$suffix.png';
        expect(File(path).existsSync(), isTrue, reason: '$path is missing');
        expect(
          pngSize(path),
          (px, px),
          reason:
              'these were 1x1 transparent files, which is why the iOS launch '
              'screen showed the teal alone',
        );
      }
    });

    test('the storyboard centres it and declares its real size', () {
      final board = read('ios/Runner/Base.lproj/LaunchScreen.storyboard');
      expect(board, contains('image="LaunchImage"'));
      expect(board, contains('contentMode="center"'));
      expect(
        board,
        contains('<image name="LaunchImage" width="128" height="128"/>'),
        reason: 'a stale declared size here misplaces the mark in Xcode',
      );
    });
  });

  group('Flutter draws what the native splash already drew', () {
    test('one mark size, in all four places that have to agree', () {
      final dartSize = RegExp(
        r'kSplashMarkSize = (\d+)',
      ).firstMatch(launchScreen)?.group(1);
      expect(dartSize, '128', reason: 'Flutter draws the mark at this size');

      final generator = read('tool/branding/generate_brand_assets.dart');
      final cutAt = RegExp(
        r'_splashMarkDp = (\d+)',
      ).firstMatch(generator)?.group(1);
      expect(
        cutAt,
        dartSize,
        reason: 'the generator cuts every bitmap at this many dp',
      );

      final canvas = RegExp(
        r'_splashIconCanvasDp = (\d+)',
      ).firstMatch(generator)?.group(1);
      expect(
        canvas,
        '288',
        reason:
            'the Android 12+ mark is $dartSize dp of this canvas, and that '
            'ratio is the only thing the platform reads (F33)',
      );
    });

    test('the Flutter asset and the native bitmap are the same bytes', () {
      const pairs = [
        ('assets/images/brand_mark.png', 'mdpi'),
        ('assets/images/2.0x/brand_mark.png', 'xhdpi'),
        ('assets/images/3.0x/brand_mark.png', 'xxhdpi'),
      ];
      for (final (flutterAsset, bucket) in pairs) {
        final native =
            'android/app/src/main/res/drawable-$bucket/splash_mark.png';
        expect(
          File(flutterAsset).readAsBytesSync(),
          File(native).readAsBytesSync(),
          reason:
              'at a matching density these are the same image, cut from one '
              'source by one resize. If they ever diverge, the mark changes '
              'when Flutter takes over — which is the whole thing F28 exists '
              'to prevent',
        );
      }
    });

    test('the launch screen draws the mark, and the mark is the asset', () {
      expect(
        launchScreen,
        contains("kBrandMarkAsset = 'assets/images/brand_mark.png'"),
        reason: 'Flutter must draw the same file the generator cut',
      );
      expect(
        launchScreen,
        contains('width: kSplashMarkSize'),
        reason: 'drawing it at any other size is a jump at the handover',
      );
    });
  });
}
