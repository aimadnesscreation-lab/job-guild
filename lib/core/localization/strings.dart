/// All translatable strings for the app.
/// Organized by screen/feature. Access via [AppStrings.of(context)].
class AppStrings {
  final String localeCode;

  const AppStrings(this.localeCode);

  bool get isUrdu => localeCode == 'ur';

  // ─── App ─────────────────────────────────────────────────
  String get appName =>
      _t('Local Services Marketplace', 'مقامی خدمات مارکیٹ پلیس');
  String get appTagline => _t(
    'Get your local jobs done by nearby professionals',
    'قریبی پیشہ ور افراد سے اپنی ضروریات پوری کریں',
  );

  // ─── Onboarding ──────────────────────────────────────────
  String get continueEnglish => _t('Continue', 'جاری رکھیں');
  String get goBack => _t('Go back', 'واپس جائیں');
  String get enterPhone =>
      _t('Enter your phone number', 'اپنا فون نمبر درج کریں');
  String get phoneLabel => _t('Phone Number', 'فون نمبر');
  String get phoneHint => _t('300 1234567', '300 1234567');
  String get termsFooter => _t(
    'By continuing, you agree to our Terms & Conditions',
    'جاری رکھنے سے، آپ ہماری شرائط و ضوابط سے اتفاق کرتے ہیں',
  );
  String get emptyPhoneError =>
      _t('Please enter your phone number', 'براہ کرم اپنا فون نمبر درج کریں');
  String get selectLanguage => _t('Select Language', 'زبان منتخب کریں');
  String get continueInEnglish =>
      _t('Continue in English', 'انگریزی میں جاری رکھیں');
  String get continueInUrdu => _t('Continue in Urdu', 'اردو میں جاری رکھیں');
  String get failedToSendCode =>
      _t('Failed to send code:', 'کوڈ بھیجنے میں ناکام:');

