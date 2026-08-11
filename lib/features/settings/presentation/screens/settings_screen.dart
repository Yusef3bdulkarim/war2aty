import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/accessibility/high_contrast_cubit.dart';
import '../../../../core/accessibility/text_size.dart';
import '../../../../core/accessibility/text_size_cubit.dart';
import '../../../../core/analysis/processing_mode.dart';
import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/settings_section.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';

// From `Waraqti.dc.html` → `isSettings`. The 64px top already accounts for
// the status bar SafeArea applies for us, the same convention every other
// tab page in the shell uses (see `RemindersListScreen`).
const double _pageTop = 64 - 52;
const double _pageSide = 20;
const double _pageBottom = 108;
const double _headerGapBelow = 20;

/// Row keys so a test can target one specific toggle once more than one
/// [Switch] is on the screen — the analysis-consent row (F11-T02) and the
/// high-contrast row (F11-T06) would otherwise both match `find.byType`.
const Key settingsAnalysisConsentToggleKey = Key(
  'settings-analysis-consent-toggle',
);
const Key settingsHighContrastToggleKey = Key('settings-high-contrast-toggle');

/// The «الإعدادات» tab (F11-T01 onward).
///
/// The heading is a scaffold; the body below it grows one [SettingsSection]
/// per task, in the design's own order — nothing is drawn ahead of the task
/// that owns it. [SettingsCubit] backs every section from F11-T02 on.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            _pageSide,
            _pageTop,
            _pageSide,
            _pageBottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  // Same word the bottom nav already uses for this tab — the
                  // design's own H1 repeats it rather than coining a second
                  // string for the identical Arabic text.
                  context.strings.navSettings,
                  style: AppTypography.headlineLarge.copyWith(
                    color: colors.ink,
                  ),
                ),
              ),
              const SizedBox(height: _headerGapBelow),
              const _LanguageSection(),
              const _DisplaySection(),
              const _PrivacySection(),
              const _AccessibilitySection(),
            ],
          ),
        ),
      ),
    );
  }
}

/// «عام» — the language switch (F11-T04).
///
/// Reads the app-scoped [LocaleCubit] directly rather than routing through
/// [SettingsCubit]: the locale is an app-wide concern shared with
/// [MaterialApp], not a settings-screen-only flag like consent or processing
/// mode.
class _LanguageSection extends StatelessWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return BlocBuilder<LocaleCubit, Locale>(
      builder: (context, locale) => SettingsSection(
        title: strings.settingsGeneralSection,
        rows: [
          SettingsValueRow(
            glyph: StrokeGlyph.globe,
            label: strings.settingsLanguageLabel,
            value: _languageName(locale, strings),
            onTap: () => _showLanguagePicker(context, locale),
          ),
        ],
      ),
    );
  }
}

/// The display name for the current [locale].
String _languageName(Locale locale, AppStrings strings) =>
    locale.languageCode == 'ar'
    ? strings.languageArabic
    : strings.languageEnglish;

// ---------------------------------------------------------------------------
// Language picker sheet (F11-T04)
// ---------------------------------------------------------------------------

