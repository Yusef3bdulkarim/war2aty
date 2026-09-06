import '../text_size.dart';
import '../text_size_store.dart';

/// Persists the user's choice for «حجم الخط» (F11-T05).
final class SetTextSize {
  const SetTextSize(this._store);

  final TextSizeStore _store;

  Future<void> call(TextSize size) => _store.writeSize(size);
}