  // ─── Home ─────────────────────────────────────────────────
  String get welcomeTitle => _t(
    'Welcome to Local Services Marketplace',
    'مقامی خدمات مارکیٹ پلیس میں خوش آمدید',
  );
  String get welcomeSubtitle => _t(
    'Find nearby professionals or post a job to get started.',
    'قریبی پیشہ ور افراد تلاش کریں یا شروع کرنے کے لیے نوکری پوسٹ کریں۔',
  );
  String get postAJob => _t('Post a Job', 'نوکری پوسٹ کریں');
  String get findWorkers => _t('Find Workers', 'کارکن تلاش کریں');
  String get nearbyJobs => _t('Nearby Jobs', 'قریبی نوکریاں');
  String get seeAll => _t('See All', 'سب دیکھیں');
  String get viewDetails => _t('View Details', 'تفصیلات دیکھیں');
  String get urgentBadge => _t('URGENT', 'فوری');
  String get postJobToStart =>
      _t('Post a job to get started', 'شروع کرنے کے لیے نوکری پوسٹ کریں');
  String get couldNotLoadJobs =>
      _t('Could not load jobs:', 'نوکریاں لوڈ نہیں ہو سکیں:');
  String get reviewsComingSoon =>
      _t('Reviews coming soon', 'جائزے جلد آرہے ہیں');

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
  String get aiParsed => _t(
    'AI parsed your request. Review and edit below:',
    'AI نے آپ کی درخواست کا تجزیہ کیا۔ نیچے دیکھیں اور ترمیم کریں:',
  );
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
  String get jobPostedSuccess =>
      _t('Job posted successfully!', 'نوکری کامیابی سے پوسٹ ہو گئی!');
  String get shortTitleHint =>
      _t('Short title for your job', 'نوکری کے لیے مختصر عنوان');
  String get describeWhatNeedsDone => _t(
    'Describe what needs to be done...',
    'بیان کریں کہ کیا کرنے کی ضرورت ہے...',
  );
  String get yourCurrentLocation =>
      _t('Your current location', 'آپ کا موجودہ مقام');
  String get mapPickerComingSoon =>
      _t('Map picker coming soon', 'نقشہ چننے والا جلد آرہا ہے');
  String get aiSuggestion => _t('AI Suggestion', 'AI تجویز');
  String get urgency => _t('Urgency', 'فوری حیثیت');
  String get duration => _t('Duration', 'دورانیہ');
  String get hoursAbbrev => _t('hours', 'گھنٹے');
  String get categoryPlumbing => _t('Plumbing', 'پلمبنگ');
  String get categoryElectrical => _t('Electrical', 'الیکٹریکل');
  String get categoryPainting => _t('Painting', 'پینٹنگ');
  String get categoryCarpentry => _t('Carpentry', 'کارپینٹری');
  String get categoryMasonry => _t('Masonry', 'معماری');
  String get categoryMechanic => _t('Mechanic', 'مکینک');
  String get categoryCleaning => _t('Cleaning', 'صفائی');
  String get categoryTutor => _t('Tutor', 'ٹیوٹر');
  String get categoryMoving => _t('Moving', 'منتقل');
  String get categoryCook => _t('Cook', 'باورچی');
  String get categoryPhotographer => _t('Photographer', 'فوٹوگرافر');
  String get categoryGeneralLabor => _t('General Labor', 'جنرل لیبر');
  String get budgetTypeFixed => _t('Fixed', 'مقررہ');
  String get budgetTypeHourly => _t('Hourly', 'گھنٹہ وار');
  String get budgetTypeFlex => _t('Flex', 'لچکدار');
  String get instant => _t('Instant', 'فوری');
  String get sameDay => _t('Same day', 'آج');
  String get scheduleLabel => _t('Schedule', 'شیڈول');
  String get pickDateLabel => _t('Pick date', 'تاریخ منتخب کریں');
  String get scheduledPrefix => _t('Scheduled:', 'مقررہ:');
  String get aiIsAnalyzing => _t(
    'AI is analyzing your request...',
    'AI آپ کی درخواست کا تجزیہ کر رہا ہے...',
  );

