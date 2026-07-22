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
  String get onboardingTitle => 'افهم ورقتك في خطوات بسيطة';

  @override
  String get onboardingSubtitle =>
      'صوّر أوراقك اليومية المطبوعة زي موعد أو فاتورة أو ورقة حكومية أو '
      'تعليمية، وإحنا هنساعدك تفهم أهم ما فيها.';

  @override
  String get onboardingKindAppointment => 'موعد أو حجز';

  @override
  String get onboardingKindInvoice => 'فاتورة';

  @override
  String get onboardingKindGovernment => 'ورقة حكومية';

  @override
  String get onboardingKindEducation => 'ورقة تعليمية';

  @override
  String get onboardingStart => 'ابدأ الآن';

  @override
  String get privacyTitle => 'خصوصيتك مهمة';

  @override
  String get privacyPointExtractText => 'بنستخرج النص من الصورة علشان نحلله.';

  @override
  String get privacyPointTextOnly => 'بنرسل النص المستخرج فقط، مش صورة الورقة.';

  @override
  String get privacyPointImageOptIn => 'الصورة مش هتتحفظ إلا بعد موافقتك.';

  @override
  String get privacyPointDeleteAnytime => 'تقدر تحذف بياناتك في أي وقت.';

  @override
  String get privacyAgree => 'موافق، ابدأ';

  @override
  String get homeGreetingTitle => 'أهلًا، عندك ورقة محتاج تفهمها؟';

  @override
  String get homeGreetingSubtitle =>
      'صوّرها أو اختارها من الموبايل، وإحنا هنوضح لك أهم المعلومات.';

  @override
  String get homeScanTitle => 'صوّر ورقتك';

  @override
  String get homeScanSubtitle => 'اضغط علشان تبدأ التصوير';

  @override
  String get homePickImage => 'اختار صورة من الموبايل';

  @override
  String get homeImagePrivacyNote => 'صورتك مش هتتحفظ إلا بعد موافقتك.';

  @override
  String homeUsageRemaining(int remaining) => switch (remaining) {
    // Arabic counts in three numbers: one, two (المثنى), then many. Above ten
    // the noun returns to the singular accusative («11 تحليلًا»), which the
    // backend can reach by raising the daily limit.
    <= 0 => 'استخدمت تحليلات النهارده.',
    1 => 'متبقي لك تحليل واحد النهارده.',
    2 => 'متبقي لك تحليلان النهارده.',
    <= 10 => 'متبقي لك $remaining تحليلات النهارده.',
    _ => 'متبقي لك $remaining تحليلًا النهارده.',
  };

  @override
  String get homeEmptyTitle => 'ابدأ بتصوير أول ورقة.';

  @override
  String get homeUpcomingReminderTitle => 'تذكير قادم';

  @override
  String get homeRecentDocumentsTitle => 'آخر المستندات';

  @override
  String get timeAm => 'صباحًا';

  @override
  String get timePm => 'مساءً';

  @override
  String reminderDueToday(String time) => 'النهارده، الساعة $time';

  @override
  String reminderDueTomorrow(String time) => 'بكرة، الساعة $time';

  @override
  String reminderDueOn(String date, String time) => 'يوم $date، الساعة $time';

  @override
  String get actionView => 'عرض';

  @override
  String get homeSeeAll => 'عرض الكل';

  @override
  String get documentCategoryAppointment => 'موعد';

  @override
  String get documentCategoryInvoice => 'فاتورة';

  @override
  String get documentCategoryGovernment => 'حكومي';

  @override
  String get documentCategoryEducation => 'تعليمي';

  @override
  String get documentCategoryOther => 'أخرى';

  @override
  String get documentStoredResultOnly => 'النتيجة فقط';

  @override
  String get documentStoredWithImage => 'النتيجة وصورة الورقة';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navDocuments => 'مستنداتي';

  @override
  String get navReminders => 'التذكيرات';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'الإنجليزية';
}
