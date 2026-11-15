import 'dart:convert';
import 'dart:typed_data';

/// A frame received from the Gemini Live WebSocket (F37).
///
/// The three top-level keys the service sends are `setupComplete`,
/// `serverContent` and `error`. Any other key yields [LiveUnknownFrame]
/// rather than a parse failure, so a future field never crashes the session.
sealed class LiveServerFrame {
  const LiveServerFrame();

  factory LiveServerFrame.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('setupComplete')) {
      return const LiveSetupCompleteFrame();
    }
    if (json.containsKey('serverContent')) {
      return LiveContentFrame._parse(
        json['serverContent'] as Map<String, dynamic>,
      );
    }
    if (json.containsKey('error')) {
      return LiveErrorFrame._parse(json['error'] as Map<String, dynamic>);
    }
    return const LiveUnknownFrame();
  }
}

/// The server acknowledged the setup — send the user turn now.
final class LiveSetupCompleteFrame extends LiveServerFrame {
  const LiveSetupCompleteFrame();
}

/// A content frame carrying audio, transcription, or both.
///
/// A single frame may carry any combination: audio only, transcription only,
/// both, or just a completion flag. The [TranscriptAudioAnchor] alignment
/// (T07) hinges on frames that carry both.
final class LiveContentFrame extends LiveServerFrame {
  const LiveContentFrame({
    this.audioChunks = const [],
    this.transcriptionText,
    this.turnComplete = false,
    this.generationComplete = false,
  });

  /// Decoded PCM chunks from `modelTurn.parts[].inlineData.data`.
  final List<Uint8List> audioChunks;

  /// From `serverContent.outputTranscription.text`.
  ///
  /// **Not** `outputAudioTranscription` — that is the *setup* key that
  /// enables this field. The server's response uses a different spelling.
  /// Confusing the two yields an empty transcript, which makes every read
  /// look non-verbatim and silently drops every user to device TTS.
  /// See F37's spike trap #4 and [LiveSetupDto.toJson].
  final String? transcriptionText;

  final bool turnComplete;
  final bool generationComplete;

  bool get hasAudio => audioChunks.isNotEmpty;

  bool get hasTranscription =>
      transcriptionText != null && transcriptionText!.isNotEmpty;

  int get totalAudioBytes {
    var total = 0;
    for (final chunk in audioChunks) {
      total += chunk.length;
    }
    return total;
  }

  factory LiveContentFrame._parse(Map<String, dynamic> server) {
    final audioChunks = <Uint8List>[];
    final modelTurn = server['modelTurn'] as Map<String, dynamic>?;
    if (modelTurn != null) {
      final parts = modelTurn['parts'] as List<dynamic>?;
      if (parts != null) {
        for (final part in parts) {
          final partMap = part as Map<String, dynamic>;
          final inlineData = partMap['inlineData'] as Map<String, dynamic>?;
          final data = inlineData?['data'] as String?;
          if (data != null && data.isNotEmpty) {
            audioChunks.add(base64Decode(data));
          }
        }
      }
    }

    // The transcript field is "outputTranscription", NOT the setup key
    // "outputAudioTranscription". See the class doc and F37 spike trap #4.
    final transcription =
        server['outputTranscription'] as Map<String, dynamic>?;
    final text = transcription?['text'] as String?;

    return LiveContentFrame(
      audioChunks: audioChunks,
      transcriptionText: text,
      turnComplete: server['turnComplete'] == true,
      generationComplete: server['generationComplete'] == true,
    );
  }
}

/// A server error, typically with a close code and message.
final class LiveErrorFrame extends LiveServerFrame {
  const LiveErrorFrame({required this.code, required this.message});

  final int code;
  final String message;

  factory LiveErrorFrame._parse(Map<String, dynamic> error) {
    return LiveErrorFrame(
      code: error['code'] as int? ?? 0,
      message: error['message'] as String? ?? '',
    );
  }
}

/// A frame with no recognised top-level key — ignored rather than fatal.
final class LiveUnknownFrame extends LiveServerFrame {
  const LiveUnknownFrame();
}
