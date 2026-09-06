/// The plain-Egyptian-Arabic explanation of what the paper says.
final class AnalysisSummary {
  const AnalysisSummary({required this.short, required this.detailed});

  /// One-liner for the result header and the recent-documents strip.
  final String short;

  /// The full explanation shown in the result body and read aloud by TTS.
  final String detailed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisSummary &&
          other.short == short &&
          other.detailed == detailed;

  @override
  int get hashCode => Object.hash(short, detailed);

  // The summary text is document content — it quotes the paper's amounts,
  // dates and parties — so it is never printed (privacy §7). Lengths only.
  @override
  String toString() =>
      'AnalysisSummary(${short.length}/${detailed.length} chars)';
}
