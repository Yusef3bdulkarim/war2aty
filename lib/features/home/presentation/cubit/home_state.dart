import 'package:flutter/foundation.dart';

import '../../../../core/documents/recent_document.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/reminders/upcoming_reminder.dart';
import '../../../../core/usage/daily_usage.dart';

/// State of Home's usage counter.
///
/// Sealed so the widget has to handle the "still loading" case explicitly
/// rather than showing a wrong number for a frame.
sealed class UsageSection {
  const UsageSection();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// No value has arrived from the database yet.
final class UsageLoading extends UsageSection {
  const UsageLoading();
}

/// The quota is known. [usage] is `null` when nothing is cached for today —
/// a real answer meaning "we have no count to show", not a failure.
final class UsageAvailable extends UsageSection {
  const UsageAvailable(this.usage);

  final DailyUsage? usage;

  @override
  bool operator ==(Object other) =>
      other is UsageAvailable && other.usage == usage;

  @override
  int get hashCode => Object.hash(UsageAvailable, usage);
}

/// The quota could not be read. Home stays usable; the counter just hides.
final class UsageUnavailable extends UsageSection {
  const UsageUnavailable(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      other is UsageUnavailable && other.failure == failure;

  @override
  int get hashCode => Object.hash(UsageUnavailable, failure);
}

/// State of Home's recent-documents strip.
sealed class DocumentsSection {
  const DocumentsSection();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// No list has arrived from the database yet.
final class DocumentsLoading extends DocumentsSection {
  const DocumentsLoading();
}

/// The newest documents, or an empty list when nothing is saved yet.
final class DocumentsAvailable extends DocumentsSection {
  const DocumentsAvailable(this.documents);

  final List<RecentDocument> documents;

  bool get isEmpty => documents.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is DocumentsAvailable && listEquals(other.documents, documents);

  @override
  int get hashCode => Object.hashAll(documents);
}

/// The list could not be read. The rest of Home stays usable.
final class DocumentsUnavailable extends DocumentsSection {
  const DocumentsUnavailable(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      other is DocumentsUnavailable && other.failure == failure;

  @override
  int get hashCode => Object.hash(DocumentsUnavailable, failure);
}

/// State of Home's upcoming-reminder card.
sealed class ReminderSection {
  const ReminderSection();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Nothing has arrived from the database yet.
final class ReminderLoading extends ReminderSection {
  const ReminderLoading();
}

/// The next reminder, or `null` when nothing is scheduled.
final class ReminderAvailable extends ReminderSection {
  const ReminderAvailable(this.reminder);

  final UpcomingReminder? reminder;

  @override
  bool operator ==(Object other) =>
      other is ReminderAvailable && other.reminder == reminder;

  @override
  int get hashCode => Object.hash(ReminderAvailable, reminder);
}

/// It could not be read. The rest of Home stays usable.
final class ReminderUnavailable extends ReminderSection {
  const ReminderUnavailable(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      other is ReminderUnavailable && other.failure == failure;

  @override
  int get hashCode => Object.hash(ReminderUnavailable, failure);
}

/// Everything Home renders.
///
/// A composite rather than a union: Home shows several independent sections at
/// once, each with its own lifecycle, so "the screen" is never in one single
/// state. Each section is a sealed union of its own.
final class HomeState {
  const HomeState({
    this.usage = const UsageLoading(),
    this.reminder = const ReminderLoading(),
    this.documents = const DocumentsLoading(),
  });

  final UsageSection usage;
  final ReminderSection reminder;
  final DocumentsSection documents;

  HomeState copyWith({
    UsageSection? usage,
    ReminderSection? reminder,
    DocumentsSection? documents,
  }) => HomeState(
    usage: usage ?? this.usage,
    reminder: reminder ?? this.reminder,
    documents: documents ?? this.documents,
  );

  @override
  bool operator ==(Object other) =>
      other is HomeState &&
      other.usage == usage &&
      other.reminder == reminder &&
      other.documents == documents;

  @override
  int get hashCode => Object.hash(usage, reminder, documents);
}
