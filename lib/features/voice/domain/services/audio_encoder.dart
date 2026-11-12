import 'dart:typed_data';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/pcm_format.dart';

/// Compresses a reading so it can be kept (F37).
///
/// Raw audio is 48 KB a second, so a 75-second paper is ~3.6 MB and fifty
/// papers would be ~180 MB. AAC-LC in an `.m4a` at 24 kHz mono, 32 kbps brings
/// that to ~0.3 MB a paper, which is the budget the 850-character page cap was
/// chosen against (`docs/API_CONTRACT.md` §33.3). It is also iOS's own native
/// format, so a paper saved now plays unchanged when iOS lands.
///
/// An interface because the encoder is the platform's, not ours — a bundled
/// encoder was rejected at 10–40 MB of APK and a GPL licence.
abstract interface class AudioEncoder {
  /// Starts a new file and prepares to accept [format].
  Future<Result<void, AppFailure>> begin(PcmFormat format);

  /// Adds [chunk] to the file being written.
  ///
  /// Fed from the same stream the speaker is playing, so the file is written
  /// while the user listens. Keeps accepting chunks even while playback is
  /// paused: a paused encoder produces a corrupt file, and the user pausing has
  /// nothing to do with what is being saved.
  Future<void> feed(Uint8List chunk);

  /// Closes the file and returns the encoded bytes.
  ///
  /// Returned in memory rather than written to a path, because the only
  /// permitted resting place is encrypted — handing back a plaintext file would
  /// mean a readable recording of someone's paper sitting on disk, however
  /// briefly.
  Future<Result<Uint8List, AppFailure>> finish();

  /// Throws away a partial file.
  ///
  /// Called whenever a read did not reach the end. A saved paper whose offline
  /// replay stops mid-sentence, permanently, is worse than a paper with no
  /// audio at all: the second can be re-read, the first looks like the app lost
  /// half the page.
  Future<void> abort();
}
