import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/analysis/processing_mode.dart';
import 'package:war2aty/core/analysis/usecases/get_processing_mode.dart';
import 'package:war2aty/core/analysis/usecases/set_processing_mode.dart';

import '../../../support/fakes.dart';

// F11-T03: the processing mode setting's own write side.
void main() {
  test('persists the choice so a later read reflects it', () async {
    final store = FakeProcessingModeStore();
    final setMode = SetProcessingMode(store);
    final getMode = GetProcessingMode(store);

    await setMode(ProcessingMode.textOnly);

    expect(await getMode(), ProcessingMode.textOnly);
  });

  test('switching back to smartAnalysis overwrites textOnly', () async {
    final store = FakeProcessingModeStore(ProcessingMode.textOnly);
    final setMode = SetProcessingMode(store);
    final getMode = GetProcessingMode(store);

    await setMode(ProcessingMode.smartAnalysis);

    expect(await getMode(), ProcessingMode.smartAnalysis);
  });
}
