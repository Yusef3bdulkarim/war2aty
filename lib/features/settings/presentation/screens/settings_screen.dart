import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/accessibility/high_contrast_cubit.dart';
import '../../../../core/accessibility/text_size.dart';
import '../../../../core/accessibility/text_size_cubit.dart';
import '../../../../core/analysis/processing_mode.dart';
import '../../../../core/audio/reading_speed.dart';
import '../../../../core/audio/tts_voice.dart';
import '../../../../core/icons/stroke_icon.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/permissions/permission_service.dart';
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

/// The resume-reading row (F11-T07) — the other toggle beside the two above.
const Key settingsResumeReadingToggleKey = Key(
  'settings-resume-reading-toggle',
);

/// The «فتح إعدادات الكاميرا» row (F11-T08).
const Key settingsOpenCameraSettingsButtonKey = Key(
  'settings-open-camera-settings-button',
);

/// The «فتح إعدادات الإشعارات» row (F11-T09).
const Key settingsOpenNotificationSettingsButtonKey = Key(
  'settings-open-notification-settings-button',
);

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
              const _AudioSection(),
              const _PermissionsSection(),
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
            _RadioOption(
              title: strings.languageArabic,
              selected: current.languageCode == 'ar',
              onTap: () => onSelected('ar'),
            ),
            const SizedBox(height: _optionGap),
            _RadioOption(
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

class _RadioOption extends StatelessWidget {
  const _RadioOption({
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

/// «الصوت والقراءة» — the default reading speed and voice (F11-T07), «تجربة
/// الصوت», and the resume-reading toggle.
class _AudioSection extends StatelessWidget {
  const _AudioSection();

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) => switch (state) {
        SettingsLoading() => const SizedBox.shrink(),
        SettingsReady(
          :final defaultReadingSpeed,
          :final defaultReadingVoice,
          :final availableVoices,
          :final resumeReadingEnabled,
        ) =>
          SettingsSection(
            title: strings.settingsAudioSection,
            rows: [
              SettingsValueRow(
                glyph: StrokeGlyph.clock,
                label: strings.settingsAudioSpeedLabel,
                value: defaultReadingSpeed.label,
                onTap: () =>
                    _showReadingSpeedPicker(context, defaultReadingSpeed),
              ),
              SettingsValueRow(
                glyph: StrokeGlyph.speaker,
                label: strings.settingsAudioVoiceLabel,
                description: strings.settingsAudioVoiceDescription,
                value:
                    defaultReadingVoice?.name ??
                    strings.settingsAudioVoiceDefault,
                onTap: () => _showReadingVoicePicker(
                  context,
                  current: defaultReadingVoice,
                  voices: availableVoices,
                ),
              ),
              SettingsActionRow(
                glyph: StrokeGlyph.play,
                label: strings.settingsAudioPreviewLabel,
                onTap: () => _previewVoice(context, strings),
              ),
              SettingsToggleRow(
                key: settingsResumeReadingToggleKey,
                glyph: StrokeGlyph.resume,
                label: strings.settingsAudioResumeLabel,
                value: resumeReadingEnabled,
                onChanged: (value) => context
                    .read<SettingsCubit>()
                    .setResumeReadingEnabled(value),
              ),
            ],
          ),
      },
    );
  }
}

/// «الأذونات والتنبيهات» — the camera and notification permission rows
/// (F11-T08, F11-T09).
///
/// The design also shows a notification-privacy toggle and «حذف كل
/// التذكيرات» in this same card — no F11 task owns them yet (F11-T10/T11),
/// so they are left out rather than guessed at, the same way
/// `_AccessibilitySection` leaves out «تقليل الحركة».
///
/// Stateful only for the [AppLifecycleListener]: opening the OS settings app
/// backgrounds this app, so only a re-check on resume notices what the user
/// changed there ([SettingsCubit.refreshCameraPermission],
/// [SettingsCubit.refreshNotificationPermission]).
class _PermissionsSection extends StatefulWidget {
  const _PermissionsSection();

  @override
  State<_PermissionsSection> createState() => _PermissionsSectionState();
}

class _PermissionsSectionState extends State<_PermissionsSection> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(onResume: _onResume);
  }

  void _onResume() {
    if (!mounted) return;
    final cubit = context.read<SettingsCubit>();
    cubit.refreshCameraPermission();
    cubit.refreshNotificationPermission();
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = AppColors.of(context);

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) => switch (state) {
        SettingsLoading() => const SizedBox.shrink(),
        SettingsReady(:final cameraPermission, :final notificationPermission) =>
          SettingsSection(
            title: strings.settingsPermissionsSection,
            rows: [
              SettingsStatusRow(
                glyph: StrokeGlyph.camera,
                label: strings.settingsCameraPermissionLabel,
                statusLabel: _permissionStatusLabel(cameraPermission, strings),
                statusBackground: _permissionStatusBackground(
                  cameraPermission,
                  colors,
                ),
                statusForeground: _permissionStatusForeground(
                  cameraPermission,
                  colors,
                ),
              ),
              SettingsLinkRow(
                key: settingsOpenCameraSettingsButtonKey,
                label: strings.settingsOpenCameraSettingsLabel,
                onTap: () => context.read<SettingsCubit>().openCameraSettings(),
              ),
              SettingsStatusRow(
                glyph: StrokeGlyph.navReminders,
                label: strings.settingsNotificationPermissionLabel,
                statusLabel: _permissionStatusLabel(
                  notificationPermission,
                  strings,
                ),
                statusBackground: _permissionStatusBackground(
                  notificationPermission,
                  colors,
                ),
                statusForeground: _permissionStatusForeground(
                  notificationPermission,
                  colors,
                ),
              ),
              SettingsLinkRow(
                key: settingsOpenNotificationSettingsButtonKey,
                label: strings.settingsOpenNotificationSettingsLabel,
                onTap: () =>
                    context.read<SettingsCubit>().openNotificationSettings(),
              ),
            ],
          ),
      },
    );
  }
}

