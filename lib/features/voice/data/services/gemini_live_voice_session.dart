import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/live_voice_event.dart';
import '../../domain/entities/pcm_format.dart';
import '../../domain/services/live_voice_session.dart';
import '../models/live_server_frame_dto.dart';
import '../models/live_setup_dto.dart';

/// A [LiveVoiceSession] backed by a Gemini Live WebSocket (F37-T09).
///
/// The only file in the app that imports `web_socket_channel`. Everything
/// else reaches the voice service through the [LiveVoiceSession] interface.
///
/// The four conditions that produced 0.0 % WER in the spike are hard-wired:
/// `responseModalities: ["AUDIO"]`, `temperature: 0`, the verbatim system
/// instruction, and `outputAudioTranscription` enabled. A caller cannot vary
/// them.
///
/// Two watchdogs guard the session: an inter-frame watchdog that fires when no
/// frame arrives for [interFrameTimeout], and a total watchdog that fires when
/// the entire session exceeds [totalTimeout]. Either yields a
/// [LiveSessionLost] with the appropriate [AppFailure].
final class GeminiLiveVoiceSession implements LiveVoiceSession {
  GeminiLiveVoiceSession({
    required Uri endpoint,
    required String model,
    required Future<WebSocketChannel> Function(Uri uri) connect,
    Duration interFrameTimeout = const Duration(seconds: 10),
    Duration totalTimeout = const Duration(seconds: 60),
  }) : _endpoint = endpoint,
       _model = model,
       _connect = connect,
       _interFrameTimeout = interFrameTimeout,
       _totalTimeout = totalTimeout;

  static const _systemInstruction =
      'اقرأ النص التالي بالحرف، كلمة بكلمة، من غير أي إضافة أو تعليق أو ترحيب، '
      'ومن غير ما تغيّر أي كلمة أو رقم أو تاريخ. متقولش حاجة غير النص نفسه.';

  final Uri _endpoint;
  final String _model;
  final Future<WebSocketChannel> Function(Uri uri) _connect;
  final Duration _interFrameTimeout;
  final Duration _totalTimeout;

  final _events = StreamController<LiveVoiceEvent>();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _interFrameTimer;
  Timer? _totalTimer;
  int _audioBytes = 0;
  bool _started = false;
  bool _finished = false;

  @override
  PcmFormat get format => PcmFormat.geminiLive;

  @override
  Stream<LiveVoiceEvent> get events => _events.stream;

  @override
  Future<Result<void, AppFailure>> start(String turnText) async {
    if (_started) return const Err(VoiceServiceFailure());
    _started = true;

    try {
      final channel = await _connect(_endpoint);
      _channel = channel;

      final setupDone = Completer<void>();

      _sub = channel.stream.listen(
        (data) {
          try {
            _resetInterFrameTimer();

            Map<String, dynamic> json;
            try {
              json = jsonDecode(data as String) as Map<String, dynamic>;
            } catch (_) {
              return;
            }

            final frame = LiveServerFrame.fromJson(json);
            switch (frame) {
              case LiveSetupCompleteFrame():
                if (!setupDone.isCompleted) {
                  channel.sink.add(
                    jsonEncode(LiveClientContentDto(text: turnText).toJson()),
                  );
                  setupDone.complete();
                }
              case LiveContentFrame():
                _onContent(frame);
              case LiveErrorFrame():
                if (!setupDone.isCompleted) {
                  setupDone.completeError(const VoiceServiceFailure());
                }
                _emitLoss(const VoiceServiceFailure());
              case LiveUnknownFrame():
                break;
            }
          } catch (e) {
            if (!setupDone.isCompleted) {
              setupDone.completeError(const VoiceServiceFailure());
            }
            _emitLoss(const VoiceServiceFailure());
          }
        },
        onError: (Object _) {
          if (!setupDone.isCompleted) {
            setupDone.completeError(const VoiceServiceFailure());
          }
          _emitLoss(const VoiceServiceFailure());
        },
        onDone: () {
          if (!setupDone.isCompleted) {
            setupDone.completeError(const VoiceServiceFailure());
          }
          _onSocketDone();
        },
      );

      _totalTimer = Timer(_totalTimeout, _onTotalTimeout);
      _resetInterFrameTimer();

      channel.sink.add(
        jsonEncode(
          LiveSetupDto(
            model: 'models/$_model',
            systemInstruction: _systemInstruction,
          ).toJson(),
        ),
      );

      await setupDone.future;
      return const Ok(null);
    } catch (_) {
      await cancel();
      return const Err(VoiceServiceFailure());
    }
  }

  void _onContent(LiveContentFrame frame) {
    for (final chunk in frame.audioChunks) {
      _audioBytes += chunk.length;
      if (!_events.isClosed) _events.add(LivePcmChunk(chunk));
    }
    if (frame.hasTranscription) {
      if (!_events.isClosed) {
        _events.add(LiveTranscriptDelta(frame.transcriptionText!));
      }
    }
    if (frame.turnComplete || frame.generationComplete) {
      _completeSuccessfully();
    }
  }

  void _onSocketDone() {
    if (_finished) return;
    _emitLoss(
      _audioBytes > 0
          ? VoiceStreamInterruptedFailure(format.durationOfBytes(_audioBytes))
          : const VoiceServiceFailure(),
    );
  }

  void _onTotalTimeout() {
    if (_finished) return;
    _emitLoss(
      _audioBytes > 0
          ? VoiceStreamInterruptedFailure(format.durationOfBytes(_audioBytes))
          : const VoiceServiceFailure(),
    );
  }

  void _completeSuccessfully() {
    if (_finished) return;
    _finished = true;
    _cancelTimers();
    _events
      ..add(const LiveTurnComplete())
      ..close();
    _closeSocket();
  }

  void _emitLoss(AppFailure failure) {
    if (_finished) return;
    _finished = true;
    _cancelTimers();
    _events
      ..add(LiveSessionLost(failure))
      ..close();
    _closeSocket();
  }

  void _resetInterFrameTimer() {
    _interFrameTimer?.cancel();
    if (_finished) return;
    _interFrameTimer = Timer(_interFrameTimeout, () {
      if (_finished) return;
      _emitLoss(
        _audioBytes > 0
            ? VoiceStreamInterruptedFailure(format.durationOfBytes(_audioBytes))
            : const VoiceServiceFailure(),
      );
    });
  }

  void _cancelTimers() {
    _interFrameTimer?.cancel();
    _totalTimer?.cancel();
  }

  void _closeSocket() {
    unawaited(_sub?.cancel());
    try {
      _channel?.sink.close();
    } catch (_) {
      // Already closed or never opened.
    }
  }

  @override
  Future<void> cancel() async {
    if (!_finished) {
      _finished = true;
      _cancelTimers();
      if (!_events.isClosed) unawaited(_events.close());
    }
    _closeSocket();
  }
}
