import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/analysis/processing_mode.dart';
import 'package:war2aty/core/analysis/usecases/get_processing_mode.dart';

import '../../../support/fakes.dart';

// F11-T03: the processing mode setting's own read side.
void main() {
  test('defaults to smartAnalysis when the user has never set it', () async {
    final useCase = GetProcessingMode(FakeProcessingModeStore());

    expect(await useCase(), ProcessingMode.smartAnalysis);
  });

  test('reflects an explicit smartAnalysis', () async {
    final useCase = GetProcessingMode(
      FakeProcessingModeStore(ProcessingMode.smartAnalysis),
    );

    expect(await useCase(), ProcessingMode.smartAnalysis);
  });

  test('reflects an explicit textOnly', () async {
    final useCase = GetProcessingMode(
      FakeProcessingModeStore(ProcessingMode.textOnly),
    );

    expect(await useCase(), ProcessingMode.textOnly);
  });
}
