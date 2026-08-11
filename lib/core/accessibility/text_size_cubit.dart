import 'package:flutter_bloc/flutter_bloc.dart';

import 'text_size.dart';
import 'usecases/get_text_size.dart';
import 'usecases/set_text_size.dart';

/// Holds the active [TextSize] and persists the user's choice (F11-T05).
///
/// App-scoped — the root [MediaQuery.textScaler] reads this, exactly as
/// [LocaleCubit] drives the [Locale]. Depends on use cases only.
final class TextSizeCubit extends Cubit<TextSize> {
  TextSizeCubit({
    required GetTextSize getTextSize,
    required SetTextSize setTextSize,
  }) : _getTextSize = getTextSize,
       _setTextSize = setTextSize,
       super(TextSize.normal);

  final GetTextSize _getTextSize;
  final SetTextSize _setTextSize;

  /// Restores the persisted text size, if any.
  Future<void> load() async {
    final size = await _getTextSize();
    if (size != state) emit(size);
  }

  /// Switches text size and persists it.
  Future<void> setTextSize(TextSize size) async {
    if (size == state) return;
    emit(size);
    await _setTextSize(size);
  }
}