  // ─── Worker Profile ───────────────────────────────────────
  String get workerProfile => _t('Worker Profile', 'کارکن کا پروفائل');
  String get save => _t('Save', 'محفوظ کریں');
  String get headline => _t('Headline', 'ہیڈلائن');
  String get bio => _t('Bio', 'تعارف');
  String get letAiWrite => _t('Let AI write it', 'AI کو لکھنے دیں');
  String get generateBio => _t('Generate Bio', 'تعارف تیار کریں');
  String get categories => _t('Categories', 'زمرہ جات');
  String get experience => _t('Experience', 'تجربہ');
  String get experienceAndRate => _t('Experience & Rate', 'تجربہ اور شرح');
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
  String get nameLabel => _t('Name', 'نام');
  String get yourFullName => _t('Your full name', 'آپ کا پورا نام');
  String get headlineHint => _t(
    'e.g. Experienced Plumber & Electrician',
    'مثال: تجربہ کار پلمبر اور الیکٹریشن',
  );
  String get bioHint => _t(
    'Describe your experience and skills...',
    'اپنے تجربے اور مہارتوں کی وضاحت کریں...',
  );
  String get generatingProfile =>
      _t('Generating your profile...', 'آپ کا پروفائل تیار ہو رہا ہے...');
  String get viewAiSuggestion => _t('View AI Suggestion', 'AI تجویز دیکھیں');
  String get yearsExperience => _t('Years Experience', 'سالوں کا تجربہ');
  String get lessThan1Year => _t('Less than 1', '1 سال سے کم');
  String get maxRadius => _t('Max:', 'زیادہ سے زیادہ:');
  String get noPortfolioImages => _t(
    'No portfolio images yet. Tap "Add" to showcase your work.',
    'ابھی تک کوئی پورٹ فولیو تصاویر نہیں۔ "شامل کریں" پر ٹیپ کریں۔',
  );
  String get verifiedAccount => _t('Verified Account', 'تصدیق شدہ اکاؤنٹ');
  String get yourIdentityVerified =>
      _t('Your identity has been verified', 'آپ کی شناخت کی تصدیق ہو گئی ہے');
  String get verifyIdBadge => _t(
    'Verify your ID to earn a trusted badge',
    'بھروسہ مند بیج حاصل کرنے کے لیے اپنی ID کی تصدیق کریں',
  );
  String get noRatings => _t('No ratings', 'کوئی درجہ بندی نہیں');
  String get aiGeneratedProfile =>
      _t('AI Generated Profile', 'AI سے تیار کردہ پروفائل');
  String get suggestedBio => _t('Suggested Bio:', 'تجویز کردہ تعارف:');
  String get suggestedCategories =>
      _t('Suggested Categories:', 'تجویز کردہ زمرہ جات:');
  String get dismiss => _t('Dismiss', 'مسترد کریں');
  String get add => _t('Add', 'شامل کریں');
  String get addPortfolioImage =>
      _t('Add Portfolio Image', 'پورٹ فولیو تصویر شامل کریں');
  String get pasteImageUrl => _t('Paste image URL', 'تصویر کا URL پیسٹ کریں');
  String get imageUrlLabel => _t('Image URL', 'تصویر کا URL');
  String get letAiWriteProfileTitle =>
      _t('Let AI write your profile', 'AI کو اپنا پروفائل لکھنے دیں');
  String get letAiWriteProfileDesc => _t(
    'Describe your experience in your own words, and we\'ll turn it into a professional bio.',
    'اپنے تجربے کو اپنے الفاظ میں بیان کریں، اور ہم اسے پیشہ ورانہ تعارف میں تبدیل کر دیں گے۔',
  );
  String get letAiWriteProfileExample => _t(
    'Example: "I worked in construction for 8 years, mostly plumbing and tiling."',
    'مثال: "میں نے تعمیرات میں 8 سال کام کیا، زیادہ تر پلمبنگ اور ٹائلنگ۔"',
  );
  String get describeExperienceHint =>
      _t('Describe your experience...', 'اپنا تجربہ بیان کریں...');
  String get changePhoto => _t('Change photo', 'تصویر تبدیل کریں');
  String get portfolioCount => _t('Portfolio', 'پورٹ فولیو');

  // ─── Chat ─────────────────────────────────────────────────
  String get typeAMessage => _t('Type a message...', 'پیغام لکھیں...');
  String get send => _t('Send', 'بھیجیں');
  String get noConversations =>
      _t('No conversations yet', 'ابھی کوئی بات چیت نہیں');
  String get noConvSubtitle => _t(
    'Post a job and chat with interested workers',
    'نوکری پوسٹ کریں اور دلچسپی رکھنے والے کارکنوں سے بات کریں',
  );
  String get message => _t('Message', 'پیغام');
  String get reportUser => _t('Report User', 'صارف کی اطلاع دیں');
  String get blockUser => _t('Block User', 'صارف کو بلاک کریں');
  String get viewJobDetails =>
      _t('View Job Details', 'نوکری کی تفصیلات دیکھیں');
  String get failedToSend => _t('Failed to send:', 'بھیجنے میں ناکام:');
  String get isTyping => _t('is typing...', 'ٹائپ کر رہا ہے...');
  /// Localized "You" shown for optimistic/outgoing chat messages.
  String get you => _t('You', 'آپ');
  String get gallery => _t('Gallery', 'گیلری');
  String get camera => _t('Camera', 'کیمرہ');
  String get voice => _t('Voice', 'آواز');
  String get now => _t('Now', 'ابھی');

