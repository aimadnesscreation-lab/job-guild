import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/localization/locale_provider.dart';
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

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    publishableKey: AppConstants.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);
    // Watch the locale so switching language (in onboarding / settings)
    // rebuilds MaterialApp with the new locale and re-localizes the UI.
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'Local Services Marketplace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: Locale(locale),
      supportedLocales: const [Locale('en'), Locale('ur')],
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: authState.when(
        data: (state) {
          if (state.session != null) {
            return const HomeView();
          }
          return const LanguageSelectionView();
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (err, stack) => Scaffold(
          body: Center(child: Text('Error: $err')),
        ),
      ),
    );
  }
}
