import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/theme/app_colors.dart';

// From the approved F29 prototype (`docs/design/F29-reminders-empty-mockups.html`
// → concept D's small art). The ring overhangs the bell by [_ringOverhang] on
// two sides, and the box is grown by exactly that much so the whole drawing
// sits inside its own bounds — a `Stack` clips to them, and a decoration that
// paints outside its widget is a surprise waiting for the next layout change.
const double _ringOverhang = 5;
const double _artWidth = 104 + _ringOverhang;
const double _artHeight = 88 + _ringOverhang;

const double _sheetTop = 4;
const double _sheetStart = 14;
const double _sheetWidth = 66;
const double _sheetHeight = 76;
const double _sheetRadius = 11;
const double _sheetTilt = -7 * math.pi / 180;
const double _sheetPaddingTop = 11;
const double _sheetPaddingSide = 10;

const double _lineHeight = 4;
const double _lineGap = 6;

const double _chipSize = 20;
const double _chipRadius = 7;
const double _chipGlyph = 11;
const double _chipBottom = 22;
const double _chipStart = 7;

const double _bellSize = 46;
const double _bellRadius = 15;
const double _bellGlyph = 23;
const double _ringSize = _bellSize + _ringOverhang * 2;
const double _ringRadius = 18;
const double _ringWidth = 2;

const double _hairline = 1.5;

/// Illustration-only accents for the mock "lines of text" on the paper.
///
/// The same two values «مستنداتي»'s own empty-state art uses, so the two
/// drawings read as one family — decorative, not semantic, which is why they
/// are literals here rather than [AppColors] entries. Sharing them properly
/// would mean lifting them into `core/`, which would touch
/// `documents_empty_state.dart`; F29 locked decision 9 keeps that file to the
/// shadow removal and nothing else.
const Color _lineDark = Color(0xFFD3CDBF);
const Color _lineLight = Color(0xFFDED9CE);

/// A tilted paper with a date marked on it, and a reminder bell resting on
/// the corner — the picture over «مافيش تذكيرات لسه» (F29).
///
/// **Flat by construction.** Not one [BoxShadow] anywhere: the paper is
/// separated from the page by a hairline border, and the bell by the pale
/// ring around it. The owner had the shadows taken off Home's and
/// «مستنداتي»'s art in the same breath as asking for this screen (F29-T02),
/// so arriving with a third shadowed illustration would have undone half the
/// feature. `reminders_empty_art_test` fails if a shadow appears.
///
/// Laid out with plain [Positioned] rather than the directional variant, and
/// carrying no text at all: this is a picture, so it holds the same
/// composition in both languages, and the amber chip says "there is a date on
/// this paper" with a calendar glyph rather than with digits no translation
/// would reach — the whole thing is [ExcludeSemantics], so any text in it
/// would be read by nobody and localized by nothing.
class RemindersEmptyArt extends StatelessWidget {
  const RemindersEmptyArt({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return ExcludeSemantics(
      child: SizedBox(
        width: _artWidth,
        height: _artHeight,
        child: Stack(
          children: [
            Positioned(
              top: _sheetTop,
              left: _sheetStart,
              child: Transform.rotate(
                angle: _sheetTilt,
                child: Container(
                  width: _sheetWidth,
                  height: _sheetHeight,
                  padding: const EdgeInsets.only(
                    top: _sheetPaddingTop,
                    left: _sheetPaddingSide,
                    right: _sheetPaddingSide,
                  ),
                  decoration: BoxDecoration(
                    color: colors.card,
                    border: Border.all(
                      color: colors.borderSoft,
                      width: _hairline,
                    ),
                    borderRadius: BorderRadius.circular(_sheetRadius),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TextLine(width: 0.62, color: _lineDark),
                      SizedBox(height: _lineGap),
                      _TextLine(color: _lineLight),
                      SizedBox(height: _lineGap),
                      _TextLine(width: 0.82, color: _lineLight),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: _chipStart,
              bottom: _chipBottom,
              child: Transform.rotate(
                angle: _sheetTilt,
                child: Container(
                  width: _chipSize,
                  height: _chipSize,
                  decoration: BoxDecoration(
                    color: colors.warningTint,
                    border: Border.all(
                      color: colors.warningBorder,
                      width: _hairline,
                    ),
                    borderRadius: BorderRadius.circular(_chipRadius),
                  ),
                  child: Center(
                    child: StrokeIcon(
                      StrokeGlyph.calendar,
                      color: colors.warningInk,
                      size: _chipGlyph,
                    ),
                  ),
                ),
              ),
            ),
            // The pale ring stands in for the teal glow the design used to
            // put under a tile like this — the one the owner removed.
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: _ringSize,
                height: _ringSize,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colors.surfaceTealAlt,
                    width: _ringWidth,
                  ),
                  borderRadius: BorderRadius.circular(_ringRadius),
                ),
              ),
            ),
            Positioned(
              right: _ringOverhang,
              bottom: _ringOverhang,
              child: Container(
                width: _bellSize,
                height: _bellSize,
                decoration: BoxDecoration(
                  color: colors.brandPrimary,
                  borderRadius: BorderRadius.circular(_bellRadius),
                ),
                child: Center(
                  child: StrokeIcon(
                    StrokeGlyph.navReminders,
                    color: colors.onBrand,
                    size: _bellGlyph,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One hairline bar standing in for a line of text on the mock paper.
class _TextLine extends StatelessWidget {
  const _TextLine({this.width = 1, required this.color});

  /// Fraction of the paper's content width this line fills.
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: width,
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        height: _lineHeight,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(_lineHeight),
        ),
      ),
    );
  }
}
