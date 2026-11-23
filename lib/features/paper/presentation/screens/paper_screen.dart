import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/audio/reading_speed.dart';
import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/papers/paper_explanation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/voice/voice_playback_cubit.dart';
import '../../../../core/voice/voice_playback_state.dart';
import '../../../../core/widgets/service_state_view.dart';
import '../../../../core/widgets/top_bar_icon_button.dart';
import '../cubit/paper_screen_cubit.dart';
import '../cubit/paper_screen_state.dart';
import '../cubit/phone_dialer_cubit.dart';
import '../cubit/phone_dialer_state.dart';
import '../models/paper_player_view.dart';
import '../models/paper_view.dart';
import '../models/paper_voice_progress.dart';
import '../widgets/caution_card.dart';
import '../widgets/contact_card.dart';
import '../widgets/date_card.dart';
import '../widgets/explain_card.dart';
import '../widgets/paper_player_bar.dart';
import '../widgets/paper_status_segments.dart';
import '../widgets/place_card.dart';
import '../widgets/todo_card.dart';
import 'enlarged_address_screen.dart';

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
  const PaperScreen({required this.onBack, required this.onRemind, super.key});

  final VoidCallback onBack;
  final void Function(DateTime eventDate, int? eventMinuteOfDay) onRemind;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return BlocListener<PhoneDialerCubit, PhoneDialerState>(
      listener: (context, state) {
        if (state is! PhoneDialerCallFailed) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(strings.paperContactCardCallFailedMessage)),
          );
      },
      child: Scaffold(
        backgroundColor: AppColors.of(context).surface,
        body: BlocBuilder<PaperScreenCubit, PaperScreenState>(
          builder: (context, state) {
            final strings = context.strings;
            return switch (state) {
              PaperScreenLoading() => const _Loading(),
              PaperScreenReady(:final paper, :final imageBytes) => _ReadyBody(
                view: PaperView.from(paper, strings),
                explanation: paper.explanation,
                imageBytes: imageBytes,
                onBack: onBack,
                onRemind: onRemind,
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

class _ReadyBody extends StatefulWidget {
  const _ReadyBody({
    required this.view,
    required this.explanation,
    required this.imageBytes,
    required this.onBack,
    required this.onRemind,
  });

  final PaperView view;
  final PaperExplanation explanation;
  final Uint8List? imageBytes;
  final VoidCallback onBack;
  final void Function(DateTime eventDate, int? eventMinuteOfDay) onRemind;

  @override
  State<_ReadyBody> createState() => _ReadyBodyState();
}

class _ReadyBodyState extends State<_ReadyBody> {
  final _scrollController = ScrollController();
  final _cardKeys = <String, GlobalKey>{};
  var _followsVoice = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) => _cardKeys.putIfAbsent(id, GlobalKey.new);

  void _scrollToCard(String id) {
    final cardContext = _cardKeys[id]?.currentContext;
    if (cardContext == null) return;
    final animate = !MediaQuery.disableAnimationsOf(context);
    unawaited(
      Scrollable.ensureVisible(
        cardContext,
        alignment: _cardAlignment,
        duration: animate ? _scrollDuration : Duration.zero,
        curve: Curves.easeInOut,
      ),
    );
  }

  void _followVoiceTo(VoicePlaybackState state) {
    final activeId = PaperVoiceProgress.of(state).activeId;
    if (!_followsVoice || activeId == null) return;
    _scrollToCard(activeId);
  }

  bool _stopFollowingOnDrag(ScrollStartNotification notification) {
    if (notification.dragDetails != null) _followsVoice = false;
    return false;
  }

  void _onSegmentTap(String id) {
    _followsVoice = true;
    _scrollToCard(id);
    unawaited(context.read<VoicePlaybackCubit>().seekToSegment(id));
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;

    return SafeArea(
      child: Column(
        children: [
          _SegmentsBar(cardIds: view.cardIds, onSegmentTap: _onSegmentTap),
          _PaperHeader(
            view: view,
            imageBytes: widget.imageBytes,
            onBack: widget.onBack,
          ),
          Expanded(
            child: BlocListener<VoicePlaybackCubit, VoicePlaybackState>(
              listenWhen: (previous, current) =>
                  PaperVoiceProgress.of(previous).activeId !=
                  PaperVoiceProgress.of(current).activeId,
              listener: (_, state) => _followVoiceTo(state),
              child: NotificationListener<ScrollStartNotification>(
                onNotification: _stopFollowingOnDrag,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: _bodyPaddingH,
                    vertical: _bodyPaddingV,
                  ),
                  child:
                      BlocSelector<
                        VoicePlaybackCubit,
                        VoicePlaybackState,
                        String?
                      >(
                        selector: (state) =>
                            PaperVoiceProgress.of(state).activeId,
                        builder: (context, activeId) => _CardsSection(
                          cardIds: view.cardIds,
                          activeId: activeId,
                          keyFor: _keyFor,
                          explanation: widget.explanation,
                          dateCard: view.dateCard,
                          groupedPhone: view.groupedPhone,
                          onRemind: widget.onRemind,
                        ),
                      ),
                ),
              ),
            ),
          ),
          const _Player(),
        ],
      ),
    );
  }
}

class _Player extends StatelessWidget {
  const _Player();

  @override
  Widget build(BuildContext context) {
    final voice = context.read<VoicePlaybackCubit>();

    return BlocSelector<
      VoicePlaybackCubit,
      VoicePlaybackState,
      PaperPlayerView
    >(
      selector: PaperPlayerView.of,
      builder: (context, view) => PaperPlayerBar(
        view: view,
        speed: ReadingSpeed.normal,
        onPressed: () => unawaited(switch (view.action) {
          PaperPlayerAction.pause => voice.pause(),
          PaperPlayerAction.resume => voice.resume(),
          PaperPlayerAction.replay => voice.replay(),
        }),
        onSeek: view.canSeek
            ? (fraction) => unawaited(voice.seek(view.duration * fraction))
            : null,
      ),
    );
  }
}

class _SegmentsBar extends StatelessWidget {
  const _SegmentsBar({required this.cardIds, required this.onSegmentTap});

  final List<String> cardIds;
  final ValueChanged<String> onSegmentTap;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.of(context).card,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _headerPaddingH),
        child:
            BlocSelector<
              VoicePlaybackCubit,
              VoicePlaybackState,
              PaperVoiceProgress
            >(
              selector: PaperVoiceProgress.of,
              builder: (context, progress) => PaperStatusSegments(
                cardIds: cardIds,
                activeId: progress.activeId,
                fillFraction: progress.fillFraction,
                onSegmentTap: onSegmentTap,
              ),
            ),
      ),
    );
  }
}

