import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/money/document_amount_label.dart';

const _strings = ArStrings();

void main() {
  group('formatDocumentAmount', () {
    test('writes a whole figure without a decimal part', () {
      expect(formatDocumentAmount(_strings, 750, 'EGP'), '750 جنيه');
    });

    test('keeps both digits when there are piastres', () {
      // `250.5` must never read as "250 pounds 5".
      expect(formatDocumentAmount(_strings, 250.5, 'EGP'), '250.50 جنيه');
    });

    test('names the currencies the app expects to meet', () {
      expect(formatDocumentAmount(_strings, 20, 'USD'), '20 دولار');
      expect(formatDocumentAmount(_strings, 20, 'egp'), '20 جنيه');
    });

    test('shows an unknown code as it arrived rather than dropping it', () {
      expect(formatDocumentAmount(_strings, 20, 'XYZ'), '20 XYZ');
    });
  });

  group('formatAmountNumber', () {
    test('is the figure alone, for pasting into a payment app', () {
      expect(formatAmountNumber(750), '750');
      expect(formatAmountNumber(250.5), '250.50');
      expect(formatAmountNumber(1250.75), '1250.75');
    });
  });
}
