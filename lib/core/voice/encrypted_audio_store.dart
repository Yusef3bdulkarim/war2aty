import 'dart:typed_data';

import '../error/app_failure.dart';
import '../result/result.dart';

/// Encrypts, stores and retrieves voice audio for offline replay (F37-T15).
///
/// The mirror of [DocumentImageStore] for `.m4a` files: the encoder hands over
/// raw bytes ([store]), and the replay player retrieves them ([load]). The
/// store is keyed by a **plain id string** — deliberately not a document id,
/// so F37 stays clear of F36's schema and could have run in parallel.
///
/// No plaintext audio ever rests on disk: [store] encrypts before writing, and
/// [load] decrypts into memory. The only unencrypted copy of a paper's reading
/// is the kernel's own `AudioTrack` buffer, which is transient.
abstract interface class EncryptedAudioStore {
  /// Encrypts [audioBytes] and writes the result to the app-private directory
  /// under [id].
  ///
  /// Returns the encrypted file's path on success, or a failure. The caller
  /// does not use the path — it exists so the store can round-trip through
  /// [load] and for diagnostics.
  Future<Result<String, AppFailure>> store({
    required String id,
    required Uint8List audioBytes,
  });

  /// Decrypts and returns a stored audio's bytes, or a failure if the file is
  /// missing or cannot be decrypted.
  Future<Result<Uint8List, AppFailure>> load(String id);

  /// Deletes a stored audio file, if it exists.
  Future<void> delete(String id);

  /// Deletes every stored audio file in one call.
  Future<void> deleteAll();

  /// Whether an encrypted audio file exists for [id].
  Future<bool> exists(String id);
}
