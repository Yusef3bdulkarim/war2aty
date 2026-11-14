import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/live_voice_event.dart';
import '../../domain/entities/pcm_format.dart';
import '../../domain/services/live_voice_session.dart';
import '../datasources/edge_function_live_token_data_source.dart';

/// A [LiveVoiceSession] that fetches its own ephemeral token when it starts
/// (F37-T21).
///
/// It closes a shape mismatch, and enforces two things of its own: a session
/// is single-use, and a cancel during the token fetch stops the session that
/// fetch was about to open.
/// `ReadPaperAloud` takes a **synchronous** `LiveVoiceSession Function()`,
/// because a session is single-use and a retry needs a second one without
/// awaiting anything mid-read. But the endpoint a session connects to carries
/// a token that is minted per read, 30 minutes' TTL, `uses=1` (T10) — and
/// fetching it is asynchronous. Something has to hold that gap, and the two
/// alternatives were worse: making `openSession` return a `Future` would
/// change a use case with 60-odd tests behind it and spread `await` through
/// the read's hot path, and caching one token for the app's lifetime would
/// hand the second read a credential already spent.
///
/// So the token is fetched inside [start], which is already asynchronous and
/// already the place a session reports that nothing will arrive.
///
/// [format] answers without a token on purpose: `ReadPaperAloud` reads it to
/// reserve the speaker *before* opening the session, and the format is a
/// property of the service, not of the credential — Live always emits
/// [PcmFormat.geminiLive]. Were it fetched, every read would pay a round trip
/// before the first byte of audio.
final class TokenedLiveVoiceSession implements LiveVoiceSession {
  TokenedLiveVoiceSession({
    required LiveTokenDataSource tokens,
    required LiveVoiceSession Function(LiveSessionEndpoint endpoint) build,
  }) : _tokens = tokens,
       _build = build;

  final LiveTokenDataSource _tokens;
  final LiveVoiceSession Function(LiveSessionEndpoint endpoint) _build;

  LiveVoiceSession? _inner;

  /// Whether [cancel] was called before there was an inner session to cancel.
  ///
  /// Without this, `cancel()` during the token fetch is a **silent no-op**:
  /// `_inner` is still null, so there is nothing to close, and when the token
  /// arrives `start` goes on to open the socket anyway. The whole cancel path
  /// in `ReadPaperAloud` then fails, because it ends the frame loop by
  /// *closing the session's stream* — so the user's stop is ignored and the
  /// paper is read to the end over it. The window is the fetch itself, ~450 ms
  /// measured, which is exactly long enough for someone to press play and
  /// immediately change their mind.
  bool _cancelled = false;

  @override
  PcmFormat get format => PcmFormat.geminiLive;

  @override
  Future<Result<void, AppFailure>> start(String turnText) async {
    if (_inner != null) {
      // A session is single-use by contract; starting twice would open a
      // second socket and leak the first.
      return const Err(VoiceServiceFailure());
    }

    final endpoint = await _tokens.fetchEndpoint();
    return endpoint.when(
      // The datasource has already classified this — 401, 429 and offline map
      // to distinct failures (T10), and the ladder reads them to decide
      // whether falling back to the device is allowed. Re-wrapping it here
      // would flatten that.
      err: (failure) async => Err(failure),
      ok: (endpoint) async {
        // The caller gave up while we were fetching. Opening the socket now
        // would send the paper's text to the service and read it aloud over a
        // user who has already pressed stop.
        if (_cancelled) return const Err(VoiceServiceFailure());

        final inner = _build(endpoint);
        _inner = inner;
        return inner.start(turnText);
      },
    );
  }

  @override
  Stream<LiveVoiceEvent> get events {
    final inner = _inner;
    if (inner == null) {
      // Only reachable if a caller subscribes before starting, which
      // `ReadPaperAloud` does not: it reads `events` after `start` answered
      // `Ok`. An empty stream is the honest answer — a session that was never
      // opened has nothing to report, and throwing here would take down a read
      // that could still fall back to the device.
      return const Stream<LiveVoiceEvent>.empty();
    }
    return inner.events;
  }

  @override
  Future<void> cancel() async {
    // Set first, and unconditionally: a cancel that arrives while the token is
    // still in flight has no socket to close, and its whole job is to stop the
    // one that is about to be opened.
    _cancelled = true;
    // Safe twice, as the interface promises — the inner session is itself
    // idempotent.
    await _inner?.cancel();
  }
}
