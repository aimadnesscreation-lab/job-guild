/// All translatable strings for the app.
/// Organized by screen/feature. Access via [AppStrings.of(context)].
class AppStrings {
  final String localeCode;

  const AppStrings(this.localeCode);

  bool get isUrdu => localeCode == 'ur';

  // ─── App ─────────────────────────────────────────────────
  String get appName => _t('Local Services Marketplace', 'مقامی خدمات مارکیٹ پلیس');
  String get appTagline => _t(
        'Get your local jobs done by nearby professionals',
        'قریبی پیشہ ور افراد سے اپنی ضروریات پوری کریں',
      );

  // ─── Onboarding ──────────────────────────────────────────
  String get continue_en => _t('Continue', 'جاری رکھیں');
  String get goBack => _t('Go back', 'واپس جائیں');
  String get enterPhone => _t('Enter your phone number', 'اپنا فون نمبر درج کریں');
  String get phoneLabel => _t('Phone Number', 'فون نمبر');
  String get phoneHint => _t('300 1234567', '300 1234567');
  String get termsFooter => _t(
        'By continuing, you agree to our Terms & Conditions',
        'جاری رکھنے سے، آپ ہماری شرائط و ضوابط سے اتفاق کرتے ہیں',
      );
  String get emptyPhoneError => _t('Please enter your phone number', 'براہ کرم اپنا فون نمبر درج کریں');
  String get selectLanguage => _t('Select Language', 'زبان منتخب کریں');

  // ─── Home ─────────────────────────────────────────────────
  String get welcomeTitle => _t('Welcome to Local Services Marketplace', 'مقامی خدمات مارکیٹ پلیس میں خوش آمدید');
  String get welcomeSubtitle => _t(
        'Find nearby professionals or post a job to get started.',
        'قریبی پیشہ ور افراد تلاش کریں یا شروع کرنے کے لیے نوکری پوسٹ کریں۔',
      );
  String get postAJob => _t('Post a Job', 'نوکری پوسٹ کریں');
  String get findWorkers => _t('Find Workers', 'کارکن تلاش کریں');
  String get nearbyJobs => _t('Nearby Jobs', 'قریبی نوکریاں');
  String get seeAll => _t('See All', 'سب دیکھیں');
  String get viewDetails => _t('View Details', 'تفصیلات دیکھیں');

  // ─── Post a Job ───────────────────────────────────────────
  String get describeWhatYouNeed => _t(
        'Describe what you need — AI will fill the details',
        'بیان کریں کہ آپ کو کیا چاہیے — AI تفصیلات بھر دے گا',
      );
  String get aiParsingHint => _t(
        'e.g. "Need a plumber to fix bathroom faucet, urgent, budget around 2000"',
        'مثال: "پلمبر کی ضرورت ہے باتھ روم کا نل ٹھیک کرنے کے لیے، فوری، بجٹ 2000 کے قریب"',
      );
  String get parseWithAi => _t('Parse with AI', 'AI سے تجزیہ کریں');
  String get analyzing => _t('Analyzing...', 'تجزیہ ہو رہا ہے...');
  String get aiParsed => _t('AI parsed your request. Review and edit below:', 'AI نے آپ کی درخواست کا تجزیہ کیا۔ نیچے دیکھیں اور ترمیم کریں:');
  String get jobTitle => _t('Job Title', 'نوکری کا عنوان');
  String get description => _t('Description', 'تفصیل');
  String get category => _t('Category', 'زمرہ');
  String get budget => _t('Budget', 'بجٹ');
  String get amount => _t('Amount (PKR)', 'رقم (PKR)');
  String get whenLabel => _t('When?', 'کب؟');
  String get location => _t('Location', 'مقام');
  String get pickDate => _t('Pick a Date', 'تاریخ منتخب کریں');
  String get postJob => _t('Post Job', 'نوکری پوسٹ کریں');
  String get posting => _t('Posting...', 'پوسٹ ہو رہا ہے...');
  String get jobPostedSuccess => _t('Job posted successfully!', 'نوکری کامیابی سے پوسٹ ہو گئی!');

