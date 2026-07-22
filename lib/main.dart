import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/localization/locale_provider.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/views/language_selection_view.dart';
import 'features/home/views/home_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment overrides. A missing .env file is fine — AppConstants
  // falls back to safe defaults so the app still runs in development.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env not present — defaults in AppConstants are used.
  }

  if (!AppConstants.isSupabaseConfigured) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Supabase is not configured.\n\n'
                'Copy .env.example to .env and fill in your '
                'SUPABASE_URL and SUPABASE_ANON_KEY.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    publishableKey: AppConstants.supabaseAnonKey,
  );

  // Initialize Firebase Cloud Messaging for push notifications.
  // This is best-effort — if Firebase hasn't been configured (e.g. no
  // google-services.json) it will log a warning and continue without crashing.
  await initializeFirebase();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);
    // Watch the locale so switching language (in onboarding / settings)
    // rebuilds MaterialApp with the new locale and re-localizes the UI.
    final localeCode = ref.watch(localeProvider);

    final isUrdu = localeCode == 'ur';

    return MaterialApp(
      title: ref.watch(appStringsProvider).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: Locale(localeCode),
      supportedLocales: const [Locale('en'), Locale('ur')],
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      builder: (context, child) {
        // Apply RTL text direction when Urdu is selected for proper
        // Nastaliq/Arabic-script rendering.
        return Directionality(
          textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        );
      },
      home: authState.when(
        data: (state) {
          if (state.session != null) {
            return const HomeView();
          }
          return const LanguageSelectionView();
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, stack) =>
            Scaffold(body: Center(child: Text('Error: $err'))),
      ),
    );
  }
}