const double _cardGap = 12;
const double _cardAlignment = 0.05;
const Duration _scrollDuration = Duration(milliseconds: 350);

class _CardsSection extends StatelessWidget {
  const _CardsSection({
    required this.cardIds,
    required this.activeId,
    required this.keyFor,
    required this.explanation,
    required this.dateCard,
    required this.groupedPhone,
    required this.onRemind,
  });

  final List<String> cardIds;
  final String? activeId;
  final GlobalKey Function(String id) keyFor;
  final PaperExplanation explanation;
  final PaperDateCardView? dateCard;
  final String? groupedPhone;
  final void Function(DateTime eventDate, int? eventMinuteOfDay) onRemind;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      for (final id in cardIds)
        if (_cardFor(
              context,
              id,
              isHighlighted: id == activeId,
              explanation: explanation,
              dateCard: dateCard,
              groupedPhone: groupedPhone,
              onRemind: onRemind,
            )
            case final card?)
          KeyedSubtree(key: keyFor(id), child: card),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, card) in cards.indexed) ...[
          if (index > 0) const SizedBox(height: _cardGap),
          card,
        ],
      ],
    );
  }
}

Widget? _cardFor(
  BuildContext context,
  String id, {
  required bool isHighlighted,
  required PaperExplanation explanation,
  required PaperDateCardView? dateCard,
  required String? groupedPhone,
  required void Function(DateTime eventDate, int? eventMinuteOfDay) onRemind,
}) => switch (id) {
  'explain' => ExplainCard(
    paragraphs: explanation.paragraphs,
    isHighlighted: isHighlighted,
  ),
  'todo' => TodoCard(text: explanation.todo.text, isHighlighted: isHighlighted),
  'date' => DateCard(
    view: dateCard!,
    isHighlighted: isHighlighted,
    onRemindMe: () =>
        onRemind(explanation.date!.day, explanation.date!.time?.minuteOfDay),
  ),
  'caution' => CautionCard(
    text: explanation.caution!.text,
    isHighlighted: isHighlighted,
  ),
  'contact' => ContactCard(
    name: explanation.contact!.name,
    groupedPhone: groupedPhone!,
    isHighlighted: isHighlighted,
    onCall: () =>
        context.read<PhoneDialerCubit>().dial(explanation.contact!.phone),
  ),
  'place' => PlaceCard(
    address: explanation.place!.text,
    isHighlighted: isHighlighted,
    onEnlarge: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EnlargedAddressScreen(address: explanation.place!.text),
      ),
    ),
  ),
  _ => null,
};

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
