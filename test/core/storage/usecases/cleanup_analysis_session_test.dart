import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/storage/usecases/cleanup_analysis_session.dart';

import '../../../support/fakes.dart';

void main() {
  test('forwards the session id to the storage layer', () async {
    final storage = FakeAnalysisSessionStorage();
    final useCase = CleanupAnalysisSession(storage);

    await useCase('session-1');

    expect(storage.deletedSessionIds, ['session-1']);
  });
}
