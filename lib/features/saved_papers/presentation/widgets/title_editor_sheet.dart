import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';

// From `Waraqti.dc.html` → save sheet (reuses the same sheet chrome as
// note_editor_sheet.dart).
const double _sheetRadius = 26;
const double _sheetPaddingTop = 12;
const double _sheetPaddingH = 22;
const double _sheetPaddingBottom = 30;
const double _sheetMaxHeightFactor = 0.88;
const double _grabberWidth = 40;
const double _grabberHeight = 5;
const double _grabberGapBelow = 18;
const double _titleFontSize = 19;
const double _titleGapBelow = 18;
const double _fieldRadius = 13;
const double _fieldPaddingH = 15;
const double _fieldPaddingV = 14;
const double _fieldFontSize = 15;
const double _fieldHeight = 1.7;
const double _fieldGapBelow = 18;
const double _buttonHeight = 54;
const double _buttonRadius = 15;
const double _buttonFontSize = 17;

/// Opens a sheet that lets the user rename a document (F08-T10).
///
/// Returns the confirmed title, or `null` if the user dismissed it.
/// [current] pre-fills the field with the existing title.
Future<String?> showTitleEditorSheet(
  BuildContext context, {
  required String current,
}) => showModalBottomSheet<String>(
  context: context,
  backgroundColor: AppColors.of(context).card,
  isScrollControlled: true,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * _sheetMaxHeightFactor,
  ),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
  ),
  builder: (_) => _TitleEditorSheet(current: current),
);

class _TitleEditorSheet extends StatefulWidget {
  const _TitleEditorSheet({required this.current});

  final String current;

  @override
  State<_TitleEditorSheet> createState() => _TitleEditorSheetState();
}

class _TitleEditorSheetState extends State<_TitleEditorSheet> {
  late final TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.current);
    _hasText = _controller.text.trim().isNotEmpty;
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final has = _controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            _sheetPaddingH,
            _sheetPaddingTop,
            _sheetPaddingH,
            _sheetPaddingBottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: _grabberWidth,
                  height: _grabberHeight,
                  margin: const EdgeInsets.only(bottom: _grabberGapBelow),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),
              Semantics(
                header: true,
                child: Text(
                  strings.documentEditTitleHeading,
                  style: AppTypography.titleLarge.copyWith(
                    fontSize: _titleFontSize,
                    fontWeight: AppTypography.extraBold,
                    color: colors.ink,
                  ),
                ),
              ),
              const SizedBox(height: _titleGapBelow),
              TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: _hasText ? (_) => _submit() : null,
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: _fieldFontSize,
                  height: _fieldHeight,
                  color: colors.textBody,
                ),
                decoration: InputDecoration(
                  hintText: strings.documentEditTitleHint,
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    fontSize: _fieldFontSize,
                    height: _fieldHeight,
                    color: colors.textMuted,
                  ),
                  filled: true,
                  fillColor: colors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: _fieldPaddingH,
                    vertical: _fieldPaddingV,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_fieldRadius),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: _fieldGapBelow),
              SizedBox(
                height: _buttonHeight,
                child: FilledButton(
                  onPressed: _hasText ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.brandPrimary,
                    foregroundColor: colors.onBrand,
                    disabledBackgroundColor: colors.borderSoft,
                    disabledForegroundColor: colors.textMuted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_buttonRadius),
                    ),
                    textStyle: AppTypography.labelMedium.copyWith(
                      fontSize: _buttonFontSize,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                  child: Text(strings.documentEditTitleSave),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());
}
