/// A date and time to open the manual reminder form already holding (F29).
///
/// The empty reminders list offers three ready-made dates — «بكرة», «بعد
/// أسبوع», «آخر الشهر» — and tapping one opens the ordinary manual form with
/// its event date and time filled in, so the user only has to say what the
/// reminder is *about*.
///
/// Deliberately **not** the title: `canSave` requires a non-empty title, and
/// guessing one would either be wrong or would let an untitled reminder
/// through. One step fewer, not zero.
///
/// The reason the manual form has a parameter at all. Kept separate from
/// `QuickReminderSlot` in `core/`: the form does not need to know that a
/// seed came from a quick row rather than from anywhere else.
final class ManualReminderSeed {
  const ManualReminderSeed({required this.eventDate, this.eventMinuteOfDay});

  /// The calendar day, as the date pickers themselves produce one — only
  /// `year`/`month`/`day` are read downstream.
  final DateTime eventDate;

  /// Minutes since midnight on [eventDate]. `null` when the source had no
  /// time to seed — the manual form still marks time required to save, so
  /// the user fills it in themselves (F40 D13: a paper's date with no hour).
  final int? eventMinuteOfDay;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManualReminderSeed &&
          other.eventDate == eventDate &&
          other.eventMinuteOfDay == eventMinuteOfDay;

  @override
  int get hashCode => Object.hash(eventDate, eventMinuteOfDay);

  @override
  String toString() =>
      'ManualReminderSeed(${eventDate.year}-${eventDate.month}'
      '-${eventDate.day}, $eventMinuteOfDay)';
}
