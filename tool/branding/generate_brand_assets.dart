// Brand asset generator (F27-P01): every launcher icon and splash mark, from
// one source image.
//
//   dart run tool/branding/generate_brand_assets.dart [--source <path>] [--preview]
//
// The source is the icon tile: a teal rounded square with a light symbol on
// it. It may sit on a larger canvas (the current source is a 1024×559 mockup
// with the tile in the middle); the tile is found by its dark teal pixels.
// When a cleaner or larger source arrives, drop it in and re-run — every file
// below is regenerated from it, nothing is edited by hand.
//
// Pipeline:
//   1. find the tile and estimate its background in 2D (vertical gradient plus
//      the soft glow behind the symbol) from the pixels that are clearly
//      background;
//   2. lift the symbol off that background with colour-to-alpha, so it can sit
//      on any background (adaptive foreground, splash, monochrome);
//   3. recompose and resize per target, premultiplied so edges stay clean.
//
// `--preview` also writes build/branding-preview/*.png (git-ignored): the
// icon at launcher sizes, under several adaptive masks, the themed
// (monochrome) icon, and the splash, for review.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const String _defaultSource = 'assets/branding/icon.jpg';

/// Android density buckets and their scale against mdpi.
const Map<String, double> _densities = {
  'mdpi': 1,
  'hdpi': 1.5,
  'xhdpi': 2,
  'xxhdpi': 3,
  'xxxhdpi': 4,
};

/// Side of the Flutter splash mark, in logical pixels (`kSplashMarkSize`). The
/// native splashes show the teal alone, so they need no mark of their own.
const double _splashMarkDp = 128;

/// Background of the dev flavor's icon: the brand warning amber, so a dev
/// build can never be mistaken for the real app on a home screen.
const _Rgb _devTop = (r: 222, g: 145, b: 38);
const _Rgb _devBottom = (r: 168, g: 96, b: 10);

/// The brand teal ramp — the same pair the Flutter splash gradient uses
/// (`#0E7C86` -> `#0A5C64`). The prod icon's background is mapped onto it; see
/// [_retintToBrand].
const _Rgb _brandTop = (r: 14, g: 124, b: 134);
const _Rgb _brandBottom = (r: 10, g: 92, b: 100);

typedef _Rgb = ({double r, double g, double b});

Future<void> main(List<String> args) async {
  final sourcePath = _argValue(args, '--source') ?? _defaultSource;
  final source = img.decodeImage(File(sourcePath).readAsBytesSync());
  if (source == null) {
    stderr.writeln('Cannot decode $sourcePath');
    exit(1);
  }

  final art = _Extraction.from(source);
  stdout.writeln(
    'tile ${art.side}px at (${art.originX}, ${art.originY}); '
    'symbol box ${art.symbolBox}',
  );

  final devBackground = _verticalGradient(art.side, _devTop, _devBottom);
  final devTile = _composite(devBackground, art.symbol);

  _writeAndroid(art, devBackground, devTile);
  _writeIos(art);
  _writeFlutter(art);
  _writeAppIconAsset(art);

  if (args.contains('--preview')) _writePreview(art, devTile);
  stdout.writeln('done');
}

String? _argValue(List<String> args, String name) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

// ---------------------------------------------------------------------------
// Extraction
// ---------------------------------------------------------------------------

final class _Extraction {
  _Extraction._({
    required this.side,
    required this.originX,
    required this.originY,
    required this.background,
    required this.sourceBackground,
    required this.symbol,
    required this.tile,
    required this.symbolBox,
  });

