/// The analysis quota for one Africa/Cairo day.
///
/// The backend owns these numbers; the app mirrors them locally so the Home
/// screen can show "you have N left today" instantly and offline.
final class DailyUsage {
  const DailyUsage({
    required this.usageDate,
    required this.dailyLimit,
    required this.usedCount,
    required this.remainingCount,
    required this.resetsAt,
    this.lastSyncedAt,
    this.azureOcrEnabled = false,
  });

  /// Cairo calendar day this quota belongs to (date-only, UTC midnight).
  final DateTime usageDate;

  final int dailyLimit;
  final int usedCount;
  final int remainingCount;

  /// When the quota resets (end of the Cairo day, in UTC).
  final DateTime resetsAt;

  /// Last successful sync with the backend; `null` before the first one.
  final DateTime? lastSyncedAt;

  /// Whether the backend's online Azure/Google image pipeline is live right
  /// now (F13). Read by [DecideAnalysisRoute] before routing a capture
  /// online — connectivity alone is not enough, since the pipeline is
  /// dark-launched behind this same flag server-side (`RuntimeConfig`
  /// §`azureOcrEnabled`), and a mismatch there is a dead-end retry loop, not
  /// a harmless no-op (locked decision #2 forbids falling back once online
  /// is chosen).
  ///
  /// Only a *fresh* sync (`UsageRepository.syncUsage`) carries the real
  /// value — a reading reconstructed from the local cache always defaults
  /// this to `false`, since the flag is not persisted there. That is a
  /// deliberate fail-closed default (matches the server's own `optInFlag`
  /// philosophy for this flag), not an oversight: a stale "yes" is the
  /// dangerous direction to be wrong in, a stale "no" only costs one
  /// avoidable offline-route capture.
  final bool azureOcrEnabled;

  /// Whether the user can still run an analysis today.
  bool get hasQuotaLeft => remainingCount > 0;

  @override
  bool operator ==(Object other) =>
      other is DailyUsage &&
      other.usageDate == usageDate &&
      other.dailyLimit == dailyLimit &&
      other.usedCount == usedCount &&
      other.remainingCount == remainingCount &&
      other.resetsAt == resetsAt &&
      other.lastSyncedAt == lastSyncedAt &&
      other.azureOcrEnabled == azureOcrEnabled;

  @override
  int get hashCode => Object.hash(
    usageDate,
    dailyLimit,
    usedCount,
    remainingCount,
    resetsAt,
    lastSyncedAt,
    azureOcrEnabled,
  );
}
