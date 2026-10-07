import 'error_report_dto.dart';
import 'error_report_remote_data_source.dart';
import 'log_sink.dart';

/// F27-T12 / H1 · The production [LogSink]: reports failures to our own
/// backend, and nothing else.
///
/// Production used to run on [NoopLogSink], so a crash or a failing analysis
/// in the field produced no signal anywhere. Q13 settled where the signal
/// goes: **our own table behind an Edge Function that accepts only
/// allowlisted codes** — not a third-party crash reporter, which could not be
/// shown never to receive document content, and would break the free-tier
/// rule besides.
///
/// Four rules keep a reporting channel from becoming a liability of its own:
///
/// 1. **Only failures leave the device.** [ErrorReportDto.fromLogFields]
///    returns null for any record without an `errorCode`, so volume tracks
///    defects, not usage.
/// 2. **Never block, never throw.** [write] returns the instant the request is
///    started, and every error from the send is swallowed. A log line is not
///    worth a frame, let alone an exception.
/// 3. **No recursion.** A failed report would normally be logged — which would
///    report it, which would fail. Records produced while a send is in flight
///    are dropped. The transport's client also has no log interceptor, so
///    there are two independent reasons this cannot loop.
/// 4. **A ceiling per session.** A crash loop can emit thousands of errors a
///    minute. [maxReportsPerSession] is the stop: enough to see what broke,
///    far too few to drain a free-tier quota or flood the table.
final class ErrorReportSink implements LogSink {
  ErrorReportSink(this._remote, {this.maxReportsPerSession = 20});

  final ErrorReportRemoteDataSource _remote;

  /// How many reports one app run may send. Reached, the sink goes quiet for
  /// the rest of the session.
  final int maxReportsPerSession;

  int _sent = 0;
  bool _sending = false;

  /// Reports sent (or attempted) so far this session — for tests and for the
  /// ceiling.
  int get sentCount => _sent;

  @override
  void write(Map<String, Object> fields) {
    if (_sending || _sent >= maxReportsPerSession) return;

    final report = ErrorReportDto.fromLogFields(fields);
    if (report == null) return;

    _sent++;
    _sending = true;

    // Fire and forget. `catchError` rather than `await`: `write` is
    // synchronous by contract, and the caller is a logger on some other
    // code path's hot line.
    try {
      _remote
          .send(report)
          .catchError((Object _) {})
          .whenComplete(() => _sending = false);
    } on Object {
      // A transport that throws synchronously instead of returning a failed
      // future. Rare, but it must not escape a log call.
      _sending = false;
    }
  }
}
