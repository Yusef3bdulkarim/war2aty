import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/analysis_status.dart';
import 'package:war2aty/core/documents/analysis_summary.dart';
import 'package:war2aty/core/documents/confidence_band.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/core/documents/document_kind.dart';
import 'package:war2aty/core/documents/documents_repository.dart';
import 'package:war2aty/core/documents/usecases/save_document.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/saved_papers/presentation/cubit/save_document_cubit.dart';
import 'package:war2aty/features/saved_papers/presentation/widgets/save_document_listener.dart';

import '../../support/pump_app.dart';

void main() {
  late _FakeRepository repository;
  late SaveDocumentCubit cubit;

  setUp(() {
    repository = _FakeRepository();
    cubit = SaveDocumentCubit(SaveDocument(repository));
  });
  tearDown(() => cubit.close());

  Future<void> pumpListener(WidgetTester tester, {Locale? locale}) {
    return pumpApp(
      tester,
      BlocProvider<SaveDocumentCubit>.value(
        value: cubit,
        child: const Scaffold(
          body: SaveDocumentListener(child: SizedBox.shrink()),
        ),
      ),
      locale: locale ?? AppLocalizations.arabic,
    );
  }

  testWidgets('says nothing before a save', (tester) async {
    await pumpListener(tester);

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('confirms a save, and says the photo stayed out', (tester) async {
    await pumpListener(tester);

    await cubit.save(analysis: _analysis(), extractedText: 'نص');
    await tester.pumpAndSettle();

    expect(find.text(const ArStrings().documentSaved), findsOneWidget);
  });

  testWidgets('reports a failure without database detail', (tester) async {
    repository.outcome = const Err(LocalDatabaseFailure());
    await pumpListener(tester);

    await cubit.save(analysis: _analysis(), extractedText: 'نص');
    await tester.pumpAndSettle();

    expect(find.text(const ArStrings().documentSaveFailed), findsOneWidget);
  });

  testWidgets('speaks English under the English locale', (tester) async {
    await pumpListener(tester, locale: AppLocalizations.english);

    await cubit.save(analysis: _analysis(), extractedText: 'نص');
    await tester.pumpAndSettle();

    expect(find.text(const EnStrings().documentSaved), findsOneWidget);
  });

  testWidgets('stays readable under Large Text', (tester) async {
    await pumpApp(
      tester,
      BlocProvider<SaveDocumentCubit>.value(
        value: cubit,
        child: const Scaffold(
          body: SaveDocumentListener(child: SizedBox.shrink()),
        ),
      ),
      textScaler: const TextScaler.linear(1.8),
    );

    await cubit.save(analysis: _analysis(), extractedText: 'نص');
    await tester.pumpAndSettle();

    expect(find.text(const ArStrings().documentSaved), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _FakeRepository implements DocumentsRepository {
  Result<String, AppFailure> outcome = const Ok('doc-1');

  @override
  Future<Result<String, AppFailure>> saveResultOnly({
    required DocumentAnalysis analysis,
    required String extractedText,
  }) async => outcome;
}

DocumentAnalysis _analysis() => const DocumentAnalysis(
  sessionId: 'session-1',
  status: AnalysisStatus.success,
  kind: DocumentKind.invoice,
  title: 'فاتورة كهرباء',
  kindConfidence: ConfidenceBand.high,
  summary: AnalysisSummary(short: 'سددها', detailed: 'فاتورة شهر يوليو.'),
);
