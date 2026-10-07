import 'package:supabase_flutter/supabase_flutter.dart';

import 'secure_storage_service.dart';

/// Persists the Supabase auth session in platform secure storage.
///
/// F27-T16. `Supabase.initialize` was called without `authOptions`, so the SDK
/// installed its own default, `SharedPreferencesLocalStorage`, which writes the
/// whole serialized GoTrue session — the access JWT **and the long-lived
/// refresh token** — into plain `SharedPreferences`. Meanwhile
/// [SecureStorageKeys.session] declared itself as "contains a JWT — must stay
/// encrypted" and was referenced only by the dev-only stub repository. So the
/// control the code described was not the control the app had, and nothing at
/// the call site hinted at it. This class is what makes that declaration true.
///
/// The exposure it closes is narrow and local: an attacker who can read the
/// app's private data directory (a rooted or unlocked device, malware with
/// root, a forensic image) could lift the refresh token and go on minting
/// access tokens for that install from off the device. Such an attacker also
/// already has the Drift database, which holds the plaintext of every analysed
/// paper and is the worse loss — the point is not that this was the crown
/// jewels, but that a credential the code promised to encrypt was not
/// encrypted.
///
/// **No migration, deliberately.** An install that already holds a session in
/// `SharedPreferences` will not find one here and will sign in anonymously
/// again, getting a fresh identity. Nothing a user can see is lost: saved
/// papers, reminders and settings all live in the local database, which is not
/// keyed by the auth user, and [SecureStorageKeys.installationId] is untouched.
/// What it costs is one orphaned anonymous row per existing install, which
/// T07's idle purge collects. Reading the old value would mean taking
/// `shared_preferences` as a direct dependency — it is only transitive today —
/// to serve pre-launch installs, which CLAUDE.md §5 does not justify.
final class SecureSessionLocalStorage extends LocalStorage {
  const SecureSessionLocalStorage(this._storage);

  final SecureStorageService _storage;

  @override
  Future<void> initialize() async {
    // Nothing to open: the keystore/keychain is available on first use.
  }

  @override
  Future<bool> hasAccessToken() async => await _read() != null;

  @override
  Future<String?> accessToken() => _read();

  @override
  Future<void> persistSession(String persistSessionString) async {
    // Swallowed rather than thrown. This runs inside `Supabase.initialize` and
    // on every token refresh; a throw from the first would be caught by
    // `_initializeSupabase` and degrade the whole app to "service
    // unavailable" over a transient keystore error. Failing to persist costs
    // the user a new anonymous identity next launch, which is recoverable;
    // blanking the configuration is not.
    try {
      await _storage.write(SecureStorageKeys.session, persistSessionString);
    } on Object {
      // Intentionally ignored — see above.
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _storage.delete(SecureStorageKeys.session);
    } on Object {
      // Intentionally ignored — see above.
    }
  }

  /// A read that cannot throw: an unreadable store is reported as "no session",
  /// so the app signs in anonymously again instead of refusing to start.
  Future<String?> _read() async {
    try {
      return await _storage.read(SecureStorageKeys.session);
    } on Object {
      return null;
    }
  }
}