void _showLanguagePicker(BuildContext context, Locale current) {
  final localeCubit = context.read<LocaleCubit>();

  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
    ),
    backgroundColor: AppColors.of(context).card,
    builder: (_) => _LanguageSheet(
      current: current,
      onSelected: (code) {
        localeCubit.setLanguage(code);
        Navigator.of(context).pop();
      },
    ),
  );
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet({required this.current, required this.onSelected});

  final Locale current;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          _sheetPaddingH,
          _sheetPaddingTop,
          _sheetPaddingH,
          _sheetPaddingBottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                strings.settingsLanguageLabel,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: AppTypography.bold,
                  color: colors.ink,
                ),
              ),
            ),
            const SizedBox(height: _sheetTitleGap),
            _LanguageOption(
              title: strings.languageArabic,
              selected: current.languageCode == 'ar',
              onTap: () => onSelected('ar'),
            ),
            const SizedBox(height: _optionGap),
            _LanguageOption(
              title: strings.languageEnglish,
              selected: current.languageCode == 'en',
              onTap: () => onSelected('en'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: selected ? colors.brandPrimary : colors.surfaceAlt,
              width: selected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _optionPaddingH,
              vertical: _optionPaddingV,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: AppTypography.semiBold,
                      color: colors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _Radio(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «العرض» — the text-size setting (F11-T05).
///
/// Reads the app-scoped [TextSizeCubit] directly rather than routing through
/// [SettingsCubit]: like locale, the text size is an app-wide concern that
/// feeds [MediaQuery.textScaler] at the root, not a settings-screen-only flag.
class _DisplaySection extends StatelessWidget {
  const _DisplaySection();

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return BlocBuilder<TextSizeCubit, TextSize>(
      builder: (context, textSize) => SettingsSection(
        title: strings.settingsDisplaySection,
        rows: [
          SettingsValueRow(
            glyph: StrokeGlyph.textSize,
            label: strings.settingsTextSizeLabel,
            value: _textSizeName(textSize, strings),
            onTap: () => _showTextSizePicker(context, textSize),
          ),
        ],
      ),
    );
  }
}

/// The display name for the current [textSize].
String _textSizeName(TextSize textSize, AppStrings strings) =>
    switch (textSize) {
      TextSize.normal => strings.settingsTextSizeNormal,
      TextSize.large => strings.settingsTextSizeLarge,
      TextSize.veryLarge => strings.settingsTextSizeVeryLarge,
    };

// ---------------------------------------------------------------------------
// Text-size picker sheet (F11-T05)
// ---------------------------------------------------------------------------

void _showTextSizePicker(BuildContext context, TextSize current) {
  final textSizeCubit = context.read<TextSizeCubit>();

  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
    ),
    backgroundColor: AppColors.of(context).card,
    builder: (_) => _TextSizeSheet(
      current: current,
      onSelected: (size) {
        textSizeCubit.setTextSize(size);
        Navigator.of(context).pop();
      },
    ),
  );
}

class _TextSizeSheet extends StatelessWidget {
  const _TextSizeSheet({required this.current, required this.onSelected});

  final TextSize current;
  final ValueChanged<TextSize> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          _sheetPaddingH,
          _sheetPaddingTop,
          _sheetPaddingH,
          _sheetPaddingBottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                strings.settingsTextSizeLabel,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: AppTypography.bold,
                  color: colors.ink,
                ),
              ),
            ),
            const SizedBox(height: _sheetTitleGap),
            _TextSizeOption(
              title: strings.settingsTextSizeNormal,
              description: strings.settingsTextSizeNormalDescription,
              selected: current == TextSize.normal,
              onTap: () => onSelected(TextSize.normal),
            ),
            const SizedBox(height: _optionGap),
            _TextSizeOption(
              title: strings.settingsTextSizeLarge,
              description: strings.settingsTextSizeLargeDescription,
              selected: current == TextSize.large,
              onTap: () => onSelected(TextSize.large),
            ),
            const SizedBox(height: _optionGap),
            _TextSizeOption(
              title: strings.settingsTextSizeVeryLarge,
              description: strings.settingsTextSizeVeryLargeDescription,
              selected: current == TextSize.veryLarge,
              onTap: () => onSelected(TextSize.veryLarge),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextSizeOption extends StatelessWidget {
  const _TextSizeOption({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: selected ? colors.brandPrimary : colors.surfaceAlt,
              width: selected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _optionPaddingH,
              vertical: _optionPaddingV,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: AppTypography.semiBold,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: AppTypography.caption.copyWith(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _Radio(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «الخصوصية» — the analysis consent toggle (F11-T02) and the
/// processing-mode row (F11-T03).
class _PrivacySection extends StatelessWidget {
  const _PrivacySection();

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) => switch (state) {
        SettingsLoading() => const SizedBox.shrink(),
        SettingsReady(:final analysisConsent, :final processingMode) =>
          SettingsSection(
            title: strings.settingsPrivacySection,
            rows: [
              SettingsToggleRow(
                key: settingsAnalysisConsentToggleKey,
                glyph: StrokeGlyph.send,
                label: strings.settingsAnalysisConsentLabel,
                value: analysisConsent,
                onChanged: (value) =>
                    context.read<SettingsCubit>().setAnalysisConsent(value),
              ),
              SettingsValueRow(
                glyph: StrokeGlyph.documentSteps,
                label: strings.settingsProcessingModeLabel,
                value: _modeName(processingMode, strings),
                onTap: () => _showModePicker(context, processingMode),
              ),
            ],
          ),
      },
    );
  }
}

/// The short label for the current mode, shown on the row itself.
String _modeName(ProcessingMode mode, AppStrings strings) => switch (mode) {
  ProcessingMode.smartAnalysis => strings.settingsProcessingModeSmartAnalysis,
  ProcessingMode.textOnly => strings.settingsProcessingModeTextOnly,
};

// ---------------------------------------------------------------------------
// Processing-mode picker sheet (F11-T03)
// ---------------------------------------------------------------------------

/// Sheet layout constants, matching the design's pattern for option sheets.
const double _sheetRadius = 20;
const double _sheetPaddingH = 20;
const double _sheetPaddingTop = 24;
const double _sheetPaddingBottom = 32;
const double _sheetTitleGap = 16;
const double _optionGap = 12;
const double _optionPaddingH = 16;
const double _optionPaddingV = 14;
const double _radioSize = 20;

void _showModePicker(BuildContext context, ProcessingMode current) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
    ),
    backgroundColor: AppColors.of(context).card,
    builder: (_) => _ProcessingModeSheet(
      current: current,
      onSelected: (mode) {
        context.read<SettingsCubit>().setProcessingMode(mode);
        Navigator.of(context).pop();
      },
    ),
  );
}

