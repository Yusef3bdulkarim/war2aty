import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/service_state_view.dart';
import '../../../../core/widgets/top_bar_icon_button.dart';
import '../cubit/paper_screen_cubit.dart';
import '../cubit/paper_screen_state.dart';
import '../models/paper_view.dart';

const double _headerPaddingH = 16;
const double _headerPaddingV = 16;
const double _headerGap = 10;
const double _thumbnailSize = 46;
const double _thumbnailBorder = 2;
const double _miniCardWidth = 22;
const double _miniCardHeight = 28;
const double _miniCardTilt = -6 * math.pi / 180;
const double _helpButtonSize = 44;
const double _titleFontSize = 17;
const double _dateFontSize = 13;
const double _bodyPaddingH = 16;
const double _bodyPaddingV = 16;

class PaperScreen extends StatelessWidget {
  const PaperScreen({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).surface,
      body: BlocBuilder<PaperScreenCubit, PaperScreenState>(
        builder: (context, state) {
          final strings = context.strings;
          return switch (state) {
            PaperScreenLoading() => const _Loading(),
            PaperScreenReady(:final paper, :final imageBytes) => _ReadyBody(
              view: PaperView.from(paper, strings),
              imageBytes: imageBytes,
              onBack: onBack,
            ),
            PaperScreenNotFound() => _StateBody(
              title: strings.paperScreenNotFoundTitle,
              message: strings.paperScreenNotFoundMessage,
              onBack: onBack,
            ),
            PaperScreenError() => _StateBody(
              title: strings.paperScreenErrorTitle,
              message: strings.paperScreenErrorMessage,
              onBack: onBack,
            ),
          };
        },
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: AppColors.of(context).brandPrimary,
        semanticsLabel: context.strings.stateLoading,
      ),
    );
  }
}

class _StateBody extends StatelessWidget {
  const _StateBody({
    required this.title,
    required this.message,
    required this.onBack,
  });

  final String title;
  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return ServiceStateView(
      title: title,
      message: message,
      primary: ServiceStateAction(
        label: strings.analysisBackToHome,
        onPressed: onBack,
      ),
      onBack: onBack,
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({
    required this.view,
    required this.imageBytes,
    required this.onBack,
  });

  final PaperView view;
  final Uint8List? imageBytes;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _PaperHeader(view: view, imageBytes: imageBytes, onBack: onBack),
          const Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: _bodyPaddingH,
                vertical: _bodyPaddingV,
              ),
              child: SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperHeader extends StatelessWidget {
  const _PaperHeader({
    required this.view,
    required this.imageBytes,
    required this.onBack,
  });

  final PaperView view;
  final Uint8List? imageBytes;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;
    final mirror = Directionality.of(context) == TextDirection.ltr;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(bottom: BorderSide(color: colors.borderSoft)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _headerPaddingH,
          vertical: _headerPaddingV,
        ),
        child: Row(
          children: [
            TopBarIconButton(
              tooltip: strings.analysisResultBackLabel,
              onPressed: onBack,
              icon: Transform.flip(
                flipX: mirror,
                child: StrokeIcon(
                  StrokeGlyph.arrowBack,
                  color: colors.ink,
                  strokeWidth: 2.2,
                ),
              ),
            ),
            const SizedBox(width: _headerGap),
            _PaperThumbnail(imageBytes: imageBytes),
            const SizedBox(width: _headerGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      view.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelCard.copyWith(
                        fontSize: _titleFontSize,
                        fontWeight: AppTypography.extraBold,
                        color: colors.ink,
                        height: 1.35,
                      ),
                    ),
                  ),
                  Text(
                    view.headerDate,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelCard.copyWith(
                      fontSize: _dateFontSize,
                      fontWeight: AppTypography.semiBold,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: _headerGap),
            _HelpButton(label: strings.paperHelpLabel),
          ],
        ),
      ),
    );
  }
}

class _PaperThumbnail extends StatelessWidget {
  const _PaperThumbnail({required this.imageBytes});

  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final imageBytes = this.imageBytes;

    return ExcludeSemantics(
      child: Container(
        width: _thumbnailSize,
        height: _thumbnailSize,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surfaceAlt,
          border: Border.all(color: colors.borderCool, width: _thumbnailBorder),
        ),
        child: imageBytes == null
            ? const _PaperThumbnailPlaceholder()
            : Image.memory(imageBytes, fit: BoxFit.cover),
      ),
    );
  }
}

class _PaperThumbnailPlaceholder extends StatelessWidget {
  const _PaperThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Center(
      child: Transform.rotate(
        angle: _miniCardTilt,
        child: Container(
          width: _miniCardWidth,
          height: _miniCardHeight,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FractionallySizedBox(
                widthFactor: 0.6,
                child: ColoredBox(
                  color: colors.brandPrimary,
                  child: const SizedBox(height: 2),
                ),
              ),
              ColoredBox(
                color: colors.borderStrong,
                child: const SizedBox(height: 2),
              ),
              FractionallySizedBox(
                widthFactor: 0.75,
                child: ColoredBox(
                  color: colors.borderStrong,
                  child: const SizedBox(height: 2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpButton extends StatelessWidget {
  const _HelpButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Semantics(
      button: true,
      enabled: false,
      label: label,
      child: Container(
        width: _helpButtonSize,
        height: _helpButtonSize,
        decoration: BoxDecoration(
          color: colors.surfaceTeal,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.help_outline_rounded,
          color: colors.brandPrimary,
          size: 22,
        ),
      ),
    );
  }
}