  factory _Extraction.from(img.Image src) {
    final bounds = _findTile(src);
    final side = math.min(bounds.width, bounds.height);
    final x0 = bounds.left + (bounds.width - side) ~/ 2;
    final y0 = bounds.top + (bounds.height - side) ~/ 2;

    final bg = _BackgroundModel.estimate(src, x0, y0, side);
    // The mockup's own teal, kept because the symbol can only be lifted off
    // the background it was actually drawn on. The shipped background is this
    // field re-tinted — see [_retintToBrand].
    final sourceBackground = img.Image(width: side, height: side);
    final symbol = img.Image(width: side, height: side, numChannels: 4);

    // The symbol never touches the tile's edge; ignoring a margin keeps the
    // rounded corners and the mockup around them out of it.
    final margin = (side * 0.06).round();
    for (var y = 0; y < side; y++) {
      for (var x = 0; x < side; x++) {
        final b = bg.at(x.toDouble(), y.toDouble());
        sourceBackground.setPixelRgb(x, y, b.r, b.g, b.b);
        if (x < margin || y < margin || x >= side - margin) continue;
        if (y >= side - margin) continue;
        final p = src.getPixel(x0 + x, y0 + y);
        final lifted = _colorToAlpha((
          r: p.r * 1.0,
          g: p.g * 1.0,
          b: p.b * 1.0,
        ), b);
        if (lifted == null) continue;
        symbol.setPixelRgba(
          x,
          y,
          lifted.color.r,
          lifted.color.g,
          lifted.color.b,
          lifted.alpha * 255,
        );
      }
    }

    final background = _retintToBrand(sourceBackground);
    return _Extraction._(
      side: side,
      originX: x0,
      originY: y0,
      background: background,
      sourceBackground: sourceBackground,
      symbol: symbol,
      tile: _composite(background, symbol),
      symbolBox: _opaqueBox(symbol),
    );
  }

  final int side;
  final int originX;
  final int originY;

  /// The tile's background alone, side × side, opaque — on the brand ramp.
  final img.Image background;

  /// The same field before [_retintToBrand]: the mockup's own teal. Kept only
  /// so the preview can show the two side by side.
  final img.Image sourceBackground;

  /// The symbol alone on transparency, side × side, in tile coordinates.
  final img.Image symbol;

  /// Background + symbol: the clean, square, full-bleed icon.
  final img.Image tile;

  /// Bounding box of the symbol inside [symbol].
  final math.Rectangle<int> symbolBox;

  /// The symbol cropped to a square around its box, for the splash mark.
  ///
  /// The square is padded beyond the box: the box is measured on the
  /// symbol's solid parts, and the ring's faint outer fade lies past it — a
  /// tight crop cuts that fade into a hard edge.
  img.Image get squareSymbol {
    final box = symbolBox;
    final s = (math.max(box.width, box.height) * 1.1).round();
    final cx = box.left + box.width / 2;
    final cy = box.top + box.height / 2;
    final out = img.Image(width: s, height: s, numChannels: 4);
    for (final p in out) {
      final x = (cx - s / 2 + p.x).round();
      final y = (cy - s / 2 + p.y).round();
      if (x < 0 || y < 0 || x >= symbol.width || y >= symbol.height) continue;
      final q = symbol.getPixel(x, y);
      p
        ..r = q.r
        ..g = q.g
        ..b = q.b
        ..a = q.a;
    }
    return out;
  }
}

bool _isTileTeal(img.Pixel p) =>
    p.r < 60 && (0.299 * p.r + 0.587 * p.g + 0.114 * p.b) < 130;

math.Rectangle<int> _findTile(img.Image src) {
  final cy = src.height ~/ 2;
  int? left;
  int? right;
  for (var x = 0; x < src.width; x++) {
    if (_isTileTeal(src.getPixel(x, cy))) {
      left ??= x;
      right = x;
    }
  }
  if (left == null || right == null) {
    throw StateError('No teal tile found on the centre row of the source.');
  }
  // A column inside the tile but clear of the symbol and the corners.
  final cx = left + ((right - left) * 0.2).round();
  int? top;
  int? bottom;
  for (var y = 0; y < src.height; y++) {
    if (_isTileTeal(src.getPixel(cx, y))) {
      top ??= y;
      bottom = y;
    }
  }
  return math.Rectangle<int>(left, top!, right + 1 - left, bottom! + 1 - top);
}

