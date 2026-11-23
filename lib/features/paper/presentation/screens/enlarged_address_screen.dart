import 'package:flutter/material.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/top_bar_icon_button.dart';

const double _headerPadding = 16;
const double _bodyPaddingH = 24;
const double _addressFontSize = 36;
const double _addressLineHeight = 1.4;

class EnlargedAddressScreen extends StatelessWidget {
  const EnlargedAddressScreen({required this.address, super.key});

  final String address;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;
    final mirror = Directionality.of(context) == TextDirection.ltr;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(_headerPadding),
              child: Row(
                children: [
                  TopBarIconButton(
                    tooltip: strings.analysisResultBackLabel,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Transform.flip(
                      flipX: mirror,
                      child: StrokeIcon(
                        StrokeGlyph.arrowBack,
                        color: colors.ink,
                        strokeWidth: 2.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _bodyPaddingH,
                  ),
                  child: Text(
                    address,
                    textAlign: TextAlign.center,
                    style: AppTypography.displayLarge.copyWith(
                      fontSize: _addressFontSize,
                      height: _addressLineHeight,
                      color: colors.ink,
                    ),
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