  // ─── Worker Profile ───────────────────────────────────────
  String get workerProfile => _t('Worker Profile', 'کارکن کا پروفائل');
  String get save => _t('Save', 'محفوظ کریں');
  String get headline => _t('Headline', 'ہیڈلائن');
  String get bio => _t('Bio', 'تعارف');
  String get letAiWrite => _t('Let AI write it', 'AI کو لکھنے دیں');
  String get generateBio => _t('Generate Bio', 'تعارف تیار کریں');
  String get categories => _t('Categories', 'زمرہ جات');
  String get experience => _t('Experience', 'تجربہ');
  String get years => _t('years', 'سال');
  String get hourlyRate => _t('Rate (PKR/hr)', 'شرح (PKR/گھنٹہ)');
  String get serviceRadius => _t('Service Radius', 'سروس کا رداس');
  String get availability => _t('Availability', 'دستعدی');
  String get portfolio => _t('Portfolio', 'پورٹ فولیو');
  String get verification => _t('Verification', 'تصدیق');
  String get verified => _t('Verified', 'تصدیق شدہ');
  String get notVerified => _t('Not Yet Verified', 'ابھی تصدیق نہیں ہوئی');
  String get verifyNow => _t('Verify Now', 'ابھی تصدیق کریں');
  String get jobsLabel => _t('jobs', 'نوکریاں');

  // ─── Chat ─────────────────────────────────────────────────
  String get typeAMessage => _t('Type a message...', 'پیغام لکھیں...');
  String get send => _t('Send', 'بھیجیں');
  String get noConversations => _t('No conversations yet', 'ابھی کوئی بات چیت نہیں');
  String get noConvSubtitle => _t('Post a job and chat with interested workers', 'نوکری پوسٹ کریں اور دلچسپی رکھنے والے کارکنوں سے بات کریں');
  String get message => _t('Message', 'پیغام');
  String get reportUser => _t('Report User', 'صارف کی اطلاع دیں');
  String get blockUser => _t('Block User', 'صارف کو بلاک کریں');

  // ─── Search ──────────────────────────────────────────────
  String get findWorkersTitle => _t('Find Workers', 'کارکن تلاش کریں');
  String get searchHint => _t('Search by name, skill, or category...', 'نام، مہارت یا زمرہ کے لحاظ سے تلاش کریں...');
  String get verifiedOnly => _t('Verified Only', 'صرف تصدیق شدہ');
  String get minimumRating => _t('Minimum Rating', 'کم از کم درجہ بندی');
  String get maximumDistance => _t('Maximum Distance', 'زیادہ سے زیادہ فاصلہ');
  String get anyAvailability => _t('Any', 'کوئی بھی');

  // ─── Dashboard ────────────────────────────────────────────
  String get employer => _t('Employer', 'آجر');
  String get worker => _t('Worker', 'کارکن');
  String get activeJobs => _t('Active Jobs', 'فعال نوکریاں');
  String get applicants => _t('Applicants', 'درخواست دہندگان');
  String get completed => _t('Completed', 'مکمل');
  String get savedWorkers => _t('Saved Workers', 'محفوظ کارکن');
  String get recentActivity => _t('Recent Activity', 'حالیہ سرگرمی');
  String get nearbyJobsCount => _t('Nearby Jobs', 'قریبی نوکریاں');
  String get applied => _t('Applied', 'درخواست دی گئی');
  String get messages => _t('Messages', 'پیغامات');
  String get rating => _t('Rating', 'درجہ بندی');
  String get profileViews => _t('Profile Views', 'پروفائل ملاحظات');
  String get earningsLog => _t('Earnings Log', 'آمدنی کا ریکارڈ');
  String get editProfile => _t('Edit Profile', 'پروفائل میں ترمیم کریں');

