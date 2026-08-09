import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../reminder.dart';
import '../reminders_repository.dart';

/// Creates a reminder the user entered by hand — «إضافة تذكير» (F09-T04).
///
/// Unlike [CreateReminderFromDocumentDate], [eventMinuteOfDay] is never
/// `null` in practice: the manual form marks the time required, since there
/// is no paper to be silent about it — the user is the source.
final class CreateManualReminder {
  const CreateManualReminder(this._repository);

  final RemindersRepository _repository;

  Future<Result<Reminder, AppFailure>> call({
    required String title,
    String? description,
    required DateTime eventDate,
    int? eventMinuteOfDay,
    required List<DateTime> alertTimes,
  }) => _repository.createReminder(
    title: title,
    description: description,
    eventDate: eventDate,
    eventMinuteOfDay: eventMinuteOfDay,
    isManual: true,
    alertTimes: alertTimes,
  );
}
