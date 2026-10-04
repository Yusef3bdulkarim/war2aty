import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/usage/usage_hint_holder.dart';

void main() {
  group('UsageHintHolder', () {
    test('hands a stored count out once', () {
      final holder = UsageHintHolder()..set(2);

      expect(holder.consume(), 2);
      expect(holder.consume(), isNull);
    });

    test('tells its listeners when a count is stored', () {
      var notified = 0;
      UsageHintHolder()
        ..addListener(() => notified++)
        ..set(1);

      expect(notified, 1);
    });

    test('clear drops a stored count without showing it (F26-T04)', () {
      var notified = 0;
      final holder = UsageHintHolder()..set(1);
      holder
        ..addListener(() => notified++)
        ..clear();

      expect(holder.consume(), isNull);
      expect(notified, 0);
    });
  });
}
