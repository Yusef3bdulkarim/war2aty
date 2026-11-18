import '../../capture/domain/entities/captured_photo.dart';

final class PaperRetryHolder {
  CapturedPhoto? photo;
  void clear() => photo = null;
}