/// The pill's text for [outcome] — always paired with a color, never color
/// alone (CLAUDE.md).
String _permissionStatusLabel(PermissionOutcome outcome, AppStrings strings) =>
    switch (outcome) {
      PermissionOutcome.granted => strings.settingsPermissionGranted,
      PermissionOutcome.denied => strings.settingsPermissionDenied,
      PermissionOutcome.permanentlyDenied => strings.settingsPermissionBlocked,
    };

/// The pill's background for [outcome] — the same success/warning/error
/// triad `ReminderStatusPill` uses.
Color _permissionStatusBackground(
  PermissionOutcome outcome,
  AppColors colors,
) => switch (outcome) {
  PermissionOutcome.granted => colors.successTint,
  PermissionOutcome.denied => colors.warningTint,
  PermissionOutcome.permanentlyDenied => colors.errorTint,
};

/// The pill's text color for [outcome], matching [_permissionStatusBackground].
Color _permissionStatusForeground(
  PermissionOutcome outcome,
  AppColors colors,
) => switch (outcome) {
  PermissionOutcome.granted => colors.successInk,
  PermissionOutcome.denied => colors.warningInk,
  PermissionOutcome.permanentlyDenied => colors.error,
};

/// Plays «تجربة الصوت» and surfaces a failure — the one audio row that is
/// not a persisted value, so it has no dedicated failure state of its own
/// (no silent failures, CLAUDE.md §A3).
Future<void> _previewVoice(BuildContext context, AppStrings strings) async {
  final cubit = context.read<SettingsCubit>();
  final played = await cubit.previewVoice(strings);
  if (played || !context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(strings.settingsAudioPreviewFailedFeedback)),
    );
}

// ---------------------------------------------------------------------------
// Reading-speed picker sheet (F11-T07)
// ---------------------------------------------------------------------------

void _showReadingSpeedPicker(BuildContext context, ReadingSpeed current) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
    ),
    backgroundColor: AppColors.of(context).card,
    builder: (_) => _ReadingSpeedSheet(
      current: current,
      onSelected: (speed) {
        context.read<SettingsCubit>().setDefaultReadingSpeed(speed);
        Navigator.of(context).pop();
      },
    ),
  );
}

class _ReadingSpeedSheet extends StatelessWidget {
  const _ReadingSpeedSheet({required this.current, required this.onSelected});

  final ReadingSpeed current;
  final ValueChanged<ReadingSpeed> onSelected;

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
                strings.settingsAudioSpeedLabel,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: AppTypography.bold,
                  color: colors.ink,
                ),
              ),
            ),
            const SizedBox(height: _sheetTitleGap),
            for (final (index, speed) in ReadingSpeed.values.indexed) ...[
              if (index > 0) const SizedBox(height: _optionGap),
              _RadioOption(
                title: speed.label,
                selected: speed == current,
                onTap: () => onSelected(speed),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reading-voice picker sheet (F11-T07)
// ---------------------------------------------------------------------------

void _showReadingVoicePicker(
  BuildContext context, {
  required TtsVoice? current,
  required List<TtsVoice> voices,
}) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
    ),
    backgroundColor: AppColors.of(context).card,
    builder: (_) => _ReadingVoiceSheet(
      current: current,
      voices: voices,
      onSelected: (voice) {
        context.read<SettingsCubit>().setDefaultReadingVoice(voice);
        Navigator.of(context).pop();
      },
    ),
  );
}

class _ReadingVoiceSheet extends StatelessWidget {
  const _ReadingVoiceSheet({
    required this.current,
    required this.voices,
    required this.onSelected,
  });

  final TtsVoice? current;
  final List<TtsVoice> voices;
  final ValueChanged<TtsVoice?> onSelected;

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
                strings.settingsAudioVoiceLabel,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: AppTypography.bold,
                  color: colors.ink,
                ),
              ),
            ),
            const SizedBox(height: _sheetTitleGap),
            _RadioOption(
              title: strings.settingsAudioVoiceDefault,
              selected: current == null,
              onTap: () => onSelected(null),
            ),
            for (final voice in voices) ...[
              const SizedBox(height: _optionGap),
              _RadioOption(
                title: voice.name,
                selected: voice == current,
                onTap: () => onSelected(voice),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
