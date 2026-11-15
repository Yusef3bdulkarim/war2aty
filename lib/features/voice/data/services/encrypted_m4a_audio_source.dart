// ignore_for_file: experimental_member_use
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

/// A [StreamAudioSource] that serves range requests from a fully decrypted
/// in-memory buffer (F37-T16).
///
/// AES-GCM is an AEAD cipher with no random-access mode: you cannot decrypt
/// byte 50 000 without decrypting bytes 0–49 999 first. For a 0.3 MB `.m4a`
/// that is not a problem — the entire file fits comfortably in memory — so
/// the buffer is decrypted once and served from RAM for every range request
/// `just_audio` makes during playback and seeking.
///
/// **Decrypt-to-cache fallback.** If in-memory playback causes issues on
/// cheap devices (out-of-memory on a phone with < 1 GB free, or
/// `just_audio`'s platform player failing to consume a [StreamAudioSource]
/// on old Android versions), the alternative is:
/// 1. Write the decrypted bytes to a temp file in the app's cache directory.
/// 2. Use [AudioSource.file] instead of this source.
/// 3. Delete the temp file in `dispose()` / `finally`.
/// At 0.3 MB the window where plaintext sits on disk is brief and inside
/// the app-private directory, so the trade-off is acceptable. This path is
/// not built here because the in-memory approach should work on any phone
/// that can run the rest of the app — it is documented for the next person
/// who hits a device-specific failure.
final class EncryptedM4aAudioSource extends StreamAudioSource {
  EncryptedM4aAudioSource(this._buffer);

  final Uint8List _buffer;

  /// The total byte length of the decrypted audio.
  int get length => _buffer.length;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final effectiveStart = start ?? 0;
    final effectiveEnd = end ?? _buffer.length;

    return StreamAudioResponse(
      sourceLength: _buffer.length,
      contentLength: effectiveEnd - effectiveStart,
      offset: effectiveStart,
      contentType: 'audio/mp4',
      stream: Stream.value(_buffer.sublist(effectiveStart, effectiveEnd)),
    );
  }
}
