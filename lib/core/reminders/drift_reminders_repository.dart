import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/daos/reminders_dao.dart';
import '../error/app_failure.dart';
import '../identity/installation_id_provider.dart';
import '../result/result.dart';
import 'notification_id.dart';
import 'reminder.dart';
import 'reminder_alert_status.dart';
import 'reminder_read_mapper.dart';
import 'reminder_write_mapper.dart';
import 'reminders_repository.dart';

/// [RemindersRepository] backed by the local Drift database.
///
/// The error boundary for reminders: drift throws, this catches, and
/// everything above it sees a [Result] (CLAUDE.md §B5). The caught object is
/// deliberately not inspected or logged — a title or note is document/user
/// content, and a database exception on a write can carry the row it failed
/// on (§7).
final class DriftRemindersRepository implements RemindersRepository {
  DriftRemindersRepository(
    this._dao, {
    IdGenerator? idGenerator,
    DateTime Function()? clock,
  }) : _generateId = idGenerator ?? (() => const Uuid().v4()),
       _now = clock ?? DateTime.now;

  final RemindersDao _dao;
  final IdGenerator _generateId;
  final DateTime Function() _now;

  @override
  Stream<Result<List<Reminder>, AppFailure>> watchReminders() {
    return _dao
        .watchReminders()
        .map<Result<List<Reminder>, AppFailure>>(
          (bundles) => Ok(bundles.map(reminderOf).toList()),
        )
        .transform(_errorsToFailures());
  }

  @override
  Stream<Result<Reminder?, AppFailure>> watchReminder(String id) {
    return _dao
        .watchReminderById(id)
        .map<Result<Reminder?, AppFailure>>(
          (bundle) => Ok(bundle == null ? null : reminderOf(bundle)),
        )
        .transform(_errorsToFailures());
  }

  @override
  Future<Result<Reminder, AppFailure>> createReminder({
    String? documentId,
    required String title,
    String? description,
    required DateTime eventDate,
    int? eventMinuteOfDay,
    required bool isManual,
    required List<DateTime> alertTimes,
  }) async {
    final id = _generateId();
    final now = _now();

    try {
      await _dao.saveReminder(
        reminderWriteOf(
          id: id,
          documentId: documentId,
          title: title,
          description: description,
          eventDate: eventDate,
          eventMinuteOfDay: eventMinuteOfDay,
          isManual: isManual,
          alertTimes: alertTimes,
          alertIds: [for (final _ in alertTimes) _generateId()],
          now: now,
        ),
      );

      final bundle = await _dao.reminderById(id);
      // Written a moment ago by this same call — always there.
      return Ok(reminderOf(bundle!));
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }

  @override
  Future<Result<void, AppFailure>> updateReminder(
    String id, {
    String? title,
    String? description,
    bool clearDescription = false,
    List<DateTime>? alertTimes,
  }) async {
    try {
      await _dao.updateReminder(
        id,
        title: title,
        description: clearDescription
            ? const Value(null)
            : (description == null ? const Value.absent() : Value(description)),
        updatedAt: _now(),
      );
      if (alertTimes != null) {
        await _dao.replaceAlerts(id, _alertCompanions(id, alertTimes, _now()));
      }
      return const Ok(null);
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }

  @override
  Future<Result<void, AppFailure>> completeReminder(String id) async {
    try {
      await _dao.completeReminder(id, completedAt: _now());
      return const Ok(null);
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }

  @override
  Future<Result<void, AppFailure>> snoozeReminder(
    String id,
    DateTime newAlertTime,
  ) async {
    try {
      final now = _now();
      await _dao.replaceAlerts(id, _alertCompanions(id, [newAlertTime], now));
      // Snoozing touches only when the notification fires, never the event
      // itself, but the row still records that something about the reminder
      // changed just now.
      await _dao.updateReminder(id, updatedAt: now);
      return const Ok(null);
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }

  @override
  Future<Result<void, AppFailure>> deleteReminder(String id) async {
    try {
      await _dao.deleteReminder(id);
      return const Ok(null);
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }

  @override
  Future<Result<void, AppFailure>> deleteAllReminders() async {
    try {
      await _dao.deleteAllReminders();
      return const Ok(null);
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }

  @override
  Future<Result<List<Reminder>, AppFailure>> pendingReminders() async {
    try {
      final bundles = await _dao.pendingBundles();
      return Ok(bundles.map(reminderOf).toList());
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }

  @override
  Future<Result<List<Reminder>, AppFailure>> remindersForDocument(
    String documentId,
  ) async {
    try {
      final bundles = await _dao.bundlesForDocument(documentId);
      return Ok(bundles.map(reminderOf).toList());
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }

  @override
  Future<Result<void, AppFailure>> setAlertStatus(
    String alertId,
    ReminderAlertStatus status,
  ) async {
    try {
      await _dao.setAlertStatus(alertId, status);
      return const Ok(null);
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }

  List<ReminderAlertsCompanion> _alertCompanions(
    String reminderId,
    List<DateTime> alertTimes,
    DateTime now,
  ) => [
    for (final time in alertTimes)
      _alertCompanion(reminderId: reminderId, scheduledAt: time, now: now),
  ];

  ReminderAlertsCompanion _alertCompanion({
    required String reminderId,
    required DateTime scheduledAt,
    required DateTime now,
  }) {
    final id = _generateId();
    return ReminderAlertsCompanion.insert(
      id: id,
      reminderId: reminderId,
      scheduledAt: scheduledAt,
      notificationId: notificationIdOf(id),
      status: ReminderAlertStatus.scheduled,
      createdAt: now,
    );
  }

  /// Turns a stream error into an [Err] value instead of tearing the stream
  /// down — the same shape [RemoteUsageRepository.watchUsage] and
  /// `DriftDocumentsRepository._watchRows` use for the same reason.
  StreamTransformer<Result<T, AppFailure>, Result<T, AppFailure>>
  _errorsToFailures<T>() => StreamTransformer.fromHandlers(
    handleError: (error, stackTrace, sink) =>
        sink.add(const Err(LocalDatabaseFailure())),
  );
}