  // ─── Search ──────────────────────────────────────────────
  String get findWorkersTitle => _t('Find Workers', 'کارکن تلاش کریں');
  String get searchHint => _t(
    'Search by name, skill, or category...',
    'نام، مہارت یا زمرہ کے لحاظ سے تلاش کریں...',
  );
  String get verifiedOnly => _t('Verified Only', 'صرف تصدیق شدہ');
  String get minimumRating => _t('Minimum Rating', 'کم از کم درجہ بندی');
  String get maximumDistance => _t('Maximum Distance', 'زیادہ سے زیادہ فاصلہ');
  String get anyAvailability => _t('Any', 'کوئی بھی');
  String get noWorkersMatch => _t(
    'No workers match your filters.',
    'آپ کے فلٹر سے کوئی کارکن نہیں ملتا۔',
  );

  // ─── Dashboard ────────────────────────────────────────────
  String get employer => _t('Employer', 'آجر');
  String get worker => _t('Worker', 'کارکن');
  String get activeJobs => _t('Active Jobs', 'فعال نوکریاں');
  String get applicants => _t('Applicants', 'درخواست دہندگان');
  String get completed => _t('Completed', 'مکمل');
  String get recentActivity => _t('Recent Activity', 'حالیہ سرگرمی');
  String get nearbyJobsCount => _t('Nearby Jobs', 'قریبی نوکریاں');
  String get applied => _t('Applied', 'درخواست دی گئی');
  String get messages => _t('Messages', 'پیغامات');
  String get rating => _t('Rating', 'درجہ بندی');
  String get profileViews => _t('Profile Views', 'پروفائل ملاحظات');
  String get earningsLog => _t('Earnings Log', 'آمدنی کا ریکارڈ');
  String get editProfile => _t('Edit Profile', 'پروفائل میں ترمیم کریں');
  String get noActiveJobs => _t(
    'No active jobs. Post a job to get started.',
    'کوئی فعال نوکری نہیں۔ شروع کرنے کے لیے نوکری پوسٹ کریں۔',
  );
  String get noCompletedJobs =>
      _t('No completed jobs yet.', 'ابھی کوئی مکمل نوکری نہیں۔');
  String get recentApplications => _t('Recent Applications', 'حالیہ درخواستیں');
  String get totalThisWeek => _t('Total this week:', 'اس ہفتے کل:');
  String get applicantCount => _t('applicants', 'درخواست دہندگان');
  String get kmLabel => _t('km', 'کلومیٹر');
  String get negotiable => _t('Negotiable', 'قابل گفت و شنید');
  String get workerName => _t('Worker', 'کارکن');

  // ─── Reports ──────────────────────────────────────────────
  String get newReport => _t('New Report', 'نئی رپورٹ');
  String get noReports => _t('No reports yet', 'ابھی تک کوئی رپورٹ نہیں');
  String get reportsHint => _t(
    'Use the report button on profiles or chats to flag issues',
    'پروفائلز یا چیٹس پر رپورٹ بٹن کا استعمال کریں تاکہ مسائل کی نشاندہی کی جا سکے',
  );
  String get reportSubmitted => _t('Report submitted', 'رپورٹ جمع ہو گئی');

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
  String get logOutConfirm =>
      _t('Are you sure you want to log out?', 'کیا آپ لاگ آؤٹ کرنا چاہتے ہیں؟');
  String get deleteConfirm => _t(
    'This will permanently delete your account and all data. This action cannot be undone. Are you sure?',
    'یہ آپ کے اکاؤنٹ اور تمام ڈیٹا کو مستقل طور پر حذف کر دے گا۔ اس عمل کو واپس نہیں کیا جا سکتا۔ کیا آپ کو یقین ہے؟',
  );
  String get cancel => _t('Cancel', 'منسوخ کریں');
  String get verifyIdentityBadge => _t(
    'Verify your identity to earn a trusted badge',
    'بھروسہ مند بیج حاصل کرنے کے لیے اپنی شناخت کی تصدیق کریں',
  );
  String get receiveAlerts => _t(
    'Receive alerts about jobs and messages',
    'نوکریوں اور پیغامات کے بارے میں الرٹس وصول کریں',
  );
  String get newJobMatches =>
      _t('New job matches in your area', 'آپ کے علاقے میں نئی نوکری کے میچز');
  String get newMessagesFrom =>
      _t('New messages from employers/workers', 'آجرین/کارکنوں سے نئے پیغامات');
  String get serviceRadiusKm => _t('Service Radius:', 'سروس کا رداس:');
  String get versionLabel => _t('Version', 'ورژن');
  String get yourAccount => _t('Your Account', 'آپ کا اکاؤنٹ');
  String get notSignedIn => _t('Not signed in', 'سائن ان نہیں');
  String get englishLabel => _t('English 🇬🇧', 'انگریزی 🇬🇧');
  String get urduLabel => _t('Urdu 🇵🇰', 'اردو 🇵🇰');

