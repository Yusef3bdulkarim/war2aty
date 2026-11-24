import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/audio/reading_speed.dart';
import '../../../../core/audio/usecases/get_default_reading_speed.dart';
import '../../../../core/audio/usecases/next_reading_speed.dart';
import '../../../../core/audio/usecases/set_default_reading_speed.dart';

final class PaperSpeedCubit extends Cubit<ReadingSpeed> {
  PaperSpeedCubit(
    this._getDefaultReadingSpeed,
    this._setDefaultReadingSpeed,
    this._nextReadingSpeed,
  ) : super(ReadingSpeed.normal);

  final GetDefaultReadingSpeed _getDefaultReadingSpeed;
  final SetDefaultReadingSpeed _setDefaultReadingSpeed;
  final NextReadingSpeed _nextReadingSpeed;

  Future<void> load() async {
    final speed = await _getDefaultReadingSpeed();
    if (!isClosed && speed != state) emit(speed);
  }

  Future<void> cycle() async {
    if (isClosed) return;
    final next = _nextReadingSpeed(state);
    emit(next);
    await _setDefaultReadingSpeed(next);
  }
}
