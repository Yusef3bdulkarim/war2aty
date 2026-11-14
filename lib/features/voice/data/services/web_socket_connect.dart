import 'package:web_socket_channel/web_socket_channel.dart';

/// Opens a real WebSocket, and does not return until it is usable (F37-T21).
///
/// `GeminiLiveVoiceSession` takes its connector as a function so every test can
/// drive a `StreamChannelController` instead of a socket. This is the one
/// production implementation of that function, and it lives here rather than in
/// `app/di` so `web_socket_channel` stays inside the data layer with the other
/// plugin imports.
///
/// Awaiting [WebSocketChannel.ready] is the whole point. `connect` returns a
/// channel immediately, before the handshake has happened, so a refused or
/// unreachable endpoint surfaces later as an error on the stream — by which
/// time the session has already reported success and the read has told the user
/// it is starting. Awaiting it turns that into a thrown connection error the
/// session converts into a failure, which is what lets the ladder fall back to
/// the device before anyone hears silence.
Future<WebSocketChannel> connectWebSocket(Uri uri) async {
  final channel = WebSocketChannel.connect(uri);
  await channel.ready;
  return channel;
}
