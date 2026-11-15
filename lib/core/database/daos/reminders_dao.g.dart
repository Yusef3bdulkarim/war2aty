// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminders_dao.dart';

// ignore_for_file: type=lint
mixin _$RemindersDaoMixin on DatabaseAccessor<AppDatabase> {
  $RemindersTable get reminders => attachedDatabase.reminders;
  $ReminderAlertsTable get reminderAlerts => attachedDatabase.reminderAlerts;
  RemindersDaoManager get managers => RemindersDaoManager(this);
}

class RemindersDaoManager {
  final _$RemindersDaoMixin _db;
  RemindersDaoManager(this._db);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db.attachedDatabase, _db.reminders);
  $$ReminderAlertsTableTableManager get reminderAlerts =>
      $$ReminderAlertsTableTableManager(
        _db.attachedDatabase,
        _db.reminderAlerts,
      );
}