class _ProcessingModeSheet extends StatelessWidget {
  const _ProcessingModeSheet({required this.current, required this.onSelected});

  final ProcessingMode current;
  final ValueChanged<ProcessingMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.strings;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          _sheetPaddingH,
          _sheetPaddingTop,
          _sheetPaddingH,
          _sheetPaddingBottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                strings.settingsProcessingModeLabel,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: AppTypography.bold,
                  color: colors.ink,
                ),
              ),
            ),
            const SizedBox(height: _sheetTitleGap),
            _ModeOption(
              title: strings.settingsProcessingModeSmartAnalysis,
              description:
                  strings.settingsProcessingModeSmartAnalysisDescription,
              selected: current == ProcessingMode.smartAnalysis,
              onTap: () => onSelected(ProcessingMode.smartAnalysis),
            ),
            const SizedBox(height: _optionGap),
            _ModeOption(
              title: strings.settingsProcessingModeTextOnly,
              description: strings.settingsProcessingModeTextOnlyDescription,
              selected: current == ProcessingMode.textOnly,
              onTap: () => onSelected(ProcessingMode.textOnly),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: selected ? colors.brandPrimary : colors.surfaceAlt,
              width: selected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _optionPaddingH,
              vertical: _optionPaddingV,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: AppTypography.semiBold,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: AppTypography.caption.copyWith(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _Radio(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A teal filled circle or an empty ring — no Material [Radio] dependency,
/// matching the design's own radio mark.
class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      width: _radioSize,
      height: _radioSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? colors.brandPrimary : colors.textMuted,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: _radioSize - 8,
                height: _radioSize - 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.brandPrimary,
                ),
              ),
            )
          : null,
    );
  }
}

/// «إمكانية الوصول» — the high-contrast toggle (F11-T06).
///
/// Reads the app-scoped [HighContrastCubit] directly rather than routing
/// through [SettingsCubit]: like locale and text size, high contrast is an
/// app-wide concern that recolors the whole tree through [AppColorsScope] at
/// the root, not a settings-screen-only flag.
///
/// The design also shows a «تقليل الحركة» (reduce motion) row in this same
/// section — no F11 task owns it yet, so it is left out rather than guessed
/// at.
class _AccessibilitySection extends StatelessWidget {
  const _AccessibilitySection();

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return BlocBuilder<HighContrastCubit, bool>(
      builder: (context, highContrast) => SettingsSection(
        title: strings.settingsAccessibilitySection,
        rows: [
          SettingsToggleRow(
            key: settingsHighContrastToggleKey,
            glyph: StrokeGlyph.contrast,
            label: strings.settingsHighContrastLabel,
            value: highContrast,
            onChanged: (value) =>
                context.read<HighContrastCubit>().setHighContrast(value),
          ),
        ],
      ),
    );
  }
}
