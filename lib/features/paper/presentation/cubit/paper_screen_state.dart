import 'dart:typed_data';

import '../../../../core/error/app_failure.dart';
import '../../../../core/papers/saved_paper.dart';

sealed class PaperScreenState {
  const PaperScreenState();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class PaperScreenLoading extends PaperScreenState {
  const PaperScreenLoading();
}

final class PaperScreenReady extends PaperScreenState {
  const PaperScreenReady({required this.paper, this.imageBytes});

  final SavedPaper paper;
  final Uint8List? imageBytes;

  @override
  bool operator ==(Object other) =>
      other is PaperScreenReady &&
      other.paper == paper &&
      _bytesEqual(other.imageBytes, imageBytes);

  @override
  int get hashCode => Object.hash(
    paper,
    imageBytes == null ? null : Object.hashAll(imageBytes!),
  );
}

bool _bytesEqual(Uint8List? a, Uint8List? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

final class PaperScreenNotFound extends PaperScreenState {
  const PaperScreenNotFound();
}

final class PaperScreenError extends PaperScreenState {
  const PaperScreenError(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      other is PaperScreenError && other.failure == failure;

  @override
  int get hashCode => Object.hash(runtimeType, failure);
}