  // ─── OTP ──────────────────────────────────────────────────
  String get verifyPhone => _t('Verify Phone', 'فون کی تصدیق کریں');
  String get enterVerificationCode =>
      _t('Enter Verification Code', 'تصدیقی کوڈ درج کریں');
  String get enterCodeSentTo => _t(
    'Enter the 6-digit code sent to ',
    '6 ہندسوں کا کوڈ درج کریں جو بھیجا گیا',
  );
  String get verify => _t('Verify', 'تصدیق کریں');
  String get didntReceiveCode =>
      _t("Didn't receive the code? ", 'کوڈ موصول نہیں ہوا؟');
  String get resendIn => _t('Resend in ', 'دوبارہ بھیجیں');
  String get resendCode => _t('Resend Code', 'کوڈ دوبارہ بھیجیں');
  String get invalidCode => _t(
    'Invalid code. Please try again.',
    'غلط کوڈ۔ براہ کرم دوبارہ کوشش کریں۔',
  );
  String get enterFullCode => _t(
    'Please enter the full 6-digit code',
    'براہ کرم مکمل 6 ہندسوں کا کوڈ درج کریں',
  );
  String get failedToResend =>
      _t('Failed to resend code', 'کوڈ دوبارہ بھیجنے میں ناکام');
  String get youMustBeSignedIn =>
      _t('You must be signed in', 'آپ کو سائن ان ہونا چاہیے');

  // ─── Notifications ────────────────────────────────────────
  String get notifications => _t('Notifications', 'اطلاعات');
  String get markAllRead => _t('Mark All Read', 'سب پڑھے ہوئے نشان زد کریں');
  String get noNotifications => _t('No notifications', 'کوئی اطلاع نہیں');
  String get all => _t('All', 'تمام');
  String get unread => _t('Unread', 'نہ پڑھے گئے');
  String get jobsNotif => _t('Jobs', 'نوکریاں');
  String get reviews => _t('Reviews', 'جائزے');

  // ─── Review ──────────────────────────────────────────────
  String get rateExperience =>
      _t('Rate Your Experience', 'اپنے تجربے کی درجہ بندی کریں');
  String get howWasExperience =>
      _t('How was your experience?', 'آپ کا تجربہ کیسا تھا؟');
  String get leaveComment =>
      _t('Leave a comment (optional)', 'تبصرہ کریں (اختیاری)');
  String get submitReview => _t('Submit Review', 'جائزہ جمع کروائیں');
  String get reviewSubmitted => _t('Review Submitted', 'جائزہ جمع ہو گیا');
  String get reviewThanks =>
      _t('Thank you for your review!', 'آپ کے جائزے کا شکریہ!');
  String get reviewCommunityMsg => _t(
    'Your feedback helps build trust in the community.',
    'آپ کا تاثر کمیونٹی میں اعتماد بڑھانے میں مدد کرتا ہے۔',
  );
  String get tapStarToRate =>
      _t('Tap a star to rate', 'درجہ بندی کے لیے ستارے پر ٹیپ کریں');
  String get shareExperienceHint =>
      _t('Share your experience...', 'اپنا تجربہ شیئر کریں...');