/// Maps a background field onto the brand teal ramp, keeping its shading.
///
/// F27-T18 finding D-3. P01 lifted this icon out of the owner's mockup, so its
/// background was the mockup's own gradient (about `#035763` -> `#023742`) —
/// darker and greener than the `#0E7C86` / `#0A5C64` every teal surface in the
/// app uses. On a launcher, next to the app's own splash, it read as a
/// different colour, which is what the owner reported.
///
/// Re-tinting by luminance rather than replacing the field with a flat
/// gradient keeps what the mockup actually drew: the vertical falloff and the
/// soft glow behind the symbol survive, and only the hue and depth move. The
/// darkest pixel lands on [_brandBottom], the brightest on [_brandTop], so the
/// tile's dominant colour becomes the brand teal and matches the splash the
/// launch animation paints a moment later.
img.Image _retintToBrand(img.Image field) {
  double luma(img.Pixel p) => 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;

  var lo = double.infinity;
  var hi = -double.infinity;
  for (final p in field) {
    final l = luma(p);
    if (l < lo) lo = l;
    if (l > hi) hi = l;
  }
  // A field with no shading at all would divide by zero; it maps to the deep
  // end, which is the safe direction for a background.
  final span = hi - lo < 1 ? 1.0 : hi - lo;

  final out = img.Image(width: field.width, height: field.height);
  for (final p in field) {
    final c = _lerp(
      _brandBottom,
      _brandTop,
      ((luma(p) - lo) / span).clamp(0.0, 1.0),
    );
    out.setPixelRgb(p.x, p.y, c.r, c.g, c.b);
  }
  return out;
}

/// The tile background as a smooth 2D field, sampled on a coarse grid from the
/// pixels that are clearly background and filled in under the symbol.
final class _BackgroundModel {
  _BackgroundModel._(this._grid, this._cell, this._cols, this._rows);

  factory _BackgroundModel.estimate(img.Image src, int x0, int y0, int side) {
    final cell = math.max(8, side ~/ 40);
    final cols = (side / cell).ceil();
    final rows = cols;
    final grid = List<_Rgb?>.filled(cols * rows, null);

    for (var gy = 0; gy < rows; gy++) {
      for (var gx = 0; gx < cols; gx++) {
        final rs = <double>[];
        final gs = <double>[];
        final bs = <double>[];
        for (var y = gy * cell; y < math.min(side, (gy + 1) * cell); y++) {
          for (var x = gx * cell; x < math.min(side, (gx + 1) * cell); x++) {
            final p = src.getPixel(x0 + x, y0 + y);
            final luma = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
            if (p.r > 40 || luma > 100) continue;
            rs.add(p.r * 1.0);
            gs.add(p.g * 1.0);
            bs.add(p.b * 1.0);
          }
        }
        if (rs.length < cell * cell / 3) continue;
        grid[gy * cols + gx] = (r: _median(rs), g: _median(gs), b: _median(bs));
      }
    }

    // Fill the cells under the symbol (and the rounded corners) from their
    // neighbours, ring by ring.
    while (grid.contains(null)) {
      final next = List<_Rgb?>.of(grid);
      for (var gy = 0; gy < rows; gy++) {
        for (var gx = 0; gx < cols; gx++) {
          if (grid[gy * cols + gx] != null) continue;
          final around = <_Rgb>[
            for (var dy = -1; dy <= 1; dy++)
              for (var dx = -1; dx <= 1; dx++)
                if (gx + dx >= 0 && gx + dx < cols && gy + dy >= 0)
                  if (gy + dy < rows) ?grid[(gy + dy) * cols + gx + dx],
          ];
          if (around.isNotEmpty) next[gy * cols + gx] = _mean(around);
        }
      }
      grid.setAll(0, next);
    }

    var smooth = grid.cast<_Rgb>();
    for (var pass = 0; pass < 2; pass++) {
      smooth = [
        for (var gy = 0; gy < rows; gy++)
          for (var gx = 0; gx < cols; gx++)
            _mean([
              for (var dy = -1; dy <= 1; dy++)
                for (var dx = -1; dx <= 1; dx++)
                  smooth[(gy + dy).clamp(0, rows - 1) * cols +
                      (gx + dx).clamp(0, cols - 1)],
            ]),
      ];
    }
    return _BackgroundModel._(smooth, cell, cols, rows);
  }

  final List<_Rgb> _grid;
  final int _cell;
  final int _cols;
  final int _rows;

  /// Bilinear sample between cell centres, in tile coordinates.
  _Rgb at(double x, double y) {
    final fx = (x / _cell - 0.5).clamp(0.0, _cols - 1.0);
    final fy = (y / _cell - 0.5).clamp(0.0, _rows - 1.0);
    final ix = fx.floor().clamp(0, _cols - 2);
    final iy = fy.floor().clamp(0, _rows - 2);
    final tx = fx - ix;
    final ty = fy - iy;
    _Rgb g(int cx, int cy) => _grid[cy * _cols + cx];
    return _lerp(
      _lerp(g(ix, iy), g(ix + 1, iy), tx),
      _lerp(g(ix, iy + 1), g(ix + 1, iy + 1), tx),
      ty,
    );
  }
}

