import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:war2aty/app/notifications/reminder_notification_opener.dart';
import 'package:war2aty/app/notifications/reminder_notification_taps.dart';

void main() {
  late ReminderNotificationTaps taps;
  late GoRouter router;

  setUp(() {
    taps = ReminderNotificationTaps();
    // Only the shape the opener relies on: a home, and the real
    // `/reminders/:id` path `AppRoutes.reminderDetailsWith` builds.
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/reminders/:id',
          builder: (_, state) => Text('details ${state.pathParameters['id']}'),
        ),
      ],
    );
  });
  tearDown(() => router.dispose());

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (context, child) =>
          ReminderNotificationOpener(taps: taps, router: router, child: child!),
    ),
  );

  testWidgets('the tap that launched the app opens its reminder', (
    tester,
  ) async {
    taps.open('r1');

    await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.text('details r1'), findsOneWidget);
  });

  testWidgets('a tap while the app runs opens its reminder', (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);

    taps.open('r2');
    await tester.pumpAndSettle();

    expect(find.text('details r2'), findsOneWidget);
  });

  testWidgets('back from the reminder returns to where the user was', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();

    taps.open('r1');
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('no tap: nothing opens', (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });
}
