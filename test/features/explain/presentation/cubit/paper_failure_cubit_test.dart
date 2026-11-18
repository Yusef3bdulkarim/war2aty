import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/voice/usecases/speak_fixed_line.dart';
import 'package:war2aty/core/voice/voice_line.dart';
import 'package:war2aty/features/explain/domain/entities/paper_failure_kind.dart';
import 'package:war2aty/features/explain/presentation/cubit/paper_failure_cubit.dart';

import '../../../../support/fakes.dart';

void main() {
  late FakeFixedLinePlayer player;

  setUp(() {
    player = FakeFixedLinePlayer();
  });

  PaperFailureCubit buildCubit(PaperFailureKind kind) =>
      PaperFailureCubit(speakFixedLine: SpeakFixedLine(player), kind: kind);

  test('speaks fail_offline for the offline kind on open', () async {
    final cubit = buildCubit(PaperFailureKind.offline);
    await pumpEventQueue();

    expect(player.played, [VoiceLine.failOffline.assetPath]);

    await cubit.close();
  });

  test('speaks fail_limit for the limitReached kind on open', () async {
    final cubit = buildCubit(PaperFailureKind.limitReached);
    await pumpEventQueue();

    expect(player.played, [VoiceLine.failLimit.assetPath]);

    await cubit.close();
  });

  test('speaks fail_service for the serviceProblem kind on open', () async {
    final cubit = buildCubit(PaperFailureKind.serviceProblem);
    await pumpEventQueue();

    expect(player.played, [VoiceLine.failService.assetPath]);

    await cubit.close();
  });

  test('stops the line on close', () async {
    final cubit = buildCubit(PaperFailureKind.offline);
    await pumpEventQueue();

    await cubit.close();

    expect(player.stopCount, 1);
  });

  test('close stops even when the line failed to start', () async {
    player.failure = const AudioPlaybackFailure();
    final cubit = buildCubit(PaperFailureKind.serviceProblem);
    await pumpEventQueue();

    expect(player.played, isEmpty);

    await cubit.close();

    expect(player.stopCount, 1);
  });
}
