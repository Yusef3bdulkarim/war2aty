import 'app_strings.dart';

/// Arabic (Egyptian) strings. Simple, everyday dialect (CLAUDE.md).
final class ArStrings implements AppStrings {
  const ArStrings();

  @override
  String get appName => 'ورقتي بتقول إيه؟';

  @override
  String get appTagline => 'صوّر الورقة واعرف المهم فيها.';

  @override
  String get bootstrapErrorTitle => 'مقدرناش نبدأ';

  @override
  String get bootstrapErrorMessage =>
      'حصلت مشكلة وإحنا بنجهّز التطبيق. جرّب تاني.';

  @override
  String get bootstrapStageSession => 'بنجهّز التطبيق';

  @override
  String get bootstrapStageConfig => 'بنحمّل الإعدادات';

  @override
  String get bootstrapStageCleanup => 'بننضّف الملفات المؤقتة';

  @override
  String get bootstrapStageReminders => 'بنراجع التذكيرات';

  @override
  String get bootstrapStageUsage => 'بنحدّث رصيد اليوم';

  @override
  String get actionRetry => 'حاول تاني';

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get actionOk => 'تمام';

  @override
  String get actionSave => 'حفظ';

  @override
  String get actionShare => 'مشاركة';

  @override
  String get actionDelete => 'حذف';

  @override
  String get stateLoading => 'لحظة...';

  @override
  String get stateEmpty => 'مفيش حاجة هنا لسه';

  @override
  String get stateErrorGeneric => 'حصل خطأ، حاول تاني';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navSaved => 'المحفوظات';

  @override
  String get navReminders => 'التذكيرات';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'الإنجليزية';
}
