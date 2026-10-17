import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../audio/audio_reader_cubit.dart';
import '../audio/audio_reader_state.dart';
import '../error/app_failure.dart';
import '../localization/app_localizations.dart';
import 'action_prompt_sheet.dart';

/// Shows whatever the reader could not do, on any screen that has a
/// mini-player (F30-T07).
///
/// Lives here because three screens need exactly this — the analysis result,
/// a saved paper's details, and the OCR review — and all three had their own
/// copy of it before F30 (CLAUDE.md §A2: shared behaviour belongs in
/// `core/`). It replaces a `BlocListener` that showed one snackbar for
/// everything.
///
/// A `BlocListener` rather than a builder, for the reason each of those
/// screens already documented: a reading in progress emits on every progress
/// tick, and rebuilding a whole result page on each one would be wasteful
/// (CLAUDE.md §B8).
///
/// Two failures, told apart because only one of them is the user's to fix:
///
/// - **[NoArabicVoiceFailure]** — the device has no Arabic reading voice, so
///   nothing can read an Arabic paper aloud. A sheet, with a way to the
///   system's text-to-speech settings, because a snackbar that vanishes is
///   no use for something the user has to go and do. The way out is offered
///   only when the device has such a screen to open.
/// - **everything else** — a snackbar, as before.
class AudioReaderFailureListener extends StatelessWidget {
  const AudioReaderFailureListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AudioReaderCubit, AudioReaderState>(
      listenWhen: (previous, current) => current is AudioReaderFailed,
      listener: (context, state) {
        if (state is! AudioReaderFailed) return;
        switch (state.failure) {
          case NoArabicVoiceFailure():
            unawaited(_promptForArabicVoice(context));
          case _:
            _showFailureSnackBar(context);
        }
      },
      child: child,
    );
  }

  void _showFailureSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.strings.audioReaderFailedFeedback)),
      );
  }

  Future<void> _promptForArabicVoice(BuildContext context) async {
    final cubit = context.read<AudioReaderCubit>();
    final strings = context.strings;
    final canOpenSettings = await cubit.canOpenSystemTtsSettings();
    if (!context.mounted) return;

    final wantsSettings = await showActionPromptSheet(
      context,
      title: strings.audioReaderNoArabicVoiceTitle,
      message: strings.audioReaderNoArabicVoiceMessage,
      dismissLabel: strings.audioReaderNoArabicVoiceDismiss,
      // No button at all rather than one that does nothing, on a phone with
      // no such screen to reach.
      actionLabel: canOpenSettings
          ? strings.audioReaderNoArabicVoiceAction
          : null,
    );
    if (!wantsSettings || !context.mounted) return;

    final opened = await cubit.openSystemTtsSettings();
    // It said it could open and then could not. Rare, but silence here would
    // leave the user tapping a button that appears to do nothing
    // (CLAUDE.md §A3).
    if (!opened && context.mounted) _showFailureSnackBar(context);
  }
}
