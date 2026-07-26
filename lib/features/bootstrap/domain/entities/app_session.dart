/// An authenticated anonymous session.
///
/// Pure domain entity — no Flutter, no Supabase. There is no login screen in
/// this app: the session is a technical identity that protects the backend, it
/// carries no personal data about the user.
final class AppSession {
  const AppSession({
    required this.userId,
    required this.accessToken,
    required this.expiresAt,
  });

  /// Anonymous user id issued by the auth backend.
  final String userId;

  /// Short-lived JWT used to call the analysis Edge Function.
  final String accessToken;

  final DateTime expiresAt;

  /// Whether the session is no longer usable at [now].
  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  @override
  bool operator ==(Object other) =>
      other is AppSession &&
      other.userId == userId &&
      other.accessToken == accessToken &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(userId, accessToken, expiresAt);

  // Deliberately omits the token from toString so it can never land in a log.
  @override
  String toString() => 'AppSession(userId: $userId, expiresAt: $expiresAt)';
}
