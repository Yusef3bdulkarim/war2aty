import 'package:flutter_bloc/flutter_bloc.dart';

import 'usecases/get_high_contrast.dart';
import 'usecases/set_high_contrast.dart';

/// Holds whether «تباين عالي» is on and persists the user's choice (F11-T06).
///
/// App-scoped — the root [AppColorsScope] reads this, exactly as
/// [TextSizeCubit] drives the root [MediaQuery.textScaler]. Depends on use
/// cases only.
final class HighContrastCubit extends Cubit<bool> {
  HighContrastCubit({
    required GetHighContrast getHighContrast,
    required SetHighContrast setHighContrast,
  }) : _getHighContrast = getHighContrast,
       _setHighContrast = setHighContrast,
       super(false);

  final GetHighContrast _getHighContrast;
  final SetHighContrast _setHighContrast;

  /// Restores the persisted choice, if any.
  Future<void> load() async {
    final enabled = await _getHighContrast();
    if (enabled != state) emit(enabled);
  }

  /// Toggles «تباين عالي» and persists it.
  Future<void> setHighContrast(bool enabled) async {
    if (enabled == state) return;
    emit(enabled);
    await _setHighContrast(enabled);
  }
}
