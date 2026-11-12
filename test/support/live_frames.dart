import 'dart:convert';
import 'dart:typed_data';

/// Golden WebSocket frames modelled on F36-T02's spike
/// (`supabase/tools/live-spike.ts`).
///
/// Used by [GeminiLiveVoiceSession] tests to drive a fake socket with
/// realistic server messages. The text and audio are invented; nothing
/// from a real paper is used.

const setupCompleteFrame = '{"setupComplete":{}}';

String audioFrame(Uint8List pcm) {
  final b64 = base64Encode(pcm);
  return jsonEncode({
    'serverContent': {
      'modelTurn': {
        'parts': [
          {
            'inlineData': {'mimeType': 'audio/pcm', 'data': b64},
          },
        ],
      },
    },
  });
}

String transcriptFrame(String text) {
  return jsonEncode({
    'serverContent': {
      'outputTranscription': {'text': text},
    },
  });
}

String audioAndTranscriptFrame(Uint8List pcm, String text) {
  final b64 = base64Encode(pcm);
  return jsonEncode({
    'serverContent': {
      'modelTurn': {
        'parts': [
          {
            'inlineData': {'mimeType': 'audio/pcm', 'data': b64},
          },
        ],
      },
      'outputTranscription': {'text': text},
    },
  });
}

String turnCompleteFrame({bool generation = false}) {
  return jsonEncode({
    'serverContent': {
      if (generation) 'generationComplete': true else 'turnComplete': true,
    },
  });
}

String errorFrame({int code = 400, String message = 'test error'}) {
  return jsonEncode({
    'error': {'code': code, 'message': message},
  });
}

/// 480 bytes = 10 ms of Gemini Live PCM (24 kHz, 16-bit, mono).
Uint8List testPcmChunk([int fillByte = 0x42]) =>
    Uint8List.fromList(List.filled(480, fillByte));

/// 48 000 bytes = 1 second of Gemini Live PCM.
Uint8List testPcmOneSecond([int fillByte = 0x42]) =>
    Uint8List.fromList(List.filled(48000, fillByte));
