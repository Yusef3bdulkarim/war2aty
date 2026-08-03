import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/documents/usecases/watch_documents.dart';
import 'documents_list_state.dart';

/// Feeds the «مستنداتي» screen from the local database (F08-T05).
///
/// Depends on its use case only (architecture rule); it never sees the
/// repository or the database.
final class DocumentsListCubit extends Cubit<DocumentsListState> {
  DocumentsListCubit(this._watchDocuments)
    : super(const DocumentsListLoading());

  final WatchDocuments _watchDocuments;

  StreamSubscription<void>? _subscription;

  /// Starts watching the library. Safe to call more than once.
  void start() {
    if (_subscription != null) return;
    _subscription = _watchDocuments().listen((result) {
      if (isClosed) return;
      emit(
        result.when(
          ok: DocumentsListAvailable.new,
          err: DocumentsListUnavailable.new,
        ),
      );
    });
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
