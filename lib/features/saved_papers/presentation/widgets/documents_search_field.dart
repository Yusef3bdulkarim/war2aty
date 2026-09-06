import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../cubit/documents_list_cubit.dart';

// From `Waraqti.dc.html` → `isDocuments`, the `hasDocs` search row.
const double _radius = 15;
const double _paddingV = 13;
const double _paddingH = 15;
const double _gap = 10;
const double _iconSize = 20;

/// The «مستنداتي» search field (F08-T06): filters the list by title as the
/// user types.
///
/// A [StatefulWidget] rather than folding the controller into the screen —
/// [TextEditingController] must be created once and disposed, which only a
/// `State` can guarantee (CLAUDE.md §B8). It reads [DocumentsListCubit]
/// directly rather than taking a callback: the field has nothing else to do
/// with what the user types.
class DocumentsSearchField extends StatefulWidget {
  const DocumentsSearchField({super.key});

  @override
  State<DocumentsSearchField> createState() => _DocumentsSearchFieldState();
}

class _DocumentsSearchFieldState extends State<DocumentsSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: AppShadows.low,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _paddingH,
          vertical: _paddingV,
        ),
        child: Row(
          children: [
            StrokeIcon(
              StrokeGlyph.search,
              color: colors.textMuted,
              size: _iconSize,
            ),
            const SizedBox(width: _gap),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: (value) =>
                    context.read<DocumentsListCubit>().search(value),
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.ink,
                  fontWeight: AppTypography.medium,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: context.strings.documentsSearchHint,
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: colors.textPlaceholder,
                    fontWeight: AppTypography.medium,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
