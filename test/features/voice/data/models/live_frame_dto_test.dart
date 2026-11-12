import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/voice/data/models/live_server_frame_dto.dart';
import 'package:war2aty/features/voice/data/models/live_setup_dto.dart';

/// Golden frames modelled on the structures F36-T02's spike sent and received
/// (`supabase/tools/live-spike.ts`). The text is invented; nothing from a
/// real paper is used.

void main() {
  // ── setup DTO (client → server) ───────────────────────────────────────

  group('LiveSetupDto', () {
    test('serialises the four spike conditions', () {
      const dto = LiveSetupDto(
        model: 'models/gemini-2.5-flash-native-audio-latest',
        systemInstruction: 'اقرأ النص التالي بالحرف',
      );
      final json = dto.toJson();

      expect(json.containsKey('setup'), isTrue);
      final setup = json['setup'] as Map<String, dynamic>;

      expect(setup['model'], 'models/gemini-2.5-flash-native-audio-latest');

      final config = setup['generationConfig'] as Map<String, dynamic>;
      expect(config['responseModalities'], ['AUDIO']);
      expect(config['temperature'], 0);

      final instruction = setup['systemInstruction'] as Map<String, dynamic>;
      final parts = instruction['parts'] as List<dynamic>;
      expect(
        (parts[0] as Map<String, dynamic>)['text'],
        'اقرأ النص التالي بالحرف',
      );

      expect(setup.containsKey('outputAudioTranscription'), isTrue);
    });

    test('the setup key is outputAudioTranscription, '
        'not the server key outputTranscription', () {
      const dto = LiveSetupDto(model: 'models/test', systemInstruction: 'read');
      final setup = dto.toJson()['setup'] as Map<String, dynamic>;
      expect(setup.containsKey('outputAudioTranscription'), isTrue);
      expect(setup.containsKey('outputTranscription'), isFalse);
    });
  });

  group('LiveClientContentDto', () {
    test('serialises a single user turn with turnComplete', () {
      const dto = LiveClientContentDto(text: 'النص المراد قراءته');
      final json = dto.toJson();

      expect(json.containsKey('clientContent'), isTrue);
      final content = json['clientContent'] as Map<String, dynamic>;

      final turns = content['turns'] as List<dynamic>;
      expect(turns, hasLength(1));
      final turn = turns[0] as Map<String, dynamic>;
      expect(turn['role'], 'user');
      final parts = turn['parts'] as List<dynamic>;
      expect((parts[0] as Map<String, dynamic>)['text'], 'النص المراد قراءته');

      expect(content['turnComplete'], isTrue);
    });
  });

  // ── server frame DTO (server → client) ────────────────────────────────

  group('LiveServerFrame.fromJson', () {
    test('setup complete', () {
      final frame = LiveServerFrame.fromJson({
        'setupComplete': <String, dynamic>{},
      });
      expect(frame, isA<LiveSetupCompleteFrame>());
    });

    test('content frame with audio only', () {
      // base64("AQID") = bytes [1, 2, 3]
      final frame = LiveServerFrame.fromJson({
        'serverContent': {
          'modelTurn': {
            'parts': [
              {
                'inlineData': {
                  'data': base64Encode(Uint8List.fromList([1, 2, 3])),
                  'mimeType': 'audio/pcm;rate=24000',
                },
              },
            ],
          },
        },
      });

      expect(frame, isA<LiveContentFrame>());
      final content = frame as LiveContentFrame;
      expect(content.hasAudio, isTrue);
      expect(content.hasTranscription, isFalse);
      expect(content.audioChunks, hasLength(1));
      expect(content.audioChunks[0], Uint8List.fromList([1, 2, 3]));
      expect(content.totalAudioBytes, 3);
    });

    test('content frame with transcription only', () {
      final frame = LiveServerFrame.fromJson({
        'serverContent': {
          'outputTranscription': {'text': 'الاجتماع يوم'},
        },
      });

      expect(frame, isA<LiveContentFrame>());
      final content = frame as LiveContentFrame;
      expect(content.hasTranscription, isTrue);
      expect(content.transcriptionText, 'الاجتماع يوم');
      expect(content.hasAudio, isFalse);
    });

    test('content frame with both audio and transcription', () {
      final pcm = Uint8List.fromList(List.generate(48, (i) => i));
      final frame = LiveServerFrame.fromJson({
        'serverContent': {
          'modelTurn': {
            'parts': [
              {
                'inlineData': {
                  'data': base64Encode(pcm),
                  'mimeType': 'audio/pcm;rate=24000',
                },
              },
            ],
          },
          'outputTranscription': {'text': 'روح الاجتماع بنفسك'},
        },
      });

      final content = frame as LiveContentFrame;
      expect(content.hasAudio, isTrue);
      expect(content.hasTranscription, isTrue);
      expect(content.audioChunks[0], pcm);
      expect(content.transcriptionText, 'روح الاجتماع بنفسك');
    });

    test('content frame with turnComplete', () {
      final frame = LiveServerFrame.fromJson({
        'serverContent': {'turnComplete': true},
      });

      final content = frame as LiveContentFrame;
      expect(content.turnComplete, isTrue);
      expect(content.generationComplete, isFalse);
      expect(content.hasAudio, isFalse);
      expect(content.hasTranscription, isFalse);
    });

    test('content frame with generationComplete', () {
      final frame = LiveServerFrame.fromJson({
        'serverContent': {'generationComplete': true},
      });

      final content = frame as LiveContentFrame;
      expect(content.generationComplete, isTrue);
    });

    test('error frame', () {
      final frame = LiveServerFrame.fromJson({
        'error': {
          'code': 1007,
          'message': 'Unknown name "speechConfig" at \'setup\'',
        },
      });

      expect(frame, isA<LiveErrorFrame>());
      final error = frame as LiveErrorFrame;
      expect(error.code, 1007);
      expect(error.message, contains('speechConfig'));
    });

    test('error frame with missing fields defaults gracefully', () {
      final frame = LiveServerFrame.fromJson({'error': <String, dynamic>{}});

      final error = frame as LiveErrorFrame;
      expect(error.code, 0);
      expect(error.message, '');
    });

    test('unknown top-level key yields LiveUnknownFrame', () {
      final frame = LiveServerFrame.fromJson({
        'goAway': {'timeLeft': '30s'},
      });
      expect(frame, isA<LiveUnknownFrame>());
    });

    test('unknown fields inside serverContent are ignored', () {
      final frame = LiveServerFrame.fromJson({
        'serverContent': {
          'outputTranscription': {'text': 'مرحبا'},
          'usageMetadata': {'totalTokenCount': 42},
          'groundingMetadata': {'searchQueries': <String>[]},
        },
      });

      final content = frame as LiveContentFrame;
      expect(content.transcriptionText, 'مرحبا');
    });

    test('multiple audio parts in one frame', () {
      final chunk1 = Uint8List.fromList([10, 20, 30]);
      final chunk2 = Uint8List.fromList([40, 50]);
      final frame = LiveServerFrame.fromJson({
        'serverContent': {
          'modelTurn': {
            'parts': [
              {
                'inlineData': {'data': base64Encode(chunk1)},
              },
              {
                'inlineData': {'data': base64Encode(chunk2)},
              },
            ],
          },
        },
      });

      final content = frame as LiveContentFrame;
      expect(content.audioChunks, hasLength(2));
      expect(content.audioChunks[0], chunk1);
      expect(content.audioChunks[1], chunk2);
      expect(content.totalAudioBytes, 5);
    });

    test('empty inlineData.data is skipped', () {
      final frame = LiveServerFrame.fromJson({
        'serverContent': {
          'modelTurn': {
            'parts': [
              {
                'inlineData': {'data': ''},
              },
              {
                'inlineData': {
                  'data': base64Encode(Uint8List.fromList([7])),
                },
              },
            ],
          },
        },
      });

      final content = frame as LiveContentFrame;
      expect(content.audioChunks, hasLength(1));
      expect(content.audioChunks[0], Uint8List.fromList([7]));
    });

    test('parts without inlineData are skipped', () {
      final frame = LiveServerFrame.fromJson({
        'serverContent': {
          'modelTurn': {
            'parts': [
              <String, dynamic>{'text': 'should not appear here'},
              {
                'inlineData': {
                  'data': base64Encode(Uint8List.fromList([1])),
                },
              },
            ],
          },
        },
      });

      final content = frame as LiveContentFrame;
      expect(content.audioChunks, hasLength(1));
    });

    test('empty serverContent yields a content frame with nothing set', () {
      final frame = LiveServerFrame.fromJson({
        'serverContent': <String, dynamic>{},
      });

      final content = frame as LiveContentFrame;
      expect(content.hasAudio, isFalse);
      expect(content.hasTranscription, isFalse);
      expect(content.turnComplete, isFalse);
      expect(content.generationComplete, isFalse);
    });
  });

  // ── the field-name trap (spike trap #4) ───────────────────────────────
  //
  // `outputAudioTranscription` is the SETUP key that enables transcription.
  // The SERVER frame sends the text at `outputTranscription` — a different
  // spelling. Reading the setup key on a server frame yields null, which
  // makes every read look non-verbatim and silently drops every user to
  // device TTS. This test exists because of that.

  group('field-name asymmetry (spike trap #4)', () {
    test('server frame reads outputTranscription, '
        'not the setup key outputAudioTranscription', () {
      // A frame with the CORRECT server key
      final correct = LiveServerFrame.fromJson({
        'serverContent': {
          'outputTranscription': {'text': 'الاجتماع يوم'},
        },
      });
      expect((correct as LiveContentFrame).transcriptionText, 'الاجتماع يوم');

      // The same text under the SETUP key — the parser must NOT read it
      final wrong = LiveServerFrame.fromJson({
        'serverContent': {
          'outputAudioTranscription': {'text': 'الاجتماع يوم'},
        },
      });
      expect(
        (wrong as LiveContentFrame).transcriptionText,
        isNull,
        reason:
            'outputAudioTranscription is the setup key; '
            'the server frame uses outputTranscription',
      );
    });

    test('setup DTO writes outputAudioTranscription, '
        'server DTO reads outputTranscription — '
        'the two keys are provably different', () {
      // What the client sends
      const setup = LiveSetupDto(
        model: 'models/test',
        systemInstruction: 'read',
      );
      final setupJson = setup.toJson()['setup'] as Map<String, dynamic>;
      final setupKey = setupJson.keys
          .where((k) => k.toLowerCase().contains('transcription'))
          .single;

      // What the server sends
      final serverFrame =
          LiveServerFrame.fromJson({
                'serverContent': {
                  'outputTranscription': {'text': 'x'},
                },
              })
              as LiveContentFrame;

      // The setup key and the server key are spelled differently
      expect(setupKey, 'outputAudioTranscription');
      expect(serverFrame.transcriptionText, 'x');

      // And a frame using the setup spelling yields nothing
      final misread =
          LiveServerFrame.fromJson({
                'serverContent': {
                  setupKey: {'text': 'x'},
                },
              })
              as LiveContentFrame;
      expect(misread.transcriptionText, isNull);
    });
  });
}
