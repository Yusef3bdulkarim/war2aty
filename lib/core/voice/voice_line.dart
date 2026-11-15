/// The fixed spoken UI lines, bundled as audio assets (F37-T20).
///
/// Every important message in a non-reader's app has to be *heard*, not read.
/// If these were spoken by Gemini Live or by device TTS at the moment they
/// appear, each one would be silent in exactly the situation that produces it:
/// the user with no connection reaches the offline screen and hears nothing,
/// and the user with no Arabic voice installed reaches the failure screen and
/// hears nothing. So they are generated once — by
/// `supabase/tools/generate-voice-lines.ts`, in the same Live voice a paper is
/// read in — and shipped inside the APK.
///
/// The Arabic for each line lives in `docs/features/F37-voice-lines.md`, which
/// the generator reads. That table is the source of truth for the wording; this
/// enum is the source of truth for the set of lines. `voice_line_test.dart`
/// asserts the two agree **in both directions**, so a line renamed in one place
/// and not the other cannot ship as silence.
///
/// [id] is the snake_case id in the table and the asset's filename. The enum
/// value's own name is never used as the id — renaming a Dart constant must not
/// be able to move a file path.
enum VoiceLine {
  /// Crop screen, once the photo is shown: «اضغط كمّل.»
  cropContinue('crop_continue'),

  /// Waiting screen, on open: «استنى شوية وأنا بقراها.»
  waitingReading('waiting_reading'),

  /// Failure screen, `offline` — no connection.
  failOffline('fail_offline'),

  /// Failure screen, `limitReached` — the daily papers are spent.
  failLimit('fail_limit'),

  /// Failure screen, `unsupported` — the paper could not be read.
  failUnsupported('fail_unsupported'),

  /// Failure screen, `serviceProblem` — the service could not answer.
  failService('fail_service'),

  /// No Arabic voice is installed on the phone (F30-T07's escape hatch).
  ///
  /// This line is a bundled asset **by necessity**, not by preference: it is
  /// the one state in which device TTS cannot say anything at all.
  noArabicVoice('no_arabic_voice'),

  /// Both voice tiers failed, so the explanation can only be read on screen.
  voiceFailed('voice_failed'),

  /// مستنداتي, with no saved papers yet.
  docsEmpty('docs_empty'),

  /// مستنداتي, confirming a delete.
  docsDeleteConfirm('docs_delete_confirm'),

  /// مستنداتي, after a delete went through.
  ///
  /// Deleting cannot be undone, so someone who cannot read the list needs to
  /// hear that what they asked for actually happened.
  docsDeleteDone('docs_delete_done'),

  /// Camera permission denied: a dead end, and unreadable without this line.
  cameraPermission('camera_permission');

  const VoiceLine(this.id);

  /// The id in `docs/features/F37-voice-lines.md`, and the asset's basename.
  final String id;

  /// Where the generator writes this line, and where `just_audio` loads it.
  String get assetPath => '$assetDirectory/$id.m4a';

  /// The directory every fixed line is bundled under.
  static const String assetDirectory = 'assets/voice_lines';

  /// The line with this [id], or `null` when no line carries it.
  static VoiceLine? byId(String id) {
    for (final line in VoiceLine.values) {
      if (line.id == id) return line;
    }
    return null;
  }
}
