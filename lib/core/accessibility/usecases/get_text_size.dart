import '../text_size.dart';
import '../text_size_store.dart';

/// Reads the user's preferred text size (F11-T05) — defaults to
/// [TextSize.normal] until the user explicitly changes it.
final class GetTextSize {
  const GetTextSize(this._store);

  final TextSizeStore _store;

  Future<TextSize> call() async => await _store.readSize() ?? TextSize.normal;
}