/// Colour-to-alpha against a known background: the least-opaque colour that,
/// laid over [bg], reproduces [p] exactly. Null when [p] is background (within
/// JPEG noise).
///
/// Only pixels LIGHTER than the background count: the symbol is silver, white
/// and gold on dark teal. Counting darker pixels too would read JPEG noise as
/// symbol wherever a background channel sits near zero (the teal's red is ~2,
/// so a 2-level dip would come out fully opaque).
({_Rgb color, double alpha})? _colorToAlpha(_Rgb p, _Rgb bg) {
  const noiseFloor = 4;
  double channel(double pc, double bc) =>
      math.max(0, pc - bc - noiseFloor) / (255 - bc);

  final alpha = [
    channel(p.r, bg.r),
    channel(p.g, bg.g),
    channel(p.b, bg.b),
  ].reduce(math.max);
  if (alpha < 0.06) return null;
  double unmix(double pc, double bc) =>
      (bc + (pc - bc) / alpha).clamp(0, 255).toDouble();
  return (
    color: (r: unmix(p.r, bg.r), g: unmix(p.g, bg.g), b: unmix(p.b, bg.b)),
    alpha: alpha.clamp(0, 1).toDouble(),
  );
}

math.Rectangle<int> _opaqueBox(img.Image rgba) {
  var left = rgba.width;
  var top = rgba.height;
  var right = -1;
  var bottom = -1;
  for (final p in rgba) {
    if (p.a < 0.15 * 255) continue;
    left = math.min(left, p.x);
    right = math.max(right, p.x);
    top = math.min(top, p.y);
    bottom = math.max(bottom, p.y);
  }
  return math.Rectangle<int>(left, top, right + 1 - left, bottom + 1 - top);
}

// ---------------------------------------------------------------------------
// Image helpers
// ---------------------------------------------------------------------------

double _median(List<double> v) => (v..sort())[v.length ~/ 2];

_Rgb _mean(List<_Rgb> v) => (
  r: v.map((c) => c.r).reduce((a, b) => a + b) / v.length,
  g: v.map((c) => c.g).reduce((a, b) => a + b) / v.length,
  b: v.map((c) => c.b).reduce((a, b) => a + b) / v.length,
);

_Rgb _lerp(_Rgb a, _Rgb b, double t) => (
  r: a.r + (b.r - a.r) * t,
  g: a.g + (b.g - a.g) * t,
  b: a.b + (b.b - a.b) * t,
);

img.Image _verticalGradient(int side, _Rgb top, _Rgb bottom) {
  final out = img.Image(width: side, height: side);
  for (var y = 0; y < side; y++) {
    final c = _lerp(top, bottom, y / (side - 1));
    for (var x = 0; x < side; x++) {
      out.setPixelRgb(x, y, c.r, c.g, c.b);
    }
  }
  return out;
}

/// [over] (RGBA, straight alpha) laid on [under] (opaque), same size.
img.Image _composite(img.Image under, img.Image over) {
  final out = img.Image(width: under.width, height: under.height);
  for (final p in out) {
    final u = under.getPixel(p.x, p.y);
    final o = over.getPixel(p.x, p.y);
    final a = o.a / 255;
    p
      ..r = u.r + (o.r - u.r) * a
      ..g = u.g + (o.g - u.g) * a
      ..b = u.b + (o.b - u.b) * a;
  }
  return out;
}

/// Resizes with premultiplied alpha, so transparent pixels' colour never
/// bleeds into the edges. Box-averages when shrinking, bicubic when growing.
img.Image _resize(img.Image src, int width, int height) {
  final shrinking = width <= src.width;
  final interpolation = shrinking
      ? img.Interpolation.average
      : img.Interpolation.cubic;
  if (src.numChannels < 4) {
    return img.copyResize(
      src,
      width: width,
      height: height,
      interpolation: interpolation,
    );
  }
  final pre = img.Image(width: src.width, height: src.height, numChannels: 4);
  for (final p in src) {
    final a = p.a / 255;
    pre.setPixelRgba(p.x, p.y, p.r * a, p.g * a, p.b * a, p.a);
  }
  final resized = img.copyResize(
    pre,
    width: width,
    height: height,
    interpolation: interpolation,
  );
  for (final p in resized) {
    final a = p.a / 255;
    if (a <= 0) {
      p
        ..r = 0
        ..g = 0
        ..b = 0;
      continue;
    }
    p
      ..r = (p.r / a).clamp(0, 255)
      ..g = (p.g / a).clamp(0, 255)
      ..b = (p.b / a).clamp(0, 255);
  }
  return resized;
}

