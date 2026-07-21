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
      other.lastSyncedAt == lastSyncedAt;

  @override
  int get hashCode => Object.hash(
    usageDate,
    dailyLimit,
    usedCount,
    remainingCount,
    resetsAt,
    lastSyncedAt,
  );
}
