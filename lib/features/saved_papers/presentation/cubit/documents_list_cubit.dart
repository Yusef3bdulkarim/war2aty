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
  String _query = '';

  /// Starts watching the library. Safe to call more than once.
  void start() {
    if (_subscription != null) return;
    _subscribe();
  }

  /// Narrows the library to titles containing [query] (F08-T06). Passing an
  /// empty or blank string clears the filter. A no-op if [query] is already
  /// the active filter, so retyping the same text does not restart the
  /// stream.
  void search(String query) {
    if (query == _query) return;
    _query = query;
    _subscribe();
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _watchDocuments(titleQuery: _query).listen((result) {
      if (isClosed) return;
      emit(
        result.when(
          ok: (documents) => DocumentsListAvailable(documents, query: _query),
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
