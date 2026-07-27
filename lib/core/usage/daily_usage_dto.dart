import 'daily_usage.dart';

/// Wire representation of the get-usage body (API_CONTRACT §32).
///
/// Hand-written `fromJson` — no `json_serializable`, no `.g.dart` (CLAUDE.md
/// §3). Enum-free and value-only: the backend owns these numbers, the app only
/// mirrors them.
final class DailyUsageDto {
  const DailyUsageDto({
    required this.schemaVersion,
    required this.usageDate,
    required this.dailyLimit,
    required this.usedToday,
    required this.remainingToday,
    required this.resetsAt,
    required this.analysisEnabled,
  });

  factory DailyUsageDto.fromJson(Map<String, dynamic> json) {
    return DailyUsageDto(
      schemaVersion: json['schema_version'] as String,
      usageDate: json['usage_date'] as String,
      dailyLimit: json['daily_limit'] as int,
      usedToday: json['used_today'] as int,
      remainingToday: json['remaining_today'] as int,
      resetsAt: json['resets_at'] as String,
      analysisEnabled: json['analysis_enabled'] as bool,
    );
  }

  final String schemaVersion;

  /// The Africa/Cairo calendar day, `YYYY-MM-DD`.
  final String usageDate;
  final int dailyLimit;
  final int usedToday;
  final int remainingToday;

  /// ISO-8601 with Cairo's real offset (`+02:00` or `+03:00` under DST).
  final String resetsAt;
  final bool analysisEnabled;

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'usage_date': usageDate,
    'daily_limit': dailyLimit,
    'used_today': usedToday,
    'remaining_today': remainingToday,
    'resets_at': resetsAt,
    'analysis_enabled': analysisEnabled,
  };

  /// @param syncedAt stamped by the caller so the entity records when this
  /// reading was actually obtained, not when it happened to be parsed.
  DailyUsage toEntity({required DateTime syncedAt}) {
    return DailyUsage(
      usageDate: _parseDay(usageDate),
      dailyLimit: dailyLimit,
      usedCount: usedToday,
      remainingCount: remainingToday,
      resetsAt: DateTime.parse(resetsAt).toUtc(),
      lastSyncedAt: syncedAt.toUtc(),
    );
  }

  /// `YYYY-MM-DD` as a UTC-midnight date, matching [DailyUsage.usageDate].
  ///
  /// Built explicitly rather than via `DateTime.parse`, which returns a *local*
  /// midnight for a bare date — that would land on the previous day for any
  /// device east of UTC and silently mis-group the row in the cache.
  static DateTime _parseDay(String day) {
    final parts = day.split('-');
    if (parts.length != 3) {
      throw FormatException('Not a YYYY-MM-DD day', day);
    }

    return DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}
