import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/analysis_amount.dart';
import 'package:war2aty/core/documents/analysis_date.dart';
import 'package:war2aty/core/documents/analysis_section.dart';
import 'package:war2aty/core/documents/confidence_band.dart';
import 'package:war2aty/core/documents/key_information.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/theme/app_colors.dart';
import 'package:war2aty/core/widgets/caveat_badge.dart';
import 'package:war2aty/core/widgets/result_details_card.dart';

import '../../support/pump_app.dart';

const _strings = ArStrings();

KeyInformation _item({
  String label = 'رقم المشترك',
  String value = '624512',
  ConfidenceBand confidence = ConfidenceBand.high,
  InfoSource source = InfoSource.extracted,
}) => KeyInformation(
  label: label,
  value: value,
  confidence: confidence,
  source: source,
);

AnalysisAmount _amount({
  String label = 'المبلغ المطلوب',
  double value = 750,
  String currency = 'EGP',
  ConfidenceBand confidence = ConfidenceBand.high,
}) => AnalysisAmount(
  label: label,
  value: value,
  currency: currency,
  confidence: confidence,
);

AnalysisDate _date({
  String label = 'آخر موعد للسداد',
  DateTime? on,
  AnalysisTime? time,
  DateRole role = DateRole.deadline,
  bool isReminderWorthy = true,
  ConfidenceBand confidence = ConfidenceBand.high,
}) => AnalysisDate(
  label: label,
  date: on ?? DateTime(2026, 8, 25),
  time: time,
  role: role,
  isReminderWorthy: isReminderWorthy,
  confidence: confidence,
);

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    List<KeyInformation> items = const [],
    List<AnalysisAmount> amounts = const [],
    List<AnalysisDate> dates = const [],
    ValueChanged<AnalysisDate>? onCreateReminder,
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
  }) => pumpApp(
    tester,
    Scaffold(
      body: SingleChildScrollView(
        child: ResultDetailsCard(
          keyInformation: items,
          amounts: amounts,
          dates: dates,
          onCreateReminder: onCreateReminder,
        ),
      ),
    ),
    locale: locale,
    textScaler: textScaler,
  );

  /// Records what the copy buttons put on the clipboard.
  List<String> recordClipboard(WidgetTester tester) {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return copied;
  }

  group('ResultDetailsCard', () {
    testWidgets('draws both groups in one card, each under its sub-header', (
      tester,
    ) async {
      await pumpCard(
        tester,
        items: [
          _item(),
          _item(label: 'الجهة', value: 'شركة الكهرباء'),
        ],
        amounts: [_amount()],
      );

      expect(find.byType(ResultDetailsCard), findsOneWidget);
      expect(find.text(_strings.resultKeyInformationTitle), findsOneWidget);
      expect(find.text(_strings.resultAmountsTitle), findsOneWidget);
      expect(find.text('رقم المشترك'), findsOneWidget);
      expect(find.text('624512'), findsOneWidget);
      expect(find.text('شركة الكهرباء'), findsOneWidget);
      expect(find.text('750 جنيه'), findsOneWidget);
      // Information first, then money — the §4 order.
      expect(
        tester.getTopLeft(find.text(_strings.resultKeyInformationTitle)).dy,
        lessThan(tester.getTopLeft(find.text(_strings.resultAmountsTitle)).dy),
      );
    });

    testWidgets('announces each sub-header as a heading', (tester) async {
      await pumpCard(tester, items: [_item()], amounts: [_amount()]);

      for (final title in [
        _strings.resultKeyInformationTitle,
        _strings.resultAmountsTitle,
      ]) {
        final node = tester.getSemantics(find.text(title));
        expect(node.flagsCollection.isHeader, isTrue, reason: title);
      }
    });

    testWidgets('shows only the group that has something in it', (
      tester,
    ) async {
      await pumpCard(tester, amounts: [_amount()]);

      expect(find.text(_strings.resultKeyInformationTitle), findsNothing);
      expect(find.text(_strings.resultAmountsTitle), findsOneWidget);
    });

    testWidgets('lets a value the analysis is sure of stand on its own', (
      tester,
    ) async {
      await pumpCard(tester, items: [_item()], amounts: [_amount()]);

      expect(find.byType(CaveatBadge), findsNothing);
    });

    testWidgets('asks the user to check a medium-confidence value', (
      tester,
    ) async {
      await pumpCard(tester, items: [_item(confidence: ConfidenceBand.medium)]);

      expect(find.text(_strings.confidenceReview), findsOneWidget);
    });

    testWidgets('marks a low-confidence value as an uncertain reading', (
      tester,
    ) async {
      await pumpCard(tester, items: [_item(confidence: ConfidenceBand.low)]);

      expect(find.text(_strings.confidenceUncertain), findsOneWidget);
    });

    testWidgets('marks a value the paper never stated', (tester) async {
      await pumpCard(tester, items: [_item(source: InfoSource.inferred)]);

      expect(find.text(_strings.resultActionInferred), findsOneWidget);
    });

    testWidgets('says both when a value is inferred and uncertain', (
      tester,
    ) async {
      await pumpCard(
        tester,
        items: [
          _item(confidence: ConfidenceBand.low, source: InfoSource.inferred),
        ],
      );

      expect(find.byType(CaveatBadge), findsNWidgets(2));
    });

    testWidgets('qualifies a figure the analysis is unsure of', (tester) async {
      await pumpCard(
        tester,
        amounts: [_amount(confidence: ConfidenceBand.medium)],
      );

      expect(find.text(_strings.confidenceReview), findsOneWidget);
    });

    testWidgets('qualifies only the row it is about', (tester) async {
      await pumpCard(
        tester,
        items: [_item()],
        amounts: [
          _amount(confidence: ConfidenceBand.medium),
          _amount(),
        ],
      );

      // Per-value, never per-document (UX rule §5.9).
      expect(find.byType(CaveatBadge), findsOneWidget);
    });

    testWidgets('copies a value as it is written', (tester) async {
      final copied = recordClipboard(tester);
      await pumpCard(tester, items: [_item()]);

      await tester.tap(
        find.bySemanticsLabel(_strings.resultCopyValueLabel('رقم المشترك')),
      );
      await tester.pumpAndSettle();

      expect(copied, ['624512']);
      expect(find.text(_strings.ocrTextCopied), findsOneWidget);
    });

    testWidgets('copies an amount as the figure alone', (tester) async {
      final copied = recordClipboard(tester);
      await pumpCard(tester, amounts: [_amount(value: 250.5)]);

      await tester.tap(
        find.bySemanticsLabel(_strings.resultCopyValueLabel('المبلغ المطلوب')),
      );
      await tester.pumpAndSettle();

      // No currency: this is what gets pasted into a payment app.
      expect(copied, ['250.50']);
    });

    testWidgets('keeps a full-size tap target on the small copy icon', (
      tester,
    ) async {
      await pumpCard(tester, items: [_item()]);

      final target = tester.getSize(
        find.bySemanticsLabel(_strings.resultCopyValueLabel('رقم المشترك')),
      );
      expect(target.width, greaterThanOrEqualTo(48));
      expect(target.height, greaterThanOrEqualTo(48));
    });

    testWidgets('lays out long labels and values under Large Text', (
      tester,
    ) async {
      await pumpCard(
        tester,
        items: [
          _item(
            label: 'رقم المعاملة لدى مكتب السجل المدني',
            value: '2026/8841 — فرع الجيزة',
            confidence: ConfidenceBand.low,
            source: InfoSource.inferred,
          ),
        ],
        amounts: [
          _amount(
            label: 'إجمالي المبلغ المطلوب سداده عن شهر أغسطس',
            value: 1250.75,
            confidence: ConfidenceBand.low,
          ),
        ],
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('follows the locale', (tester) async {
      await pumpCard(
        tester,
        items: [_item()],
        amounts: [_amount()],
        locale: AppLocalizations.english,
      );

      const english = EnStrings();
      expect(find.text(english.resultKeyInformationTitle), findsOneWidget);
      expect(find.text(english.resultAmountsTitle), findsOneWidget);
      expect(find.text('750 EGP'), findsOneWidget);
    });
  });

  group('ResultDetailsCard — the dates group', () {
    testWidgets('sits in the same card, after information and amounts', (
      tester,
    ) async {
      await pumpCard(
        tester,
        items: [_item()],
        amounts: [_amount()],
        dates: [_date()],
      );

      expect(find.byType(ResultDetailsCard), findsOneWidget);
      final amounts = tester.getTopLeft(find.text(_strings.resultAmountsTitle));
      final dates = tester.getTopLeft(find.text(_strings.resultDatesTitle));
      expect(amounts.dy, lessThan(dates.dy));
      expect(
        tester
            .getSemantics(find.text(_strings.resultDatesTitle))
            .flagsCollection
            .isHeader,
        isTrue,
      );
    });

    testWidgets('writes the date out in full and says what it is for', (
      tester,
    ) async {
      await pumpCard(
        tester,
        dates: [
          _date(),
          _date(
            label: 'تاريخ إصدار الفاتورة',
            on: DateTime(2026, 8, 10),
            role: DateRole.issued,
            isReminderWorthy: false,
          ),
        ],
      );

      expect(find.text('25 أغسطس 2026'), findsOneWidget);
      expect(find.text('آخر موعد للسداد'), findsOneWidget);
      expect(find.text('تاريخ إصدار الفاتورة'), findsOneWidget);
    });

    testWidgets('keeps the order the analysis reported', (tester) async {
      await pumpCard(
        tester,
        dates: [
          _date(label: 'الأولى'),
          _date(label: 'التانية', on: DateTime(2026, 8, 10)),
        ],
      );

      final first = tester.getTopLeft(find.text('الأولى'));
      final second = tester.getTopLeft(find.text('التانية'));
      expect(first.dy, lessThan(second.dy));
    });

    testWidgets('shows the time the paper gives', (tester) async {
      await pumpCard(
        tester,
        dates: [_date(time: const AnalysisTime(hour: 10, minute: 0))],
      );

      expect(find.text('10:00 ${_strings.timeAm}'), findsOneWidget);
      expect(find.text(_strings.resultDateNoTime), findsNothing);
    });

    testWidgets('says so rather than inventing a missing time', (tester) async {
      await pumpCard(tester, dates: [_date()]);

      expect(find.text(_strings.resultDateNoTime), findsOneWidget);
    });

    testWidgets('qualifies a date the analysis is unsure of', (tester) async {
      await pumpCard(tester, dates: [_date(confidence: ConfidenceBand.medium)]);

      expect(find.text(_strings.confidenceReview), findsOneWidget);
    });

    testWidgets('lets a certain date stand on its own', (tester) async {
      await pumpCard(tester, dates: [_date()]);

      expect(find.byType(CaveatBadge), findsNothing);
    });

    testWidgets('the day tile is not read out twice', (tester) async {
      await pumpCard(tester, dates: [_date()]);

      // The tile repeats the day and month already spelled out beside it.
      expect(find.text('25'), findsOneWidget);
      expect(find.text('أغسطس'), findsOneWidget);
      expect(find.bySemanticsLabel('25'), findsNothing);
    });

    testWidgets('has no copy button on a date', (tester) async {
      await pumpCard(tester, dates: [_date()]);

      expect(
        find.bySemanticsLabel(_strings.resultCopyValueLabel('آخر موعد للسداد')),
        findsNothing,
      );
    });

    testWidgets('ends the group with the reminder button, inside the card', (
      tester,
    ) async {
      await pumpCard(
        tester,
        dates: [
          _date(),
          _date(label: 'التانية', on: DateTime(2026, 9, 3)),
        ],
        onCreateReminder: (_) {},
      );

      final card = tester.getRect(find.byType(ResultDetailsCard));
      final button = tester.getRect(find.text(_strings.resultCreateReminder));
      final lastDate = tester.getRect(find.text('التانية'));
      expect(card.contains(button.center), isTrue);
      expect(button.top, greaterThan(lastDate.bottom));
    });

    testWidgets('lays out under Large Text', (tester) async {
      await pumpCard(
        tester,
        dates: [
          _date(
            label: 'آخر موعد لتقديم المستندات لمكتب السجل المدني',
            confidence: ConfidenceBand.low,
          ),
        ],
        onCreateReminder: (_) {},
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('follows the locale', (tester) async {
      await pumpCard(
        tester,
        dates: [_date()],
        locale: AppLocalizations.english,
      );

      const english = EnStrings();
      expect(find.text(english.resultDatesTitle), findsOneWidget);
      expect(find.text('25 August 2026'), findsOneWidget);
      expect(find.text(english.resultDateNoTime), findsOneWidget);
    });
  });

  group('ResultDetailsCard — contrast', () {
    testWidgets('its small grey text meets 4.5:1 (textCaption)', (
      tester,
    ) async {
      await pumpCard(tester, items: [_item()], dates: [_date()]);

      Color? colorOf(String text) =>
          tester.widget<Text>(find.text(text)).style?.color;

      // Sub-header, row label, date label, and the time line — all 13 px or
      // smaller, where `textMuted` (3.0:1) and `iconSubtle` (3.7:1) failed AA.
      for (final text in [
        _strings.resultKeyInformationTitle,
        'رقم المشترك',
        'آخر موعد للسداد',
        _strings.resultDateNoTime,
      ]) {
        expect(colorOf(text), AppColors.light.textCaption, reason: text);
      }
    });
  });

  group('isResultDetailsSlot', () {
    test('is the first of the sections the card draws together', () {
      const sections = [
        AnalysisSection.header,
        AnalysisSection.keyInformation,
        AnalysisSection.amounts,
        AnalysisSection.dates,
      ];

      expect(
        isResultDetailsSlot(sections, AnalysisSection.keyInformation),
        isTrue,
      );
      expect(isResultDetailsSlot(sections, AnalysisSection.amounts), isFalse);
      expect(isResultDetailsSlot(sections, AnalysisSection.header), isFalse);
    });

    test('falls to amounts when there is no key information', () {
      const sections = [AnalysisSection.header, AnalysisSection.amounts];

      expect(isResultDetailsSlot(sections, AnalysisSection.amounts), isTrue);
    });

    test('falls to dates when they are all there is', () {
      const sections = [AnalysisSection.header, AnalysisSection.dates];

      expect(isResultDetailsSlot(sections, AnalysisSection.dates), isTrue);
    });

    test('absorbs dates once key information holds the slot', () {
      const sections = [AnalysisSection.keyInformation, AnalysisSection.dates];

      expect(isResultDetailsSlot(sections, AnalysisSection.dates), isFalse);
    });
  });
}