  // ─── Navigation Tabs ────────────────────────────────────
  String get tabHome => _t('Home', 'ہوم');
  String get tabSearch => _t('Search', 'تلاش');
  String get tabPostJob => _t('Post Job', 'نوکری پوسٹ کریں');
  String get tabMessages => _t('Messages', 'پیغامات');
  String get tabDashboard => _t('Dashboard', 'ڈیش بورڈ');

  // ─── Job Detail ───────────────────────────────────────────
  String get jobDetails => _t('Job Details', 'نوکری کی تفصیلات');
  String get interestedWorkers =>
      _t('Interested Workers', 'دلچسپی رکھنے والے کارکن');
  String get noApplicants =>
      _t('No applicants yet.', 'ابھی تک کوئی درخواست نہیں');
  String get markComplete => _t('Mark Complete', 'مکمل نشان زد کریں');
  String get postedBy => _t('Posted by', 'پوسٹ کردہ');
  String get employerName => _t('Employer Name', 'آجر کا نام');
  String get skillsNeeded => _t('Skills Needed', 'مطلوبہ مہارتیں');
  String get similarJobs =>
      _t('Similar Jobs Nearby', 'قریبی ملتی جلتی نوکریاں');
  String get imInterested => _t("I'm Interested", 'مجھے دلچسپی ہے');
  String get hire => _t('Hire', 'بھرتی کریں');
  String get workerHired => _t('Worker hired!', 'کارکن بھرتی ہو گیا!');
  String get jobMarkedComplete =>
      _t('Job marked as complete!', 'نوکری مکمل نشان زد!');
  String get matchLabel => _t('Match', 'میچ');
  String get employerNotified => _t(
    'Employer will be notified of your interest',
    'آجر کو آپ کی دلچسپی سے آگاہ کر دیا جائے گا',
  );
  String get interestedCheck => _t('Interested ✓', 'دلچسپی ہے ✓');
  String get jobsPosted => _t('jobs posted', 'نوکریاں پوسٹ کی گئیں');
  String get estimatedLabel => _t('Estimated:', 'متوقع:');

  // ─── Worker Public Profile ────────────────────────────────
  String get about => _t('About', 'کے بارے میں');
  String get verifiedWorker => _t('Verified Worker', 'تصدیق شدہ کارکن');
  String get notYetVerified => _t('Not Yet Verified', 'ابھی تصدیق نہیں ہوئی');
  String get identityConfirmed =>
      _t('Identity confirmed', 'شناخت کی تصدیق ہو گئی');
  String get kmAway => _t('km away', 'کلومیٹر دور');
  String get notCompletedVerification => _t(
    'This worker has not completed verification',
    'اس کارکن نے تصدیق مکمل نہیں کی',
  );
  String get workerSavedFavorites =>
      _t('Worker saved to favorites', 'کارکن پسندیدہ میں محفوظ');
  String get workerRemovedFavorites =>
      _t('Worker removed from favorites', 'کارکن پسندیدہ سے ہٹا دیا گیا');
  String get couldNotSaveFavorite =>
      _t('Could not save favorite', 'پسندیدہ محفوظ نہیں ہو سکا');
  String get sendMessageViaJob => _t(
    'Send a message by applying to one of this worker\'s jobs',
    'اس کارکن کی نوکریوں میں سے کسی پر درخواست دے کر پیغام بھیجیں',
  );
  String get lahorePakistan => _t('Lahore, Pakistan', 'لاہور، پاکستان');

