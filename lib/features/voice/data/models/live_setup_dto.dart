/// The setup frame that opens a Gemini Live session.
///
/// The four conditions that produced 0.0 % WER in F36-T02's spike are
/// hard-wired: `responseModalities: ["AUDIO"]`, `temperature: 0`, the
/// verbatim `systemInstruction`, and `outputAudioTranscription: {}`.
/// Changing any of them reopens the product gate.
final class LiveSetupDto {
  const LiveSetupDto({required this.model, required this.systemInstruction});

  final String model;
  final String systemInstruction;

  /// Serialises the full `{ "setup": { … } }` WebSocket message.
  ///
  /// The key that enables transcription is `outputAudioTranscription` — with
  /// "Audio" in the name. The server's *response* carries the text at the
  /// differently-spelled `outputTranscription`. See [LiveContentFrame] and
  /// F37's spike trap #4.
  Map<String, dynamic> toJson() => {
    'setup': {
      'model': model,
      'generationConfig': {
        'responseModalities': ['AUDIO'],
        'temperature': 0,
      },
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction},
        ],
      },
      'outputAudioTranscription': <String, dynamic>{},
    },
  };
}

/// The user turn sent after the server acknowledges setup.
///
/// Carries the paper's text as a single user turn with `turnComplete: true`.
final class LiveClientContentDto {
  const LiveClientContentDto({required this.text});

  final String text;

  Map<String, dynamic> toJson() => {
    'clientContent': {
      'turns': [
        {
          'role': 'user',
          'parts': [
            {'text': text},
          ],
        },
      ],
      'turnComplete': true,
    },
  };
}
