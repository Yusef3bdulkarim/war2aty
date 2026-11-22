import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/papers/saved_paper.dart';
import '../../../../core/papers/usecases/load_paper_image.dart';
import '../../../../core/papers/usecases/watch_paper.dart';
import '../../../../core/result/result.dart';
import 'paper_screen_state.dart';

final class PaperScreenCubit extends Cubit<PaperScreenState> {
  PaperScreenCubit(
    this._watchPaper,
    this._loadPaperImage, {
    required String paperId,
  }) : _paperId = paperId,
       super(const PaperScreenLoading());

  final WatchPaper _watchPaper;
  final LoadPaperImage _loadPaperImage;
  final String _paperId;

  StreamSubscription<void>? _subscription;
  SavedPaper? _latestPaper;
  Uint8List? _cachedImageBytes;
  bool _loadingImage = false;

  void start() {
    if (_subscription != null) return;
    _subscription = _watchPaper(_paperId).listen(_onResult);
  }

  void _onResult(Result<SavedPaper?, AppFailure> result) {
    if (isClosed) return;
    result.when(ok: _onPaper, err: _onFailure);
  }

  void _onPaper(SavedPaper? paper) {
    if (paper == null) {
      _latestPaper = null;
      _cachedImageBytes = null;
      emit(const PaperScreenNotFound());
      return;
    }

    _latestPaper = paper;
    emit(PaperScreenReady(paper: paper, imageBytes: _cachedImageBytes));

    if (paper.encryptedImagePath != null &&
        _cachedImageBytes == null &&
        !_loadingImage) {
      unawaited(_loadImage(paper.id));
    }
  }

  void _onFailure(AppFailure failure) {
    _latestPaper = null;
    _cachedImageBytes = null;
    emit(PaperScreenError(failure));
  }

  Future<void> _loadImage(String paperId) async {
    _loadingImage = true;
    final result = await _loadPaperImage(paperId);
    _loadingImage = false;
    if (isClosed) return;

    final paper = _latestPaper;
    if (paper == null || paper.id != paperId) return;

    result.when(
      ok: (bytes) {
        _cachedImageBytes = bytes;
        emit(PaperScreenReady(paper: paper, imageBytes: bytes));
      },
      err: (_) {},
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
