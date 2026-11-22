import '../../../../core/localization/app_strings.dart';
import '../../../../core/papers/paper_date.dart';
import '../../../../core/papers/paper_explanation.dart';
import '../../../../core/papers/saved_paper.dart';
import '../../../../core/time/cairo_day.dart';
import '../../../../core/time/document_date_label.dart';
import '../../../../core/utils/list_equality.dart';

final class PaperDateCardView {
  const PaperDateCardView({
    required this.month,
    required this.day,
    required this.weekday,
    this.time,
  });

  final String month;
  final String day;
  final String weekday;
  final String? time;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaperDateCardView &&
          other.month == month &&
          other.day == day &&
          other.weekday == weekday &&
          other.time == time;

  @override
  int get hashCode => Object.hash(month, day, weekday, time);

  @override
  String toString() =>
      'PaperDateCardView($month $day, $weekday, time: ${time != null})';
}

final class PaperView {
  const PaperView({
    required this.title,
    required this.headerDate,
    required this.cardIds,
    this.dateCard,
    this.groupedPhone,
  });

  factory PaperView.from(SavedPaper paper, AppStrings s, {DateTime? now}) {
    final explanation = paper.explanation;
    final contact = explanation.contact;
    return PaperView(
      title: explanation.title,
      headerDate: _headerDate(s, paper.savedAt, now ?? DateTime.now()),
      cardIds: _presentCardIds(explanation),
      dateCard: _dateCard(s, explanation.date),
      groupedPhone: contact == null ? null : _groupPhone(contact.phone),
    );
  }

  final String title;
  final String headerDate;
  final List<String> cardIds;
  final PaperDateCardView? dateCard;
  final String? groupedPhone;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaperView &&
          other.title == title &&
          other.headerDate == headerDate &&
          listEquals(other.cardIds, cardIds) &&
          other.dateCard == dateCard &&
          other.groupedPhone == groupedPhone;

  @override
  int get hashCode => Object.hash(
    title,
    headerDate,
    Object.hashAll(cardIds),
    dateCard,
    groupedPhone,
  );

  @override
  String toString() =>
      'PaperView($title, $headerDate, cards: $cardIds, '
      'date: ${dateCard != null}, phone: ${groupedPhone != null})';
}

String _headerDate(AppStrings s, DateTime savedAt, DateTime now) {
  final today = cairoDateOf(now);
  final savedDay = cairoDateOf(savedAt);
  return switch (today.difference(savedDay).inDays) {
    0 => s.paperDateToday,
    1 => s.paperDateYesterday,
    _ => formatDayMonth(s, cairoWallClockOf(savedAt)),
  };
}

PaperDateCardView? _dateCard(AppStrings s, PaperDate? date) {
  if (date == null) return null;
  final time = date.time;
  return PaperDateCardView(
    month: s.monthName(date.day.month),
    day: '${date.day.day}',
    weekday: s.weekdayName(date.day.weekday),
    time: time == null ? null : s.paperAppointmentTime(time.hour, time.minute),
  );
}

List<String> _presentCardIds(PaperExplanation explanation) {
  final ids = <String>['explain', 'todo'];
  if (explanation.date != null) ids.add('date');
  if (explanation.caution != null) ids.add('caution');
  if (explanation.contact != null) ids.add('contact');
  if (explanation.place != null) ids.add('place');
  return List.unmodifiable(ids);
}

String _groupPhone(String digits) {
  if (digits.isEmpty) return digits;
  final groups = <String>[];
  var start = 0;
  while (start < digits.length) {
    var end = (start + 3).clamp(0, digits.length);
    if (digits.length - end == 1) end += 1;
    groups.add(digits.substring(start, end));
    start = end;
  }
  return groups.join(' ');
}