/// [src] (square) shrunk to [content] px and centred on a transparent
/// [canvas] px square.
img.Image _onCanvas(img.Image src, int canvas, int content) {
  final out = img.Image(width: canvas, height: canvas, numChannels: 4);
  final scaled = _resize(src, content, content);
  img.compositeImage(
    out,
    scaled,
    dstX: (canvas - content) ~/ 2,
    dstY: (canvas - content) ~/ 2,
    blend: img.BlendMode.direct,
  );
  return out;
}

/// Anti-aliased mask: a rounded square of [radius] (fraction of the side), or
/// a circle when [radius] is 0.5.
img.Image _masked(img.Image opaque, double radius) {
  final n = opaque.width;
  final out = img.Image(width: n, height: n, numChannels: 4);
  final r = radius * n;
  for (final p in out) {
    final s = opaque.getPixel(p.x, p.y);
    // Signed distance from the pixel centre to the rounded square's edge.
    final qx = ((p.x + 0.5) - n / 2).abs() - (n / 2 - r);
    final qy = ((p.y + 0.5) - n / 2).abs() - (n / 2 - r);
    final outside = math.sqrt(
      math.pow(math.max(qx, 0), 2) + math.pow(math.max(qy, 0), 2),
    );
    final distance = outside + math.min(math.max(qx, qy), 0) - r;
    final coverage = (0.5 - distance).clamp(0.0, 1.0);
    p
      ..r = s.r
      ..g = s.g
      ..b = s.b
      ..a = coverage * 255;
  }
  return out;
}

/// The symbol as a white silhouette, for Android 13+ themed icons. The
/// silver parts are semi-opaque after colour-to-alpha; the curve lifts them so
/// the themed icon reads as solid.
img.Image _monochrome(img.Image symbol) {
  final out = img.Image(
    width: symbol.width,
    height: symbol.height,
    numChannels: 4,
  );
  for (final p in out) {
    final a = symbol.getPixel(p.x, p.y).a / 255;
    final lifted = ((a - 0.08) / 0.6).clamp(0.0, 1.0);
    p
      ..r = 255
      ..g = 255
      ..b = 255
      ..a = lifted * 255;
  }
  return out;
}

void _save(String path, img.Image image) {
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(image, level: 9));
}

img.Image _opaqueRgb(img.Image src) =>
    src.numChannels == 3 ? src : src.convert(numChannels: 3);

// ---------------------------------------------------------------------------
// Targets
// ---------------------------------------------------------------------------

void _writeAndroid(
  _Extraction art,
  img.Image devBackground,
  img.Image devTile,
) {
  const main = 'android/app/src/main/res';
  const dev = 'android/app/src/dev/res';

  // Adaptive layers are 108 dp with the visible area the middle 72 dp — the
  // tile maps onto that 72 dp, so the symbol keeps its proportions from the
  // source and stays well inside the 66 dp safe zone.
  final foreground = art.symbol;
  final monochrome = _monochrome(art.symbol);
  // Notification small icon: Android draws it from alpha alone, as a white
  // silhouette in the status bar, so it is the monochrome symbol, cropped.
  final notify = _monochrome(art.squareSymbol);

  for (final MapEntry(key: bucket, value: scale) in _densities.entries) {
    int px(double dp) => (dp * scale).round();
    final layer = px(108);
    final visible = px(72);

    _save(
      '$main/mipmap-$bucket/ic_launcher_foreground.png',
      _onCanvas(foreground, layer, visible),
    );
    _save(
      '$main/mipmap-$bucket/ic_launcher_monochrome.png',
      _onCanvas(monochrome, layer, visible),
    );
    _save(
      '$main/mipmap-$bucket/ic_launcher_background.png',
      _resize(art.background, layer, layer),
    );
    _save(
      '$dev/mipmap-$bucket/ic_launcher_background.png',
      _resize(devBackground, layer, layer),
    );

    // Legacy icons (API 23–25 and launchers without adaptive support).
    final legacy = px(48);
    _save(
      '$main/mipmap-$bucket/ic_launcher.png',
      _masked(_resize(art.tile, legacy, legacy), 0.2),
    );
    _save(
      '$main/mipmap-$bucket/ic_launcher_round.png',
      _masked(_resize(art.tile, legacy, legacy), 0.5),
    );
    _save(
      '$dev/mipmap-$bucket/ic_launcher.png',
      _masked(_resize(devTile, legacy, legacy), 0.2),
    );
    _save(
      '$dev/mipmap-$bucket/ic_launcher_round.png',
      _masked(_resize(devTile, legacy, legacy), 0.5),
    );

    _save(
      '$main/drawable-$bucket/ic_stat_notify.png',
      _onCanvas(notify, px(24), px(22)),
    );
  }
}

