import 'app_strings.dart';

/// Gregorian month names as Egypt writes them — the calendar on a bill, a
/// clinic slip or a government notice.
const List<String> _monthNames = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

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
  String get actionBack => 'رجوع';

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
  String get privacyPointExtractText =>
      'لما تكون متصل بالإنترنت، بنبعت صورة الورقة لخدمة خارجية تقرا النص منها. '
      'إحنا مابنحفظش الصورة، لكن الخدمة دي ممكن تحتفظ بيها فترة، وممكن '
      'يراجعها موظفين عندها لتحسين خدمتها. من غير إنترنت، الصورة بتتقري على '
      'موبايلك بس.';

  @override
  String get privacyPointTextOnly =>
      'بنبعت نص ورقتك مشفَّر لخدمة تحليل علشان نفهمه، ومانحفظش النص عندنا.';

  @override
  String get privacyPointImageOptIn =>
      'الصورة مش هتتحفظ على موبايلك إلا بعد موافقتك.';

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
  String get homeImagePrivacyNote =>
      'صورتك مش هتتحفظ على موبايلك إلا بعد موافقتك.';

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
  String get cameraPermissionTitle => 'اسمح باستخدام الكاميرا';

  @override
  String get cameraPermissionMessage =>
      'محتاجين الكاميرا علشان تقدر تصوّر الورقة وتفهم محتواها.';

  @override
  String get cameraPermissionBlockedMessage =>
      'الكاميرا مقفولة من إعدادات الموبايل. افتح الإعدادات واسمح بالكاميرا '
      'علشان تصوّر ورقتك.';

  @override
  String get cameraPermissionAllow => 'السماح بالكاميرا';

  @override
  String get cameraPermissionOpenSettings => 'افتح الإعدادات';

  @override
  String get cameraPermissionPickInstead => 'اختار صورة بدلًا من ذلك';

  @override
  String get cameraOpening => 'بنفتح الكاميرا…';

  @override
  String get cameraFlashOff => 'الفلاش: مطفي';

  @override
  String get cameraFlashAuto => 'الفلاش: تلقائي';

  @override
  String get cameraFlashOn => 'الفلاش: شغال';

  @override
  String get cameraFocusHint => 'المس الورقة علشان تبقى واضحة';

  @override
  String get cameraPickFromPhone => 'اختار صورة من الموبايل';

  @override
  String get cameraShutterLabel => 'التقاط الصورة';

  @override
  String get cameraCaptureErrorTitle => 'مقدرناش نفتح الكاميرا';

  @override
  String get cameraCaptureErrorMessage =>
      'حصلت مشكلة في الكاميرا. جرّب تاني، أو ارجع واختار صورة من الموبايل.';

  @override
  String get galleryOpening => 'بنفتح الصور…';

  @override
  String get galleryErrorTitle => 'مقدرناش نفتح الصور';

  @override
  String get galleryErrorMessage =>
      'حصلت مشكلة وإحنا بنفتح صور الموبايل. جرّب تاني.';

  @override
  String get previewTitle => 'قص الصورة';

  @override
  String get previewHint => 'اتأكد إن كل الكلام ظاهر قبل ما تكمل.';

  @override
  String get previewUseImage => 'استخدم الصورة';

  @override
  String get previewRetake => 'إعادة التصوير';

  @override
  String get previewRotateLabel => 'تدوير الصورة';

  @override
  String get previewProcessing => 'بنجهّز الصورة…';

  @override
  String get previewErrorMessage => 'مقدرناش نجهّز الصورة. جرّب تاني.';

  @override
  String get qualityAlertTitle => 'الصورة ممكن تكون أوضح';

  @override
  String get qualityAlertMessage =>
      'صورة أوضح بتساعدنا نقرا الكلام صح. جرّب تصوّر تاني في إضاءة '
      'أحسن، أو كمّل لو الكلام باين.';

  @override
  String get qualityAlertRetake => 'أعيد التصوير';

  @override
  String get qualityAlertContinue => 'كمّل كده';

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
  String monthName(int month) => _monthNames[month - 1];

  @override
  String currencyName(String code) => switch (code.toUpperCase()) {
    'EGP' => 'جنيه',
    'USD' => 'دولار',
    'EUR' => 'يورو',
    'SAR' => 'ريال سعودي',
    'AED' => 'درهم إماراتي',
    'KWD' => 'دينار كويتي',
    _ => code,
  };

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
  String get documentSaved => 'تم حفظ النتيجة في مستنداتي — من غير صورة الورقة';

  @override
  String get documentSavedWithImage =>
      'تم حفظ النتيجة وصورة الورقة في مستنداتي';

  @override
  String get documentSaveFailed => 'مقدرناش نحفظ الورقة. جرّب تاني.';

  @override
  String get saveModeSectionLabel => 'إيه اللي تحفظه؟';

  @override
  String get saveModeResultOnlyTitle => 'النتيجة فقط';

  @override
  String get saveModeResultOnlySubtitle =>
      'بنحفظ الملخص والتفاصيل، من غير صورة الورقة.';

  @override
  String get saveModeWithImageTitle => 'النتيجة وصورة الورقة';

  @override
  String get saveModeWithImageSubtitle =>
      'بنحفظ الملخص والتفاصيل وصورة الورقة مشفّرة على جهازك.';

  @override
  @override
  String get documentsEmptyTitle => 'لسه ماحفظتش أي مستند';

  @override
  String get documentsEmptySubtitle => 'لما تحفظ نتيجة أي ورقة هتظهر هنا.';

  @override
  String get documentsEmptyCta => 'صوّر أول ورقة';

  @override
  String get documentsListErrorTitle => 'مقدرناش نجيب مستنداتك دلوقتي.';

  @override
  String get documentsSearchHint => 'ابحث باسم المستند';

  @override
  String get documentsSearchNoResultsTitle => 'مفيش نتايج لبحثك';

  @override
  String get documentsSearchNoResultsSubtitle =>
      'جرّب اسم تاني أو راجع الإملاء.';

  @override
  String get documentsFilterAll => 'الكل';

  @override
  String get documentsFilterAppointment => 'المواعيد';

  @override
  String get documentsFilterInvoice => 'الفواتير';

  @override
  String get documentsFilterGovernment => 'الحكومية';

  @override
  String get documentsFilterEducation => 'التعليمية';

  @override
  String get documentsFilterOther => 'أخرى';

  @override
  String get documentDetailsTitle => 'تفاصيل المستند';

  @override
  String get documentDetailsNotFoundTitle => 'المستند ده مش موجود';

  @override
  String get documentDetailsNotFoundMessage =>
      'يمكن يكون اتمسح أو مبقاش موجود.';

  @override
  String get documentDetailsErrorTitle => 'مقدرناش نفتح المستند';

  @override
  String get documentDetailsErrorMessage =>
      'حصلت مشكلة وإحنا بنجيب بيانات المستند. جرّب تاني.';

  @override
  String get documentDetailsBackToList => 'رجوع للمستندات';

  @override
  String get documentImageLabel => 'صورة المستند';

  // Document notes (F08-T09)
  @override
  String get documentNoteHeading => 'ملاحظتي';
  @override
  String get documentNoteEmpty => 'مافيش ملاحظة مضافة.';
  @override
  String get documentNoteAdd => 'إضافة ملاحظة';
  @override
  String get documentNoteEdit => 'تعديل';
  @override
  String get documentNoteDelete => 'حذف الملاحظة';
  @override
  String get documentNoteHint => 'ضيف ملاحظة تساعدك تفتكر الورقة.';
  @override
  String get documentNoteSave => 'حفظ الملاحظة';
  @override
  String get documentNoteDeleteConfirmTitle => 'حذف الملاحظة؟';
  @override
  String get documentNoteDeleteConfirmMessage =>
      'لو حذفت الملاحظة مش هتقدر ترجعها تاني.';
  @override
  String get documentNoteSaved => 'تم حفظ الملاحظة.';
  @override
  String get documentNoteDeleted => 'تم حذف الملاحظة.';
  @override
  String get documentNoteError => 'مقدرناش نحفظ الملاحظة. جرّب تاني.';

  @override
  String get documentEditTitle => 'تعديل العنوان';
  @override
  String get documentEditCategory => 'تعديل التصنيف';
  @override
  String get documentEditTitleHeading => 'تعديل العنوان';
  @override
  String get documentEditTitleHint => 'اكتب عنوان جديد للمستند.';
  @override
  String get documentEditTitleSave => 'حفظ العنوان';
  @override
  String get documentEditCategoryHeading => 'تعديل التصنيف';
  @override
  String get documentTitleUpdated => 'تم تعديل العنوان.';
  @override
  String get documentCategoryUpdated => 'تم تعديل التصنيف.';
  @override
  String get documentUpdateError => 'مقدرناش نعدّل المستند. جرّب تاني.';

  // Document delete (F08-T11)
  @override
  String get documentDeleteAction => 'حذف المستند';
  @override
  String get documentDeleteConfirmTitle => 'حذف المستند؟';
  @override
  String get documentDeleteConfirmMessage =>
      'لو حذفت المستند مش هتقدر ترجعه تاني.';
  @override
  String get documentDeleted => 'تم حذف المستند.';
  @override
  String get documentDeleteError => 'مقدرناش نحذف المستند. جرّب تاني.';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navDocuments => 'مستنداتي';

  @override
  String get navReminders => 'التذكيرات';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get settingsGeneralSection => 'عام';

  @override
  String get settingsLanguageLabel => 'لغة التطبيق';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'الإنجليزية';

  @override
  String get settingsPrivacySection => 'الخصوصية';

  @override
  String get settingsAnalysisConsentLabel => 'السماح بإرسال النص للتحليل';

  @override
  String get settingsProcessingModeLabel => 'طريقة معالجة الأوراق';

  @override
  String get settingsProcessingModeSmartAnalysis => 'تحليل ذكي';

  @override
  String get settingsProcessingModeTextOnly => 'استخراج النص فقط';

  @override
  String get settingsProcessingModeSmartAnalysisDescription =>
      'الورقة تتقرأ وتتحلل عشان تفهم المهم فيها';

  @override
  String get settingsProcessingModeTextOnlyDescription =>
      'بس يطلع النص من الورقة من غير تحليل — كل حاجة تفضل على الموبايل';

  // Display / Accessibility (F11-T05)
  @override
  String get settingsDisplaySection => 'العرض';

  @override
  String get settingsTextSizeLabel => 'حجم الخط';

  @override
  String get settingsTextSizeNormal => 'عادي';

  @override
  String get settingsTextSizeLarge => 'كبير';

  @override
  String get settingsTextSizeVeryLarge => 'كبير جدًا';

  @override
  String get settingsTextSizeNormalDescription => 'الحجم الأصلي للتطبيق';

  @override
  String get settingsTextSizeLargeDescription => 'أكبر شوية — أسهل في القراءة';

  @override
  String get settingsTextSizeVeryLargeDescription =>
      'أكبر حجم — مناسب لو محتاج خط واضح جدًا';

  // Accessibility (F11-T06)
  @override
  String get settingsAccessibilitySection => 'إمكانية الوصول';

  @override
  String get settingsHighContrastLabel => 'تباين عالي';

  // Audio & reading defaults (F11-T07)
  @override
  String get settingsAudioSection => 'الصوت والقراءة';

  @override
  String get settingsAudioSpeedLabel => 'سرعة القراءة الافتراضية';

  @override
  String get settingsAudioVoiceLabel => 'صوت القراءة';

  @override
  String get settingsAudioVoiceDescription =>
      'الأصوات المتاحة حسب إعدادات الموبايل.';

  @override
  String get settingsAudioVoiceDefault => 'الصوت الافتراضي';

  @override
  String get settingsAudioPreviewLabel => 'تجربة الصوت';

  @override
  String get settingsAudioPreviewSample =>
      'أهلًا بيك في تطبيق ورقتي بتقول إيه.';

  @override
  String get settingsAudioPreviewFailedFeedback =>
      'تعذّر تشغيل عينة الصوت الآن.';

  @override
  String get settingsAudioResumeLabel => 'استكمال القراءة من آخر مكان';

  // Permissions (F11-T08)
  @override
  String get settingsPermissionsSection => 'الأذونات والتنبيهات';
  @override
  String get settingsCameraPermissionLabel => 'إذن الكاميرا';
  @override
  String get settingsPermissionGranted => 'مسموح';
  @override
  String get settingsPermissionDenied => 'غير مسموح';
  @override
  String get settingsPermissionBlocked => 'ممنوع';
  @override
  String get settingsOpenCameraSettingsLabel => 'فتح إعدادات الكاميرا';

  // Permissions (F11-T09)
  @override
  String get settingsNotificationPermissionLabel => 'إذن الإشعارات';
  @override
  String get settingsOpenNotificationSettingsLabel => 'فتح إعدادات الإشعارات';

  // Notification privacy (F11-T10)
  @override
  String get settingsNotificationPrivacyLabel =>
      'إخفاء التفاصيل الحساسة من شاشة القفل';
  @override
  String get settingsNotificationPrivacyDescription =>
      'هيظهر اسم التذكير وميعاده بس، من غير ملاحظتك.';

  @override
  String get settingsDeleteAllDocumentsLabel => 'حذف كل المستندات';
  @override
  String get settingsDeleteAllAppDataLabel => 'حذف كل بيانات التطبيق';
  @override
  String get settingsDeleteAllRemindersLabel => 'حذف كل التذكيرات';

  @override
  String get settingsDeleteAllConfirmAction => 'حذف الكل';

  @override
  String get settingsDeleteAllDocumentsConfirmTitle => 'حذف كل المستندات؟';
  @override
  String get settingsDeleteAllDocumentsConfirmMessage =>
      'هيتم حذف كل المستندات المحفوظة وصورها نهائيًا، ومش هتقدر ترجعها تاني.';
  @override
  String get settingsDeleteAllDocumentsSuccess => 'تم حذف كل المستندات.';
  @override
  String get settingsDeleteAllDocumentsError =>
      'مقدرناش نحذف المستندات. جرّب تاني.';

  @override
  String get settingsDeleteAllAppDataConfirmTitle => 'حذف كل بيانات التطبيق؟';
  @override
  String get settingsDeleteAllAppDataConfirmMessage =>
      'هيتم حذف كل المستندات والتذكيرات نهائيًا، وإعادة كل إعدادات '
      'التطبيق لوضعها الافتراضي.';
  @override
  String get settingsDeleteAllAppDataSuccess => 'تم حذف كل بيانات التطبيق.';
  @override
  String get settingsDeleteAllAppDataError =>
      'مقدرناش نحذف بيانات التطبيق. جرّب تاني.';

  @override
  String get settingsDeleteAllRemindersConfirmTitle => 'حذف كل التذكيرات؟';
  @override
  String get settingsDeleteAllRemindersConfirmMessage =>
      'هيتم حذف التذكيرات القادمة والفائتة والمكتملة نهائيًا.';
  @override
  String get settingsDeleteAllRemindersSuccess => 'تم حذف كل التذكيرات.';
  @override
  String get settingsDeleteAllRemindersError =>
      'مقدرناش نحذف التذكيرات. جرّب تاني.';

  @override
  String get settingsAboutSection => 'عن التطبيق';

  @override
  String get settingsPrivacyPolicyLabel => 'سياسة الخصوصية';

  @override
  String get settingsSupportedDocumentTypesLabel => 'أنواع الأوراق المدعومة';

  @override
  String get settingsUsageLimitLabel => 'حدود الاستخدام';

  @override
  String settingsUsageLimitValue(int used, int limit) => '$used / $limit';

  @override
  String get settingsUsageLimitUnavailable => 'غير متاح دلوقتي';

  @override
  String settingsVersionLabel(String version) => 'الإصدار $version';

  // OCR processing
  @override
  String get ocrProcessing => 'بنقرأ الورقة...';
  @override
  String get ocrErrorTitle => 'حصل مشكلة';
  @override
  String get ocrErrorMessage =>
      'مقدرناش نقرأ الورقة. جرّب تاني أو اختار صورة تانية.';
  @override
  String get ocrNoTextTitle => 'مالقيناش كلام واضح';
  @override
  String get ocrNoTextMessage =>
      'الصورة مفيهاش كلام واضح. جرّب تصوّر الورقة تاني.';
  @override
  String get ocrRetake => 'صوّر تاني';
  @override
  String get ocrPickAnother => 'اختار صورة تانية';

  // OCR extracted text
  @override
  String get ocrExtractedTextTitle => 'الكلام اللي لقيناه';
  @override
  String get ocrCopyText => 'نسخ الكلام';
  @override
  String get ocrTextCopied => 'تم النسخ';
  @override
  String get ocrContinue => 'متابعة';

  // OCR candidate labels
  @override
  String get ocrDatesSection => 'تواريخ';
  @override
  String get ocrTimesSection => 'أوقات';
  @override
  String get ocrAmountsSection => 'مبالغ';
  @override
  String get ocrPhonesSection => 'أرقام تليفون';
  @override
  String get ocrReferencesSection => 'أرقام مرجعية';

  // OCR field review
  @override
  String get ocrReviewTitle => 'راجع المعلومات';
  @override
  String get ocrReviewSubtitle => 'المعلومات دي محتاجة مراجعة — تأكد إنها صح.';
  @override
  String get ocrReviewDone => 'تمام';

  @override
  String get ocrOnlineReviewTitle => 'النص المقروء من الورقة';
  @override
  String get ocrOnlineReviewSubtitle =>
      'راجع النص وعدّل لو فيه غلط قبل التحليل';
  @override
  String get ocrOnlineLoading => 'جاري قراءة الورقة...';
  @override
  String get ocrOnlineAnalyze => 'تحليل الورقة';
  @override
  String get ocrOnlinePoorQuality =>
      'مقدرناش نقرا نص واضح من الورقة. حاول صوّرها تاني بإضاءة أحسن.';
  @override
  String get ocrOnlineShowImage => 'عرض الصورة الأصلية';
  @override
  String get ocrOnlineHideImage => 'إخفاء الصورة';
  @override
  String get ocrOnlineAmbiguityNotice => 'بعض المعلومات ممكن تحتاج مراجعة';

  @override
  String get ocrOfflineQualityWarning =>
      'النتيجة ممكن تكون أقل دقة لأن القراءة تمت بدون إنترنت';
  @override
  String get ocrOnlineFallbackWarning =>
      'القراءة الأونلاين مش متاحة دلوقتي، فقرينا الورقة على موبايلك. '
      'النتيجة ممكن تكون أقل دقة — راجع النص كويس قبل ما تكمل.';
  @override
  String get ocrListenToText => 'الاستماع للنص';

  // Analysis — while it runs
  @override
  String get analysisRunningStatus => 'بنجهّز لك شرح الورقة، استنى ثواني';
  @override
  String get analysisWaitStepType => 'بنشوف نوع الورقة';
  @override
  String get analysisWaitStepActions => 'بنشوف المطلوب منك';
  @override
  String get analysisWaitStepDates => 'بندوّر على أي مواعيد';
  @override
  String get analysisWaitStillSeconds => 'لسه ثواني، الورقة فيها تفاصيل كتير';
  @override
  String get analysisWaitReviewing => 'بنراجع كل حاجة كويس علشانك';
  @override
  String get analysisWaitTakingLonger =>
      'بتاخد وقت أطول من العادي، لسه شغالين عليها';
  @override
  String get analysisWaitReady => 'جاهز!';
  @override
  String get analysisWaitHint => 'خليك معانا، ده بياخد ثواني';
  @override
  String get analysisWaitHintLong => 'مش محتاج تعمل حاجة، هنكمّل لوحدنا';
  @override
  String get analysisWaitHintReady => 'بنفتح لك الشرح دلوقتي';
  @override
  String get analysisWaitLongAnnouncement =>
      'الورقة بتاخد وقت أطول من العادي، لسه شغالين عليها';
  @override
  String get analysisWaitReadyAnnouncement => 'الشرح جاهز';

  // Analysis result
  @override
  String get analysisResultTitle => 'نتيجة التحليل';
  @override
  String get analysisResultBackLabel => 'رجوع';
  @override
  String get analysisFailedTitle => 'حصلت مشكلة أثناء الشرح';
  @override
  String get analysisFailedMessage =>
      'مقدرناش نكمّل شرح الورقة دلوقتي. الكلام اللي قريناه لسه معانا، فتقدر '
      'تحاول تاني من غير ما تصوّر من الأول.';
  @override
  String get analysisFailedTipsTitle => 'لو المشكلة اتكررت';
  @override
  String get analysisFailedTipWait => 'استنى دقيقة وحاول تاني';
  @override
  String get analysisFailedTipConnection => 'اتأكد إن النت شغال كويس';
  @override
  String get analysisFailedTipReadText =>
      'وفي الوقت ده تقدر تقرا الكلام اللي في الورقة';
  @override
  String get analysisNoInternetTitle => 'النت فاصل دلوقتي';
  @override
  String get analysisNoInternetMessage =>
      'علشان نشرح الورقة محتاجين إنترنت. الكلام اللي فيها اتقرا خلاص، فمش '
      'هتحتاج تصوّرها تاني.';
  @override
  String get analysisNoInternetTipsTitle => 'جرّب الحاجات دي';
  @override
  String get analysisNoInternetTipWifi => 'شغّل الواي فاي أو بيانات الموبايل';
  @override
  String get analysisNoInternetTipAirplane => 'اتأكد إن وضع الطيران مقفول';
  @override
  String get analysisNoInternetTipSignal =>
      'لو الشبكة ضعيفة، قرّب من الراوتر أو جرّب مكان تاني';
  @override
  String get analysisStepPhoto => 'الصورة';
  @override
  String get analysisStepReading => 'قراية الكلام';
  @override
  String get analysisStepExplanation => 'الشرح';
  @override
  String get analysisStepDone => 'تمام';
  @override
  String get analysisStepWaitingForInternet => 'مستني النت';
  @override
  String get analysisStepNotFinished => 'ماكملش';
  @override
  String analysisStepsSemantics(String explanation) =>
      'الصورة تمام، وقراية الكلام تمام، والشرح $explanation';
  @override
  String get analysisLimitReachedTitle => 'خلّصت تحليلات النهارده';
  @override
  String get analysisLimitReachedMessage =>
      'استخدمت كل تحليلات النهارده. $_limitTextStillThere';
  @override
  String analysisLimitReachedMessageWithLimit(int limit) => switch (limit) {
    // Arabic counts in three numbers: one, two (المثنى), then many; above
    // ten the noun returns to the singular.
    <= 1 => 'عندك تحليل ذكي واحد كل يوم، واستخدمته. $_limitTextStillThere',
    2 => 'عندك تحليلين ذكيين كل يوم، واستخدمتهم الاتنين. $_limitTextStillThere',
    <= 10 =>
      'عندك $limit تحليلات ذكية كل يوم، واستخدمتهم كلهم. '
          '$_limitTextStillThere',
    _ => 'عندك $limit تحليل ذكي كل يوم، واستخدمتهم كلهم. $_limitTextStillThere',
  };
  static const _limitTextStillThere =
      'الكلام اللي في الورقة لسه متاح تقراه دلوقتي.';
  @override
  String get analysisLimitResetsInLabel => 'تحليلاتك بتتجدد بعد';
  @override
  String analysisLimitResetsIn(int hours, int minutes) {
    final parts = [
      if (hours > 0)
        switch (hours) {
          1 => 'ساعة',
          2 => 'ساعتين',
          <= 10 => '$hours ساعات',
          _ => '$hours ساعة',
        },
      if (minutes > 0)
        switch (minutes) {
          1 => 'دقيقة',
          2 => 'دقيقتين',
          <= 10 => '$minutes دقايق',
          _ => '$minutes دقيقة',
        },
    ];
    return parts.join(' و ');
  }

  @override
  String get analysisLimitResetTime => 'الساعة 12 بالليل بتوقيت مصر';
  @override
  String get analysisLimitRenewed => 'تحليلاتك اتجددت خلاص';
  @override
  String analysisLimitUsedOf(int limit) => 'استخدمت $limit من $limit النهارده';
  @override
  String get analysisLimitTipsTitle => 'تقدر تعمل إيه دلوقتي؟';
  @override
  String get analysisLimitTipReadText =>
      'اقرا الكلام اللي في الورقة وانسخه — ده مش بيستهلك تحليلات';
  @override
  String get analysisLimitTipTomorrow =>
      'خلّي الورقة معاك، وصوّرها تاني بكرة أول ما التحليلات تتجدد';
  @override
  String get analysisBackToHome => 'العودة للرئيسية';
  @override
  String get resultListen => 'استمع';
  @override
  String get resultSavePaper => 'حفظ الورقة';
  @override
  String get resultSummaryLabel => 'ملخص المستند';
  @override
  String get resultActionRequiredTitle => 'المطلوب منك';
  @override
  String get resultActionInferred => 'استنتاج من محتوى الورقة';
  @override
  String get resultWarningsTitle => 'تنبيه مهم';
  @override
  String get resultKeyInformationTitle => 'أهم المعلومات';
  @override
  String resultCopyValueLabel(String label) => 'نسخ $label';
  @override
  String get resultDatesTitle => 'التواريخ والمواعيد';
  @override
  String get resultDateNoTime => 'الورقة مافيهاش وقت محدد.';
  @override
  String get resultCreateReminder => 'إنشاء تذكير';
  @override
  String get resultPickDateTitle => 'اختار التاريخ اللي عايز تفتكره';
  @override
  String get resultPickDateMessage =>
      'الورقة فيها أكتر من تاريخ. اختار التاريخ المناسب للتذكير.';
  @override
  String get resultDateReminderWorthy => 'مناسب للتذكير';
  @override
  String get resultDateDisplayOnly => 'للعرض فقط';
  @override
  String get resultAmountsTitle => 'المبالغ';
  @override
  String get resultRequiredDocumentsTitle => 'المستندات المطلوبة';
  @override
  String get resultInstructionsTitle => 'الخطوات بالترتيب';
  @override
  String get resultShowExplanation => 'عرض شرح الورقة بالتفصيل';
  @override
  String get resultShowExtractedText => 'عرض النص المستخرج';
  @override
  String get resultExtractedTextWarning =>
      'النص المستخرج ممكن يحتوي على أخطاء قراءة.';
  @override
  String get actionCopy => 'نسخ';
  @override
  String get resultListenToText => 'استماع';
  @override
  String get resultPartialBanner =>
      'قدرنا نفهم جزء من الورقة، لكن بعض المعلومات محتاجة مراجعتك.';
  @override
  String get analysisUnsupportedTitle => 'مقدرناش نشرح الورقة دي';
  @override
  String get analysisUnsupportedMessage =>
      'ممكن يكون الكلام اللي فيها مش واضح كفاية، أو نوعها لسه مش من الأوراق '
      'اللي بنشرحها. جرّب تصوّرها تاني في نور كويس، أو صوّر ورقة من الأنواع '
      'اللي تحت.';
  @override
  String get analysisAttemptNotCounted =>
      'المحاولة دي متحسبتش من تحليلاتك النهارده';
  @override
  String get analysisExtractedTextCardSubtitle =>
      'الكلام اللي قريناه من الورقة، وتقدر تنسخه';
  @override
  String get analysisSupportedDocumentsTitle => 'الأوراق اللي بنشرحها';
  @override
  String get analysisSupportedInvoices => 'فواتير وإيصالات';
  @override
  String get analysisSupportedInvoicesExamples => 'كهربا، مية، غاز، تليفون';
  @override
  String get analysisSupportedAppointments => 'مواعيد';
  @override
  String get analysisSupportedAppointmentsExamples =>
      'ميعاد دكتور، حجز، مقابلة';
  @override
  String get analysisSupportedGovernment => 'أوراق حكومية';
  @override
  String get analysisSupportedGovernmentExamples => 'إخطار، خطاب رسمي';
  @override
  String get analysisSupportedEducation => 'أوراق تعليمية';
  @override
  String get analysisSupportedEducationExamples => 'نتيجة امتحان، ورقة مدرسة';
  @override
  String get analysisSupportedOther => 'أوراق تانية';
  @override
  String get analysisSupportedOtherExamples =>
      'تقرير طبي، ورقة قانونية، ورقة من البنك';
  @override
  String get analysisPickFromGallery => 'اختار من الصور';
  @override
  String get analysisConsentDeclinedTitle => 'الشرح الذكي مقفول';
  @override
  String get analysisConsentDeclinedMessage =>
      'إنت قافل «السماح بإرسال النص للتحليل» من الإعدادات، وده اختيارك. علشان '
      'كده مقدرناش نشرح الورقة، بس الكلام اللي فيها متاح تقراه.';
  @override
  String get analysisConsentValueTitle => 'لو فتحته، هنقولك:';
  @override
  String get analysisConsentValueType => 'نوع الورقة';
  @override
  String get analysisConsentValueKeyPoints => 'أهم اللي فيها';
  @override
  String get analysisConsentValueRequired => 'المطلوب منك';
  @override
  String get analysisConsentValueDates => 'المواعيد اللي محتاجة تذكير';
  @override
  String get analysisConsentDeclinedOpenSettings => 'افتح الإعدادات';
  @override
  String get analysisCaptureAnother => 'صوّر ورقة تانية';
  @override
  String get extractedTextOnlyTitle => 'النص المستخرج';
  @override
  String get extractedTextOnlyNote =>
      'النص المستخرج ممكن يحتوي على أخطاء قراءة. الشرح الذكي مش متاح في '
      'الوضع ده.';

  // Document kinds
  @override
  String get documentTypeLabel => 'نوع المستند';
  @override
  String get documentKindInvoice => 'فاتورة';
  @override
  String get documentKindReceipt => 'إيصال';
  @override
  String get documentKindAppointment => 'موعد';
  @override
  String get documentKindGovernment => 'حكومي';
  @override
  String get documentKindExam => 'نتيجة امتحان';
  @override
  String get documentKindMedical => 'تقرير طبي';
  @override
  String get documentKindLegal => 'ورقة قانونية';
  @override
  String get documentKindFinancial => 'ورقة مالية';
  @override
  String get documentKindEducational => 'تعليمي';
  @override
  String get documentKindOther => 'أخرى';

  // Confidence
  @override
  String get confidenceReview => 'راجع المعلومة';
  @override
  String get confidenceUncertain => 'قراءة غير مؤكدة';

  // Reminder form (F09-T02)
  @override
  String get reminderFormTitleLabel => 'عنوان التذكير';
  @override
  String get reminderFromDocumentInfoHeading => 'معلومات من الورقة';
  @override
  String get reminderEventDateLabel => 'تاريخ الحدث';
  @override
  String get reminderEventTimeLabel => 'وقت الحدث';
  @override
  String get reminderEventTimeMissing => 'غير موجود في الورقة';
  @override
  String get reminderAlertsSectionLabel => 'مواعيد التنبيه';
  @override
  String get reminderAddAnotherAlert => 'إضافة تنبيه تاني';
  @override
  String get reminderRemoveAlertLabel => 'احذف هذا التنبيه';
  @override
  String get reminderNoteLabel => 'ملاحظة';
  @override
  String get reminderNoteHint => 'ضيف أي تفاصيل محتاج تفتكرها.';
  @override
  String get reminderLinkedDocumentSectionLabel => 'ربط بمستند محفوظ';
  @override
  String get reminderLinkedDocumentValueLabel => 'مرتبط بـ';
  @override
  String get reminderSaveAction => 'حفظ التذكير';
  @override
  String get reminderAlertOffsetThreeDays => 'قبل الموعد بـ3 أيام';
  @override
  String get reminderAlertOffsetOneDay => 'قبل الموعد بيوم';
  @override
  String get reminderAlertOffsetTwoHours => 'قبل الموعد بساعتين';
  @override
  String get reminderAlertOffsetAtEventTime => 'في نفس الموعد';
  @override
  String get reminderAlertOffsetCustom => 'وقت مخصص';
  @override
  String get reminderAlertPickerTitle => 'اختار موعد التنبيه';
  @override
  String get reminderMissingEventTimeWarning =>
      'الورقة مافيهاش وقت محدد. اختار الوقت المناسب للتنبيه.';
  @override
  String reminderSuggestedAlertTime(String time) =>
      'اقتراح: نبّهني الساعة $time';
  @override
  String get reminderCreateScreenTitle => 'إنشاء تذكير';
  @override
  String get reminderAddAction => 'إضافة تذكير';
  @override
  String get reminderSuccessTitle => 'تم إنشاء التذكير بنجاح.';
  @override
  String get reminderSuccessViewAction => 'عرض التذكير';
  @override
  String get reminderManualTitleHint => 'مثال: دفع فاتورة الكهرباء';
  @override
  String get reminderDateLabel => 'التاريخ';
  @override
  String get reminderDatePickHint => 'اختار التاريخ';
  @override
  String get reminderTimeLabel => 'الوقت';
  @override
  String get reminderTimePickHint => 'اختار الوقت';
  @override
  String get reminderNotifPermTitle => 'اسمح بالتنبيهات';
  @override
  String get reminderNotifPermMessage =>
      'علشان نفتكرك بالموعد في الوقت اللي اخترته.';
  @override
  String get reminderNotifPermAllow => 'السماح بالتنبيهات';
  @override
  String get reminderNotifPermSaveWithout => 'حفظ بدون تنبيه';
  @override
  String get reminderNotificationChannelName => 'التذكيرات';
  @override
  String reminderNotificationDays(int days) => switch (days) {
    1 => 'يوم',
    2 => 'يومين',
    <= 10 => '$days أيام',
    _ => '$days يوم',
  };
  @override
  String reminderNotificationHours(int hours) => switch (hours) {
    1 => 'ساعة',
    2 => 'ساعتين',
    <= 10 => '$hours ساعات',
    _ => '$hours ساعة',
  };
  @override
  String reminderNotificationMinutes(int minutes) => switch (minutes) {
    1 => 'دقيقة',
    2 => 'دقيقتين',
    <= 10 => '$minutes دقايق',
    _ => '$minutes دقيقة',
  };
  @override
  String reminderNotificationTitleDaysLeft(String days, String title) =>
      'فاضل $days: $title';
  @override
  String reminderNotificationTitleTomorrow(String title) =>
      'بكرة آخر ميعاد: $title';
  @override
  String reminderNotificationTitleIn(String span, String title) =>
      'بعد $span: $title';
  @override
  String reminderNotificationTitleToday(String title) => 'النهارده: $title';
  @override
  String reminderNotificationTitleNow(String title) => 'دلوقتي: $title';
  @override
  String reminderNotificationBodyTimeAndNote(String time, String note) =>
      '$time • $note';
  @override
  String reminderNotificationBodyAt(String time) => 'الساعة $time';
  @override
  String get reminderNotificationTapToContinue => 'اضغط للمتابعة';
  @override
  String get reminderListTitle => 'التذكيرات';
  @override
  String get reminderTabUpcoming => 'القادمة';
  @override
  String get reminderTabMissed => 'الفائتة';
  @override
  String get reminderTabCompleted => 'المكتملة';
  @override
  String get reminderEmptyTitle => 'مافيش تذكيرات لسه';
  @override
  String get reminderEmptySubtitle =>
      'اعمل تذكير يدوي، أو أنشئ تذكير من تاريخ موجود في ورقة.';
  @override
  String get reminderEmptyScanCta => 'صوّر ورقة';
  @override
  String get reminderEmptyMissedTitle => 'مافيش تذكيرات فائتة.';
  @override
  String get reminderEmptyCompletedTitle => 'التذكيرات اللي تنفذها هتظهر هنا.';
  @override
  String get reminderStatusUpcoming => 'قادم';
  @override
  String get reminderStatusMissed => 'فائت';
  @override
  String get reminderStatusCompleted => 'تم';
  @override
  String get reminderCompleteAction => 'تم التنفيذ';
  @override
  String get reminderSnoozeAction => 'تأجيل';
  @override
  String get reminderListErrorTitle => 'مقدرناش نجيب تذكيراتك دلوقتي.';

  // Reminder details (F09-T12)
  @override
  String get reminderDetailsTitle => 'تفاصيل التذكير';
  @override
  String get reminderDetailsDateLabel => 'التاريخ';
  @override
  String get reminderDetailsTimeLabel => 'الوقت';
  @override
  String get reminderDetailsAlertLabel => 'موعد التنبيه';
  @override
  String get reminderDetailsDescriptionLabel => 'ملاحظة';
  @override
  String get reminderDetailsLinkedDocumentLabel => 'عرض المستند المرتبط';
  @override
  String get reminderDetailsNotFoundTitle => 'التذكير مش موجود';
  @override
  String get reminderDetailsNotFoundMessage =>
      'ممكن يكون التذكير ده اتحذف، أو الرابط غلط.';
  @override
  String get reminderDetailsErrorTitle => 'حصلت مشكلة';
  @override
  String get reminderDetailsErrorMessage =>
      'مقدرناش نعرض تفاصيل التذكير دلوقتي. جرّب تاني.';
  @override
  String get reminderDetailsBackToList => 'الرجوع للتذكيرات';
  @override
  String get reminderDetailsCompleteAction => 'تم التنفيذ';
  @override
  String get reminderDetailsSnoozeAction => 'تأجيل';
  @override
  String get reminderDetailsEditAction => 'تعديل';
  @override
  String get reminderDetailsDeleteAction => 'حذف';

  // Snooze sheet (F09-T12)
  @override
  String get reminderSnoozeSheetTitle => 'تأجيل التذكير';
  @override
  String get reminderSnoozeSheetSubtitle =>
      'التأجيل بيغيّر موعد التنبيه بس، مش التاريخ الأصلي للحدث.';
  @override
  String get reminderSnoozeOptionOneHour => 'بعد ساعة';
  @override
  String get reminderSnoozeOptionTomorrow => 'بكرة في نفس الوقت';
  @override
  String get reminderSnoozeOptionCustom => 'اختيار وقت جديد';

  // Delete confirmation sheet (F09-T12)
  @override
  String get reminderDeleteSheetTitle => 'حذف التذكير؟';
  @override
  String get reminderDeleteSheetMessage =>
      'الحذف نهائي ومش هتقدر ترجع التذكير بعد كده.';
  @override
  String get reminderDeleteSheetConfirm => 'حذف';
  @override
  String get reminderDeleteSheetCancel => 'إلغاء';

  // Action feedback (F09-T12)
  @override
  String get reminderCompletedFeedback => 'تم التنفيذ.';
  @override
  String get reminderSnoozedFeedback => 'تم تأجيل التذكير.';
  @override
  String get reminderDeletedFeedback => 'تم حذف التذكير.';
  @override
  String get reminderActionFailedFeedback => 'حصلت مشكلة. جرّب تاني.';

  // Audio reader mini-player (F10-T03)
  @override
  String get audioReaderSheetTitle => 'الاستماع للورقة';
  @override
  String get audioReaderModeSummary => 'الخلاصة فقط';
  @override
  String get audioReaderModeSummaryAndKeyInformation =>
      'الخلاصة وأهم المعلومات';
  @override
  String get audioReaderModeFull => 'الشرح كامل';
  @override
  String get audioReaderModeReadAll => 'قراءة كل الشاشة';
  @override
  String get audioReaderModeExtractedText => 'النص المستخرج';
  @override
  String get audioReaderOptions => 'خيارات';
  @override
  String audioReaderNowReading(String mode) => 'بيقرأ: $mode';
  @override
  String get audioReaderStartLabel => 'ابدأ الاستماع';
  @override
  String get audioReaderPauseLabel => 'إيقاف مؤقت';
  @override
  String get audioReaderResumeLabel => 'استكمال القراءة';
  @override
  String get audioReaderStopLabel => 'إيقاف القراءة';
  @override
  String get audioReaderFailedFeedback => 'حصلت مشكلة. جرّب تاني.';
  @override
  String get audioReaderSpeedLabel => 'سرعة القراءة';
}
