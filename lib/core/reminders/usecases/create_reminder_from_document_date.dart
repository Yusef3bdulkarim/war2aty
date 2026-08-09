import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../reminder.dart';
import '../reminders_repository.dart';

/// Creates a reminder from a date the analysis found on a paper (F09-T03).
///
/// [documentId] links back to a saved document when the reminder was started
/// from its details screen; it is `null` when started from a result the user
/// has not (yet, or ever) chosen to keep — the reminder itself does not need
/// the paper to be saved to exist.
///
/// [alertTimes] is never empty by the time this is called — the form
/// (F09-T02) requires at least one alert before its save button is live.
final class CreateReminderFromDocumentDate {
  const CreateReminderFromDocumentDate(this._repository);

  final RemindersRepository _repository;

  Future<Result<Reminder, AppFailure>> call({
    String? documentId,
    required String title,
    String? description,
    required DateTime eventDate,
    int? eventMinuteOfDay,
    required List<DateTime> alertTimes,
  }) => _repository.createReminder(
    documentId: documentId,
    title: title,
    description: description,
    eventDate: eventDate,
    eventMinuteOfDay: eventMinuteOfDay,
    isManual: false,
    alertTimes: alertTimes,
  );
}