void _writeIos(_Extraction art) {
  const iconSet = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  final contents =
      jsonDecode(File('$iconSet/Contents.json').readAsStringSync())
          as Map<String, Object?>;
  for (final entry
      in (contents['images']! as List).cast<Map<String, Object?>>()) {
    final points = double.parse((entry['size']! as String).split('x').first);
    final scale = double.parse((entry['scale']! as String).replaceAll('x', ''));
    final px = (points * scale).round();
    // iOS masks the corners itself and rejects icons with an alpha channel.
    _save(
      '$iconSet/${entry['filename']}',
      _opaqueRgb(_resize(art.tile, px, px)),
    );
  }
}

void _writeFlutter(_Extraction art) {
  for (final (folder, scale) in [('', 1), ('2.0x/', 2), ('3.0x/', 3)]) {
    final px = (_splashMarkDp * scale).round();
    _save(
      'assets/images/${folder}brand_mark.png',
      _resize(art.squareSymbol, px, px),
    );
  }
}

/// `assets/app_icon.png`: the full icon, kept in step with the launcher icon.
void _writeAppIconAsset(_Extraction art) {
  _save('assets/app_icon.png', _masked(_resize(art.tile, 512, 512), 0.2));
}

// ---------------------------------------------------------------------------
// Preview sheet (review only; never shipped)
// ---------------------------------------------------------------------------

