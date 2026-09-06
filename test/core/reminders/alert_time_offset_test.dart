import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/reminders/alert_time_offset.dart';

void main() {
  final event = DateTime.utc(2026, 8, 25, 10);

  test('atEventTime is the event instant itself', () {
    expect(AlertTimeOffset.atEventTime.applyTo(event), event);
  });

  test('twoHoursBefore subtracts two hours', () {
    expect(
      AlertTimeOffset.twoHoursBefore.applyTo(event),
      DateTime.utc(2026, 8, 25, 8),
    );
  });

  test('oneDayBefore subtracts a day', () {
    expect(
      AlertTimeOffset.oneDayBefore.applyTo(event),
      DateTime.utc(2026, 8, 24, 10),
    );
  });

  test('threeDaysBefore subtracts three days', () {
    expect(
      AlertTimeOffset.threeDaysBefore.applyTo(event),
      DateTime.utc(2026, 8, 22, 10),
    );
  });
}
