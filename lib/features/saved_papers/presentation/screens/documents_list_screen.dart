import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/documents/recent_document.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../cubit/documents_list_cubit.dart';
import '../cubit/documents_list_state.dart';
import '../widgets/document_list_item.dart';
import '../widgets/documents_empty_state.dart';
import '../widgets/documents_search_field.dart';

// From `Waraqti.dc.html` → `isDocuments`. The 64px top padding is measured
// from the physical screen top and already contains the 52px status bar,
// which [SafeArea] applies for us; the 108px bottom clears the translucent
// nav bar (mirrors Home's page padding).
const double _pageTop = 64 - 52;
const double _pageSide = 20;
const double _pageBottom = 108;
const double _headerBottomGap = 16;
const double _rowGap = 12;

/// The «مستنداتي» screen: every saved paper, reactively (F08-T05), narrowed
/// by title as the user types (F08-T06).
///
/// The heading stays on screen through every state — only the body below it
/// swaps between loading, the list, the empty state and a failed read —
/// mirroring how Home keeps its greeting up while its own sections load.
///
/// Category filters (F08-T07) are not built yet.
class DocumentsListScreen extends StatelessWidget {
  const DocumentsListScreen({this.onScan, super.key});

  /// Where the empty state's action leads. Optional so the screen can be
  /// pumped on its own in a widget test without a router.
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(_pageSide, _pageTop, _pageSide, 0),
              child: _Header(),
            ),
            Expanded(
              child: BlocBuilder<DocumentsListCubit, DocumentsListState>(
                builder: (context, state) =>
                    _Content(state: state, onScan: onScan),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Everything below the heading.
///
/// The search field is rendered here, once — outside the part that swaps
/// between the list and the empty state — rather than inside [_Body]. A
/// keystroke that changes the match count would otherwise swap [_Body]'s
/// whole subtree (`ListView` ↔ `SingleChildScrollView`) out from under
/// [DocumentsSearchField], tearing down its `State` along with the
/// [TextEditingController] and focus it owns (F08-T06).
class _Content extends StatelessWidget {
  const _Content({required this.state, this.onScan});

  final DocumentsListState state;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    // The design only shows the field once there is something to search
    // (`hasDocs`); an active query still counts even if it currently matches
    // nothing, so the field stays up to be changed or cleared.
    final showSearch = switch (state) {
      DocumentsListAvailable(:final documents, :final query) =>
        documents.isNotEmpty || query.trim().isNotEmpty,
      _ => false,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showSearch) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: _pageSide),
            child: DocumentsSearchField(),
          ),
          const SizedBox(height: _headerBottomGap),
        ],
        Expanded(
          child: switch (state) {
            DocumentsListLoading() => const _Loading(),
            DocumentsListUnavailable() => const _LoadFailed(),
            DocumentsListAvailable(:final documents, :final query) => _Body(
              documents: documents,
              isSearching: query.trim().isNotEmpty,
              onScan: onScan,
            ),
          },
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.documents,
    required this.isSearching,
    this.onScan,
  });

  final List<RecentDocument> documents;

  /// Whether an active query, not an empty library, is why [documents] might
  /// be empty (F08-T06) — the two need different empty-state copy.
  final bool isSearching;

  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          _pageSide,
          0,
          _pageSide,
          _pageBottom,
        ),
        child: isSearching
            ? const DocumentsEmptyState.noResults()
            : DocumentsEmptyState(onScan: onScan ?? () {}),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(_pageSide, 0, _pageSide, _pageBottom),
      itemCount: documents.length,
      separatorBuilder: (context, index) => const SizedBox(height: _rowGap),
      itemBuilder: (context, index) {
        // `F08-T08` will wire a real destination; until then the row shows
        // exactly as designed but leads nowhere, the same pattern Home's
        // recent strip uses for the same not-yet-built screen.
        return DocumentListItem(document: documents[index]);
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Semantics(
      header: true,
      child: Text(
        context.strings.navDocuments,
        style: AppTypography.headlineLarge.copyWith(color: colors.ink),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: AppColors.light.brandPrimary,
        semanticsLabel: context.strings.stateLoading,
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed();

  @override
  Widget build(BuildContext context) {
    const colors = AppColors.light;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: Center(
        child: Text(
          context.strings.documentsListErrorTitle,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(color: colors.textBody),
        ),
      ),
    );
  }
}