void _writePreview(_Extraction art, img.Image devTile) {
  const dir = 'build/branding-preview';
  final light = img.ColorRgb8(0xF5, 0xF4, 0xEF);
  final dark = img.ColorRgb8(0x1D, 0x2B, 0x30);

  // 1. Launcher sizes (dp at xxhdpi), on light and dark wallpaper.
  const sizes = [36, 48, 72, 96, 144, 192];
  final launcher = img.Image(width: 760, height: 440);
  img.fill(launcher, color: light);
  img.fillRect(launcher, x1: 0, y1: 220, x2: 760, y2: 440, color: dark);
  var x = 16;
  for (final s in sizes) {
    final icon = _masked(_resize(art.tile, s, s), 0.2);
    img.compositeImage(launcher, icon, dstX: x, dstY: 110 - s ~/ 2);
    img.compositeImage(launcher, icon, dstX: x, dstY: 330 - s ~/ 2);
    x += s + 20;
  }
  _save('$dir/1_launcher_sizes.png', launcher);

  // 2. Adaptive icon under the common launcher masks, and the dev variant.
  const n = 216;
  final shapes = img.Image(width: 5 * (n + 24) + 24, height: n + 48);
  img.fill(shapes, color: light);
  final adaptive = _composite(
    _resize(art.background, n, n),
    _onCanvas(art.symbol, n, (n * 72 / 108).round()),
  );
  final devAdaptive = _composite(
    _resize(_verticalGradient(art.side, _devTop, _devBottom), n, n),
    _onCanvas(art.symbol, n, (n * 72 / 108).round()),
  );
  final masks = <(img.Image, double)>[
    (adaptive, 0.5),
    (adaptive, 0.3),
    (adaptive, 0.12),
    (adaptive, 0.2),
    (devAdaptive, 0.5),
  ];
  for (final (i, (source, radius)) in masks.indexed) {
    // Launchers show the middle 72/108 of the layer.
    final visible = img.copyCrop(
      source,
      x: (n * 18 / 108).round(),
      y: (n * 18 / 108).round(),
      width: (n * 72 / 108).round(),
      height: (n * 72 / 108).round(),
    );
    final shown = _masked(_resize(visible, n, n), radius);
    img.compositeImage(shapes, shown, dstX: 24 + i * (n + 24), dstY: 24);
  }
  _save('$dir/2_adaptive_masks.png', shapes);

  // 3. Themed (monochrome) icon, as Android 13+ tints it.
  final themed = img.Image(width: 3 * (n + 24) + 24, height: n + 48);
  img.fill(themed, color: light);
  final mono = _onCanvas(_monochrome(art.symbol), n, (n * 72 / 108).round());
  for (final (i, (bgColor, fgColor)) in [
    ((r: 0xCF, g: 0xE8, b: 0xEA), (r: 0x0A, g: 0x4A, b: 0x52)),
    ((r: 0x0A, g: 0x4A, b: 0x52), (r: 0xCF, g: 0xE8, b: 0xEA)),
    ((r: 0xE6, g: 0xE0, b: 0xF2), (r: 0x3A, g: 0x2E, b: 0x5C)),
  ].indexed) {
    final tile = img.Image(width: n, height: n, numChannels: 4);
    for (final p in tile) {
      final a = mono.getPixel(p.x, p.y).a / 255;
      final c = _lerp(
        (r: bgColor.r * 1.0, g: bgColor.g * 1.0, b: bgColor.b * 1.0),
        (r: fgColor.r * 1.0, g: fgColor.g * 1.0, b: fgColor.b * 1.0),
        a,
      );
      p
        ..r = c.r
        ..g = c.g
        ..b = c.b
        ..a = 255;
    }
    final visible = img.copyCrop(
      tile,
      x: (n * 18 / 108).round(),
      y: (n * 18 / 108).round(),
      width: (n * 72 / 108).round(),
      height: (n * 72 / 108).round(),
    );
    img.compositeImage(
      themed,
      _masked(_resize(visible, n, n), 0.5),
      dstX: 24 + i * (n + 24),
      dstY: 24,
    );
  }
  _save('$dir/3_themed_icon.png', themed);

  // 4. Splash at 3x on a 360×760 dp phone: the brand gradient with the mark
  // centred: the settled frame of the Flutter splash, without its rings.
  const w = 360 * 3;
  const h = 760 * 3;
  final splash = img.Image(width: w, height: h);
  const top = (r: 0x0E * 1.0, g: 0x7C * 1.0, b: 0x86 * 1.0);
  const bottom = (r: 0x0A * 1.0, g: 0x5C * 1.0, b: 0x64 * 1.0);
  for (final p in splash) {
    final c = _lerp(top, bottom, p.y / h);
    p
      ..r = c.r
      ..g = c.g
      ..b = c.b;
  }
  final mark = _resize(art.squareSymbol, 384, 384);
  img.compositeImage(splash, mark, dstX: (w - 384) ~/ 2, dstY: (h - 384) ~/ 2);
  _save('$dir/4_splash.png', splash);

  // 5b. D-3 before/after: the mockup's own teal against the brand ramp, with
  // the app's splash gradient between them as the reference both are judged
  // against.
  final retint = img.Image(width: 3 * (n + 24) + 24, height: n + 48);
  img.fill(retint, color: light);
  final before = _masked(
    _resize(_composite(art.sourceBackground, art.symbol), n, n),
    0.2,
  );
  final after = _masked(_resize(art.tile, n, n), 0.2);
  final reference = img.Image(width: n, height: n);
  for (final p in reference) {
    final c = _lerp(_brandTop, _brandBottom, p.y / n);
    p
      ..r = c.r
      ..g = c.g
      ..b = c.b;
  }
  for (final (i, tile) in [before, after, _masked(reference, 0.2)].indexed) {
    img.compositeImage(retint, tile, dstX: 24 + i * (n + 24), dstY: 24);
  }
  _save('$dir/6_brand_retint_before_after.png', retint);

  // 5. The 48 dp icon at mdpi, blown up 6× with no smoothing: what a
  // low-density phone actually has to work with.
  final tiny = _masked(_resize(art.tile, 48, 48), 0.2);
  _save(
    '$dir/5_mdpi_48px_x6.png',
    img.copyResize(tiny, width: 288, height: 288),
  );
}