  // ─── Quick Links ─────────────────────────────────────────
  String get myReviews => _t('My Reviews', 'میرے جائزے');
  String get publicProfile => _t('Public Profile', 'عوامی پروفائل');
  String get retry => _t('Retry', 'دوبارہ کوشش کریں');
  String get noOpenJobs =>
      _t('No open jobs nearby', 'قریب میں کوئی نوکری نہیں');
  String get noReviewsYet => _t('No reviews yet', 'ابھی تک کوئی جائزہ نہیں');
  String get reviewsAppearAfterJobs => _t(
    'Reviews will appear after you complete jobs or hire workers.',
    'نوکریاں مکمل کرنے یا کارکنوں کی خدمات حاصل کرنے کے بعد جائزے ظاہر ہوں گے۔',
  );
  String get reviewsForJob => _t('For job:', 'نوکری:');
  String get reviewsGiven => _t('Given', 'دیا گیا');
  String get reviewsReceived => _t('Received', 'موصول ہوا');
  String get reviewAllTab => _t('All', 'تمام');
  String get reviewGivenTab => _t('Given', 'دیا گیا');
  String get reviewReceivedTab => _t('Received', 'موصول ہوا');
  String get noGivenReviews =>
      _t('No given reviews yet', 'ابھی تک کوئی دیے گئے جائزے نہیں');
  String get noReceivedReviews =>
      _t('No received reviews yet', 'ابھی تک کوئی موصول شدہ جائزے نہیں');

  // ─── Bottom Action Bar ────────────────────────────────────
  String get interested => _t('Interested', 'دلچسپی ہے');
  String get shortlisted => _t('Shortlisted', 'شارٹ لسٹ');
  String get hired => _t('Hired', 'بھرتی ہو گیا');

  // ─── Availability ─────────────────────────────────────────
  String get availableToday => _t('Available: Today', 'دستاب: آج');
  String get availableTomorrow => _t('Available: Tomorrow', 'دستاب: کل');
  String get asap => _t('ASAP', 'فوری');
  String get todayStr => _t('Today', 'آج');
  String get scheduledStr => _t('Scheduled', 'مقررہ');
  String get availablePrefix => _t('Available:', 'دستاب:');
  String get weekdays => _t('Weekdays', 'ہفتے کے دن');
  String get weekends => _t('Weekends', 'ہفتہ وار');
  String get morning => _t('Morning', 'صبح');
  String get evening => _t('Evening', 'شام');

  // ─── Review ──────────────────────────────────────────────
  String get pleaseSelectRating =>
      _t('Please select a rating first', 'براہ کرم پہلے درجہ بندی منتخب کریں');
  String get reviewWith => _t('with ', 'کے ساتھ');
  String get submitting => _t('Submitting...', 'جمع کر رہا ہے...');

  // ─── Map Picker ────────────────────────────────────────────
  String get selectLocation => _t('Select Location', 'مقام منتخب کریں');
  String get searchForPlace => _t('Search for a place...', 'مقام تلاش کریں...');
  String get currentLocation => _t('Current Location', 'موجودہ مقام');
  String get confirmLocation => _t('Confirm', 'تصدیق کریں');
  String get adjustSliders => _t(
    'Adjust using sliders below',
    'نیچے سلائیڈرز کا استعمال کرکے ایڈجسٹ کریں',
  );
  String get googleMaps => _t('Google Maps', 'Google Maps');
  String get googleMapsSetup => _t(
    'Set your Google Maps API key in AppConstants to enable the map view.',
    'نقشہ دیکھنے کے لیے AppConstants میں اپنی Google Maps API کلید سیٹ کریں۔',
  );
  String get useManualEntry =>
      _t('Use Manual Entry', 'دستی اندراج استعمال کریں');
  String get approxLocationNotice => _t(
    '📍 Set approximate location — your address won\'t be shared until you accept a worker.',
    '📍 تقریبی مقام مقرر کریں — آپ کا پتہ اس وقت تک شیئر نہیں کیا جائے گا جب تک آپ کسی کارکن کو قبول نہیں کرتے۔',
  );
  String get coordinateDisplay => _t('Coordinates', 'متناسقات');
  String get latLabel => _t('Lat', 'عرض');
  String get lngLabel => _t('Lng', 'طول');

