import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/reminders/reminder.dart';
import 'package:war2aty/core/reminders/reminder_alert.dart';
import 'package:war2aty/core/reminders/reminder_alert_status.dart';
import 'package:war2aty/core/reminders/reminder_status.dart';

void main() {
  group('eventInstant', () {
    test('is null with no event time', () {
      expect(_reminder(eventMinuteOfDay: null).eventInstant, isNull);
    });

    test('combines the event date and time on the Cairo clock', () {
      // 25 Aug 2026, 10:00 Cairo == 08:00 UTC.
      final reminder = _reminder(eventDate: DateTime(2026, 8, 25));

      expect(reminder.eventInstant, DateTime.utc(2026, 8, 25, 8));
    });
  });

  group('nextAlert', () {
    test('is null with no alerts', () {
      expect(_reminder().nextAlert, isNull);
    });

    test('is the earliest still-scheduled alert', () {
      final reminder = _reminder(
        alerts: [
          _alert('late', DateTime(2026, 8, 25)),
          _alert('early', DateTime(2026, 8, 23)),
        ],
      );

      expect(reminder.nextAlert!.id, 'early');
    });

    test('skips cancelled alerts', () {
      final reminder = _reminder(
        alerts: [
          _alert(
            'cancelled',
            DateTime(2026, 8, 20),
            status: ReminderAlertStatus.cancelled,
          ),
          _alert('active', DateTime(2026, 8, 25)),
        ],
      );

      expect(reminder.nextAlert!.id, 'active');
    });
  });

  group('isOverdue', () {
    final now = DateTime(2026, 8, 24, 12);

    test('a completed reminder is never overdue', () {
      final reminder = _reminder(
        status: ReminderStatus.completed,
        alerts: [_alert('a1', DateTime(2026, 8))],
      );

      expect(reminder.isOverdue(now: now), isFalse);
    });

    test('pending with no alerts at all is never overdue', () {
      expect(_reminder().isOverdue(now: now), isFalse);
    });

    test('pending with every alert already past is overdue', () {
      final reminder = _reminder(
        alerts: [
          _alert('a1', DateTime(2026, 8)),
          _alert('a2', DateTime(2026, 8, 10)),
        ],
      );

      expect(reminder.isOverdue(now: now), isTrue);
    });

    test('pending with one alert still ahead is not overdue', () {
      final reminder = _reminder(
        alerts: [
          _alert('a1', DateTime(2026, 8)),
          _alert('a2', DateTime(2026, 8, 30)),
        ],
      );

      expect(reminder.isOverdue(now: now), isFalse);
    });

    test('a cancelled past alert does not count towards overdue', () {
      final reminder = _reminder(
        alerts: [
          _alert(
            'a1',
            DateTime(2026, 8),
            status: ReminderAlertStatus.cancelled,
          ),
        ],
      );

      expect(reminder.isOverdue(now: now), isFalse);
    });
  });

  group('equality', () {
    test('reminders with the same fields and alerts are equal', () {
      expect(
        _reminder(alerts: [_alert('a1', DateTime(2026, 8, 25))]),
        _reminder(alerts: [_alert('a1', DateTime(2026, 8, 25))]),
      );
    });

    test('different alert lists make them unequal', () {
      expect(
        _reminder(alerts: [_alert('a1', DateTime(2026, 8, 25))]),
        isNot(_reminder(alerts: [_alert('a2', DateTime(2026, 8, 25))])),
      );
    });
  });
}

Reminder _reminder({
  DateTime? eventDate,
  Object? eventMinuteOfDay = 600,
  ReminderStatus status = ReminderStatus.pending,
  List<ReminderAlert> alerts = const [],
}) => Reminder(
  id: 'r1',
  title: 'دفع فاتورة الكهرباء',
  eventDate: eventDate ?? DateTime(2026, 8, 25),
  eventMinuteOfDay: eventMinuteOfDay == null ? null : eventMinuteOfDay as int,
  status: status,
  isManual: false,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  alerts: alerts,
);

ReminderAlert _alert(
  String id,
  DateTime scheduledAt, {
  ReminderAlertStatus status = ReminderAlertStatus.scheduled,
}) => ReminderAlert(
  id: id,
  reminderId: 'r1',
  scheduledAt: scheduledAt,
  status: status,
);