  // ─── Settings ─────────────────────────────────────────────
  String get settings => _t('Settings', 'ترتیبات');
  String get account => _t('Account', 'اکاؤنٹ');
  String get appLanguage => _t('App Language', 'ایپ کی زبان');
  String get pushNotifications => _t('Push Notifications', 'پش اطلاعات');
  String get jobAlerts => _t('Job Alerts', 'نوکری کے الرٹس');
  String get messageAlerts => _t('Message Alerts', 'پیغام کے الرٹس');
  String get serviceArea => _t('Service Area', 'سروس کا علاقہ');
  String get support => _t('Support', 'سپورٹ');
  String get helpCenter => _t('Help Center', 'مدد کا مرکز');
  String get reportProblem => _t('Report a Problem', 'مسئلہ کی اطلاع دیں');
  String get logOut => _t('Log Out', 'لاگ آؤٹ');
  String get deleteAccount => _t('Delete Account', 'اکاؤنٹ حذف کریں');
  String get logOutConfirm => _t('Are you sure you want to log out?', 'کیا آپ لاگ آؤٹ کرنا چاہتے ہیں؟');
  String get deleteConfirm => _t(
        'This will permanently delete your account and all data. This action cannot be undone. Are you sure?',
        'یہ آپ کے اکاؤنٹ اور تمام ڈیٹا کو مستقل طور پر حذف کر دے گا۔ اس عمل کو واپس نہیں کیا جا سکتا۔ کیا آپ کو یقین ہے؟',
      );
  String get cancel => _t('Cancel', 'منسوخ کریں');

  // ─── Notifications ────────────────────────────────────────
  String get notifications => _t('Notifications', 'اطلاعات');
  String get markAllRead => _t('Mark All Read', 'سب پڑھے ہوئے نشان زد کریں');
  String get noNotifications => _t('No notifications', 'کوئی اطلاع نہیں');
  String get all => _t('All', 'تمام');
  String get unread => _t('Unread', 'نہ پڑھے گئے');
  String get jobsNotif => _t('Jobs', 'نوکریاں');
  String get reviews => _t('Reviews', 'جائزے');

  // ─── Review ──────────────────────────────────────────────
  String get rateExperience => _t('Rate Your Experience', 'اپنے تجربے کی درجہ بندی کریں');
  String get howWasExperience => _t('How was your experience?', 'آپ کا تجربہ کیسا تھا؟');
  String get leaveComment => _t('Leave a comment (optional)', 'تبصرہ کریں (اختیاری)');
  String get submitReview => _t('Submit Review', 'جائزہ جمع کروائیں');
  String get reviewSubmitted => _t('Review Submitted', 'جائزہ جمع ہو گیا');
  String get reviewThanks => _t('Thank you for your review!', 'آپ کے جائزے کا شکریہ!');
  String get reviewCommunityMsg => _t(
        'Your feedback helps build trust in the community.',
        'آپ کا تاثر کمیونٹی میں اعتماد بڑھانے میں مدد کرتا ہے۔',
      );

  // ─── Common ──────────────────────────────────────────────
  String get done => _t('Done', 'ہو گیا');
  String get error => _t('Error', 'خرابی');
  String get loading => _t('Loading...', 'لوڈ ہو رہا ہے...');
  String get noData => _t('No data available', 'کوئی ڈیٹا دستیاب نہیں');
  String get confirm => _t('Confirm', 'تصدیق کریں');
  String get edit => _t('Edit', 'ترمیم');
  String get delete => _t('Delete', 'حذف کریں');
  String get search => _t('Search', 'تلاش');
  String get filter => _t('Filter', 'فلٹر');
  String get apply => _t('Apply', 'لاگو کریں');
  String get ok => _t('OK', 'ٹھیک ہے');

  /// Helper to pick a translation based on locale
  String _t(String en, String ur) => isUrdu ? ur : en;

  /// Access current strings via provider
  static AppStrings of(String localeCode) => AppStrings(localeCode);
}
