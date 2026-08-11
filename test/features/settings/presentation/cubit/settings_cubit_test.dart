import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/analysis/processing_mode.dart';
import 'package:war2aty/core/analysis/usecases/get_analysis_consent.dart';
import 'package:war2aty/core/analysis/usecases/get_processing_mode.dart';
import 'package:war2aty/core/analysis/usecases/set_analysis_consent.dart';
import 'package:war2aty/core/analysis/usecases/set_processing_mode.dart';
import 'package:war2aty/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:war2aty/features/settings/presentation/cubit/settings_state.dart';

import '../../../../support/fakes.dart';

void main() {
  // Builds a cubit over fake stores and registers its close() teardown.
  SettingsCubit buildCubit({
    FakeAnalysisConsentStore? consentStore,
    FakeProcessingModeStore? modeStore,
  }) {
    final consent = consentStore ?? FakeAnalysisConsentStore();
    final mode = modeStore ?? FakeProcessingModeStore();
    final cubit = SettingsCubit(
      getAnalysisConsent: GetAnalysisConsent(consent),
      setAnalysisConsent: SetAnalysisConsent(consent),
      getProcessingMode: GetProcessingMode(mode),
      setProcessingMode: SetProcessingMode(mode),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('starts loading', () {
    expect(buildCubit().state, const SettingsLoading());
  });

  test('load() reads the persisted settings, defaulting to consent on and '
      'smart analysis', () async {
    final cubit = buildCubit();
    await cubit.load();

    expect(
      cubit.state,
      const SettingsReady(
        analysisConsent: true,
        processingMode: ProcessingMode.smartAnalysis,
      ),
    );
  });

  test('load() reflects an explicit decline', () async {
    final cubit = buildCubit(consentStore: FakeAnalysisConsentStore(false));
    await cubit.load();

    expect(
      cubit.state,
      const SettingsReady(
        analysisConsent: false,
        processingMode: ProcessingMode.smartAnalysis,
      ),
    );
  });

  test('load() reflects a persisted textOnly mode', () async {
    final cubit = buildCubit(
      modeStore: FakeProcessingModeStore(ProcessingMode.textOnly),
    );
    await cubit.load();

    expect(
      cubit.state,
      const SettingsReady(
        analysisConsent: true,
        processingMode: ProcessingMode.textOnly,
      ),
    );
  });

  test('setAnalysisConsent() emits and persists', () async {
    final store = FakeAnalysisConsentStore();
    final cubit = buildCubit(consentStore: store);
    await cubit.load();

    await cubit.setAnalysisConsent(false);

    expect(
      cubit.state,
      const SettingsReady(
        analysisConsent: false,
        processingMode: ProcessingMode.smartAnalysis,
      ),
    );
    expect(await store.readConsent(), isFalse);
  });

  test('setAnalysisConsent() before load() is a no-op', () async {
    final store = FakeAnalysisConsentStore();
    final cubit = buildCubit(consentStore: store);

    await cubit.setAnalysisConsent(false);

    expect(cubit.state, const SettingsLoading());
    expect(await store.readConsent(), isNull);
  });

  test('setProcessingMode() emits and persists', () async {
    final store = FakeProcessingModeStore();
    final cubit = buildCubit(modeStore: store);
    await cubit.load();

    await cubit.setProcessingMode(ProcessingMode.textOnly);

    expect(
      cubit.state,
      const SettingsReady(
        analysisConsent: true,
        processingMode: ProcessingMode.textOnly,
      ),
    );
    expect(await store.readMode(), ProcessingMode.textOnly);
  });

  test('setProcessingMode() before load() is a no-op', () async {
    final store = FakeProcessingModeStore();
    final cubit = buildCubit(modeStore: store);

    await cubit.setProcessingMode(ProcessingMode.textOnly);

    expect(cubit.state, const SettingsLoading());
    expect(await store.readMode(), isNull);
  });
}
