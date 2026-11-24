import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/reading_speed.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_speed.dart';
import 'package:war2aty/core/audio/usecases/next_reading_speed.dart';
import 'package:war2aty/core/audio/usecases/set_default_reading_speed.dart';
import 'package:war2aty/features/paper/presentation/cubit/paper_speed_cubit.dart';

import '../../../../support/fakes.dart';

void main() {
  PaperSpeedCubit buildCubit(FakeDefaultReadingSpeedStore store) {
    final cubit = PaperSpeedCubit(
      GetDefaultReadingSpeed(store),
      SetDefaultReadingSpeed(store),
      const NextReadingSpeed(),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('starts at normal, before anything is loaded', () {
    expect(
      buildCubit(FakeDefaultReadingSpeedStore()).state,
      ReadingSpeed.normal,
    );
  });

  test('load() keeps normal when nothing is persisted', () async {
    final cubit = buildCubit(FakeDefaultReadingSpeedStore());
    await cubit.load();
    expect(cubit.state, ReadingSpeed.normal);
  });

  test('load() restores a persisted speed', () async {
    final cubit = buildCubit(
      FakeDefaultReadingSpeedStore(ReadingSpeed.fastest),
    );
    await cubit.load();
    expect(cubit.state, ReadingSpeed.fastest);
  });

  test('cycle() moves to the next speed and persists it', () async {
    final store = FakeDefaultReadingSpeedStore();
    final cubit = buildCubit(store);
    await cubit.load();

    await cubit.cycle();

    expect(cubit.state, ReadingSpeed.faster);
    expect(await store.readSpeed(), ReadingSpeed.faster);
  });

  test('cycling four times returns to normal', () async {
    final cubit = buildCubit(FakeDefaultReadingSpeedStore());
    await cubit.load();

    for (var i = 0; i < 4; i++) {
      await cubit.cycle();
    }

    expect(cubit.state, ReadingSpeed.normal);
  });
}
