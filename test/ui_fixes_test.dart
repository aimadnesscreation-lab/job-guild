import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:local_services_marketplace/core/services/supabase_repository.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import 'package:local_services_marketplace/features/home/providers/role_provider.dart';
import 'package:local_services_marketplace/features/jobs/models/job_model.dart';
import 'package:local_services_marketplace/features/jobs/providers/job_provider.dart';
import 'package:local_services_marketplace/features/jobs/views/job_detail_view.dart';
import 'package:local_services_marketplace/features/jobs/views/post_job_view.dart';
import 'package:local_services_marketplace/features/jobs/views/search_workers_view.dart';
import 'package:local_services_marketplace/features/notifications/views/notifications_view.dart';
// ═════════════════════════════════════════════════════════════════════
//  Stub classes
// ═════════════════════════════════════════════════════════════════════

/// A stub SupabaseRepository that throws on getApplicants to verify
/// error SnackBar handling in JobDetailView.
class _ThrowingRepository extends SupabaseRepository {
  _ThrowingRepository() : super(null);

  @override
  Future<List<Map<String, dynamic>>> getApplicants(String jobId) async {
    throw Exception('Network error: could not load applicants');
  }
}

/// A stub SupabaseRepository that returns mock notifications for testing
/// the NotificationsView. Allows pull-to-refresh to have data to display.
class _MockNotificationsRepository extends SupabaseRepository {
  _MockNotificationsRepository() : super(null);

  @override
  Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    return [
      {
        'id': 'notif-1',
        'title': 'New job match',
        'body': 'A new plumbing job matches your skills',
        'type': 'Jobs',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'notif-2',
        'title': 'Message from employer',
        'body': 'Ali wants to discuss the plumbing job',
        'type': 'Messages',
        'is_read': true,
        'created_at': DateTime.now().toIso8601String(),
      },
    ];
  }
}

/// A stub PostJobNotifier that immediately returns a state with
/// isParsingWithAi = true, so _LoadingShimmer with localized AI text is visible.
class _AiParsingStub extends PostJobNotifier {
  @override
  PostJobState build() {
    return PostJobState(isParsingWithAi: true);
  }
}

/// Stub role notifier that defaults to worker.
class _TestRoleNotifier extends RoleNotifier {
  @override
  AppRole build() => AppRole.worker;
}

/// A test job used by JobDetailView tests.
final _testJob = Job(
  id: 'test-job-1',
  title: 'Fix leaking faucet',
  description: 'The bathroom faucet is leaking badly.',
  categoryId: 13,
  budgetAmount: 2000,
  budgetType: BudgetType.fixed,
  urgency: Urgency.instant,
  locationText: 'Lahore, Gulberg',
);

/// A mock user for tests that need an authenticated user.
/// Uses fromJson to match the real supabase_flutter User constructor.
final _mockUser = User.fromJson({
  'id': 'test-user-1',
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': null,
  'phone': '+921234567890',
  'confirmed_at': null,
  'email_confirmed_at': null,
  'phone_confirmed_at': null,
  'last_sign_in_at': null,
  'created_at': DateTime.now().toIso8601String(),
  'updated_at': DateTime.now().toIso8601String(),
  'identities': <dynamic>[],
  'app_metadata': <String, dynamic>{},
  'user_metadata': <String, dynamic>{},
  'is_anonymous': false,
});

// ═════════════════════════════════════════════════════════════════════
//  Tests
// ═════════════════════════════════════════════════════════════════════

void main() {
  group('JobDetailView error handling', () {
    testWidgets('shows error SnackBar when loading applicants fails', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseRepositoryProvider.overrideWith(
              (ref) => _ThrowingRepository(),
            ),
            currentRoleProvider.overrideWith(() => _TestRoleNotifier()),
          ],
          child: MaterialApp(home: JobDetailView(job: _testJob)),
        ),
      );

      // Pump once to trigger initState -> _loadApplicants() which throws.
      await tester.pump();
      // Allow the async catch + setState + SnackBar to complete.
      await tester.pump(const Duration(seconds: 1));

      // Verify the error SnackBar appears with the error message text.
      // The SnackBar uses: '${ref.read(appStringsProvider).error}: $e'
      // which resolves to 'Error: Exception: Network error: could not load applicants'
      expect(
        find.textContaining('Network error: could not load applicants'),
        findsOneWidget,
      );
    });
  });

  group('PostJobView localized AI text', () {
    testWidgets('shows localized "AI is analyzing" text when parsing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            postJobProvider.overrideWith(() => _AiParsingStub()),
            currentRoleProvider.overrideWith(() => _TestRoleNotifier()),
          ],
          child: const MaterialApp(home: PostJobView()),
        ),
      );

      await tester.pump();

      // The _LoadingShimmer renders the localized aiIsAnalyzing string.
      expect(find.text('AI is analyzing your request...'), findsOneWidget);
    });
  });

  group('SearchWorkersView pull-to-refresh', () {
    testWidgets('renders RefreshIndicator for pull-to-refresh', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentRoleProvider.overrideWith(() => _TestRoleNotifier()),
          ],
          child: const MaterialApp(home: SearchWorkersView()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify the RefreshIndicator is present in the widget tree.
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });

  group('NotificationsView pull-to-refresh', () {
    testWidgets('renders RefreshIndicator for pull-to-refresh', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => _mockUser),
            supabaseRepositoryProvider.overrideWith(
              (ref) => _MockNotificationsRepository(),
            ),
            currentRoleProvider.overrideWith(() => _TestRoleNotifier()),
          ],
          child: const MaterialApp(home: NotificationsView()),
        ),
      );
      // Let the Future _load() complete.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify the RefreshIndicator is present in the widget tree.
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('shows notifications loaded via pull-to-refresh', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => _mockUser),
            supabaseRepositoryProvider.overrideWith(
              (ref) => _MockNotificationsRepository(),
            ),
            currentRoleProvider.overrideWith(() => _TestRoleNotifier()),
          ],
          child: const MaterialApp(home: NotificationsView()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // After loading, the notification tiles should be visible.
      expect(find.text('New job match'), findsOneWidget);
      expect(find.text('Message from employer'), findsOneWidget);
    });
  });
}
