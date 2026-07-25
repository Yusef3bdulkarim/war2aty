/// Element-wise equality for lists held by immutable entities.
///
/// `package:flutter/foundation.dart` ships a `listEquals`, but domain entities
/// must not import Flutter — hence this pure-Dart copy in `core/`.
bool listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