  // ─── Common ──────────────────────────────────────────────
  String get done => _t('Done', 'ہو گیا');
  String get error => _t('Error', 'خرابی');
  String get loading => _t('Loading...', 'لوڈ ہو رہا ہے...');
  String get noData => _t('No data available', 'کوئی ڈیٹا دستیاب نہیں');
  String get yourName => _t('Your Name', 'آپ کا نام');
  String get confirm => _t('Confirm', 'تصدیق کریں');
  String get edit => _t('Edit', 'ترمیم');
  String get delete => _t('Delete', 'حذف کریں');
  String get search => _t('Search', 'تلاش');
  String get filter => _t('Filter', 'فلٹر');
  String get apply => _t('Apply', 'لاگو کریں');
  String get ok => _t('OK', 'ٹھیک ہے');
  String get minAbbrev => _t('min', 'منٹ');
  String get share => _t('Share', 'شیئر کریں');
  String get close => _t('Close', 'بند کریں');
  String get skip => _t('Skip', 'چھوڑیں');
  String get submit => _t('Submit', 'جمع کروائیں');

  // ─── Tutorial / Coach Marks ────────────────────────────
  String get tutorialSkip => _t('Skip', 'چھوڑیں');
  String get tutorialNext => _t('Next', 'اگلا');
  String get tutorialDone => _t('Got it!', 'سمجھ گیا!');
  String get tutorialTabSearchTitle =>
      _t('🔍 Find Workers', '🔍 کارکن تلاش کریں');
  String get tutorialTabSearchDesc => _t(
    'Browse nearby workers by category, rating, and distance. Filter by availability and verified status.',
    'زمرہ، درجہ بندی اور فاصلے کے لحاظ سے قریبی کارکنوں کو براؤز کریں۔ دستعدی اور تصدیق شدہ حیثیت کے مطابق فلٹر کریں۔',
  );
  String get tutorialTabPostTitle => _t('📝 Post a Job', '📝 نوکری پوسٹ کریں');
  String get tutorialTabPostDesc => _t(
    'Describe what you need and let AI fill in the details. Set your budget and location, then hire the best worker.',
    'بیان کریں کہ آپ کو کیا چاہیے اور AI کو تفصیلات بھرنے دیں۔ اپنا بجٹ اور مقام مقرر کریں، پھر بہترین کارکن کی خدمات حاصل کریں۔',
  );
  String get tutorialTabChatTitle => _t('💬 Messages', '💬 پیغامات');
  String get tutorialTabChatDesc => _t(
    'Chat with workers and employers about your jobs. Send images, voice messages, and share your location.',
    'نوکریوں کے بارے میں کارکنوں اور آجروں سے بات کریں۔ تصاویر، صوتی پیغامات بھیجیں اور اپنا مقام شیئر کریں۔',
  );
  String get tutorialStepCounter =>
      _t('Step {current} of {total}', 'مرحلہ {current} از {total}');

  // ─── Favorites ────────────────────────────────────────────
  String get savedWorkers => _t('Saved Workers', 'محفوظ کارکن');
  String get noSavedWorkers =>
      _t('No saved workers yet', 'ابھی تک کوئی محفوظ کارکن نہیں');
  String get favoritesHint => _t(
    'Tap the bookmark icon on a worker\'s profile to save them here.',
    'کسی کارکن کے پروفائل پر بک مارک آئیکن کو تھپتھپائیں تاکہ انہیں یہاں محفوظ کیا جا سکے۔',
  );

  /// Helper to pick a translation based on locale
  String _t(String en, String ur) => isUrdu ? ur : en;

  /// Access current strings via provider
  static AppStrings of(String localeCode) => AppStrings(localeCode);
}
