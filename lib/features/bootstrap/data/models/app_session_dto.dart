import '../../domain/entities/app_session.dart';

/// Serialization model for [AppSession].
///
/// `fromJson`/`toJson` are hand-written — no `json_serializable`, no `.g.dart`
/// (CLAUDE.md §3). Keeping this in the data layer means the domain entity never
/// learns about JSON.
final class AppSessionDto {
  const AppSessionDto({
    required this.userId,
    required this.accessToken,
    required this.expiresAtIso,
  });

  factory AppSessionDto.fromJson(Map<String, dynamic> json) {
    return AppSessionDto(
      userId: json['userId'] as String,
      accessToken: json['accessToken'] as String,
      expiresAtIso: json['expiresAt'] as String,
    );
  }

  factory AppSessionDto.fromEntity(AppSession session) {
    return AppSessionDto(
      userId: session.userId,
      accessToken: session.accessToken,
      expiresAtIso: session.expiresAt.toIso8601String(),
    );
  }

  final String userId;
  final String accessToken;
  final String expiresAtIso;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'accessToken': accessToken,
    'expiresAt': expiresAtIso,
  };

  AppSession toEntity() => AppSession(
    userId: userId,
    accessToken: accessToken,
    expiresAt: DateTime.parse(expiresAtIso),
  );
}
