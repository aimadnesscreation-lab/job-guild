import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:local_services_marketplace/core/services/supabase_repository.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import 'package:local_services_marketplace/features/chat/providers/chat_provider.dart';
import 'package:local_services_marketplace/features/home/providers/role_provider.dart';
import 'package:local_services_marketplace/features/home/views/worker_dashboard.dart';
import 'package:local_services_marketplace/features/jobs/models/job_model.dart';
import 'package:local_services_marketplace/features/jobs/providers/job_feed_provider.dart';
import 'package:local_services_marketplace/features/worker/models/worker_profile_model.dart';
import 'package:local_services_marketplace/features/worker/providers/worker_provider.dart';
import 'package:local_services_marketplace/features/worker/views/edit_worker_profile_view.dart';

// ─── Mock User ────────────────────────────────────────────────────────

final _mockUser = User.fromJson({
  'id': 'test-worker-id',
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': null,
  'phone': null,
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

// ─── Mock Data ────────────────────────────────────────────────────────

final _mockProfile = WorkerProfile(
  userId: 'test-worker-id',
  fullName: 'Test Worker',
  headline: 'Experienced Plumber',
  bio: 'Professional plumber with 8 years of experience.',
  yearsExperience: 8,
  hourlyRatePkr: 500,
  availabilityStatus: AvailabilityStatus.today,
  serviceRadiusKm: 15,
  averageRating: 4.5,
  totalJobsCompleted: 127,
  responseTimeAvgMinutes: 12,
  categories: const ['Plumbing', 'Electrical'],
  isVerified: true,
);

final _mockApplications = <Map<String, dynamic>>[
  {
    'id': 'app-1',
    'job_id': 'job-1',
    'status': 'hired',
    'jobs': {
      'title': 'Bathroom plumbing fix',
      'budget_amount': 3000,
      'budget_type': 'fixed',
      'status': 'hired',
      'urgency': 'instant',
      'location_text': 'Lahore, Gulberg',
    },
  },
  {
    'id': 'app-2',
    'job_id': 'job-2',
    'status': 'pending',
    'jobs': {
      'title': 'AC maintenance',
      'budget_amount': 2500,
      'budget_type': 'negotiable',
      'status': 'open',
      'urgency': 'today',
      'location_text': 'Lahore, DHA',
    },
  },
];

final _mockCompletedJobs = <Map<String, dynamic>>[
  {
    'status': 'hired',
    'jobs': {
      'title': 'AC repair - 3 hours',
      'budget_amount': 1500,
      'updated_at': DateTime.now().toIso8601String(),
    },
  },
  {
    'status': 'hired',
    'jobs': {
      'title': 'Plumbing - 2 hours',
      'budget_amount': 1000,
      'updated_at': DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String(),
    },
  },
  {
    'status': 'hired',
    'jobs': {
      'title': 'Electrical - 4 hours',
      'budget_amount': 2000,
      'updated_at': DateTime.now()
          .subtract(const Duration(days: 3))
          .toIso8601String(),
    },
  },
];

// ─── Stub notifiers ───────────────────────────────────────────────────

class _ChatStub extends ChatNotifier {
  @override
  ChatState build() => const ChatState();
}

class _RoleStub extends RoleNotifier {
  @override
  AppRole build() => AppRole.worker;
}

// ═════════════════════════════════════════════════════════════════════
//  Provider Unit Tests
// ═════════════════════════════════════════════════════════════════════

void main() {
  group('workerApplicationsProvider', () {
    test('returns empty list when user is null', () async {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => null),
          supabaseRepositoryProvider.overrideWith(
            (ref) => SupabaseRepository(null),
          ),
        ],
      );
      addTearDown(container.dispose);
      final result = await container.read(workerApplicationsProvider.future);
      expect(result, isEmpty);
    });

    test(
      'returns mock applications when client is null and user exists',
      () async {
        final container = ProviderContainer(
          overrides: [
            currentUserProvider.overrideWith((ref) => _mockUser),
            supabaseRepositoryProvider.overrideWith(
              (ref) => SupabaseRepository(null),
            ),
          ],
        );
        addTearDown(container.dispose);
        final result = await container.read(workerApplicationsProvider.future);
        expect(result.length, equals(2));
        expect(result[0]['id'], equals('app-1'));
        expect(result[0]['status'], equals('hired'));
        expect(result[1]['id'], equals('app-2'));
        expect(result[1]['status'], equals('pending'));
      },
    );
  });

  group('workerCompletedJobsProvider', () {
    test('returns empty list when user is null', () async {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => null),
          supabaseRepositoryProvider.overrideWith(
            (ref) => SupabaseRepository(null),
          ),
        ],
      );
      addTearDown(container.dispose);
      final result = await container.read(workerCompletedJobsProvider.future);
      expect(result, isEmpty);
    });

    test(
      'returns mock completed jobs when client is null and user exists',
      () async {
        final container = ProviderContainer(
          overrides: [
            currentUserProvider.overrideWith((ref) => _mockUser),
            supabaseRepositoryProvider.overrideWith(
              (ref) => SupabaseRepository(null),
            ),
          ],
        );
        addTearDown(container.dispose);
        final result = await container.read(workerCompletedJobsProvider.future);
        expect(result.length, equals(3));
        expect(result[0]['status'], equals('completed'));
        expect(result[2]['status'], equals('completed'));
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════
  //  Widget Tests
  // ═══════════════════════════════════════════════════════════════════

  group('WorkerDashboard', () {
    testWidgets('shows shimmer/stats area before data resolves', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentRoleProvider.overrideWith(() => _RoleStub())],
          child: const MaterialApp(home: WorkerDashboard()),
        ),
      );
      await tester.pump();

      expect(find.text('Recent Applications'), findsOneWidget);
      expect(find.text('Earnings Log'), findsOneWidget);
    });

    testWidgets('renders stats cards with live data', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => _mockUser),
            supabaseRepositoryProvider.overrideWith(
              (ref) => SupabaseRepository(null),
            ),
            openJobsProvider.overrideWith(
              (ref) => const AsyncValue<List<Job>>.data(<Job>[]),
            ),
            chatProvider.overrideWith(() => _ChatStub()),
            myWorkerProfileProvider.overrideWith((ref) async => _mockProfile),
            workerApplicationsProvider.overrideWith(
              (ref) async => _mockApplications,
            ),
            workerCompletedJobsProvider.overrideWith(
              (ref) async => _mockCompletedJobs,
            ),
            currentRoleProvider.overrideWith(() => _RoleStub()),
          ],
          child: const MaterialApp(home: WorkerDashboard()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget);
    });

    testWidgets('shows action buttons (Edit Profile, Availability)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => _mockUser),
            supabaseRepositoryProvider.overrideWith(
              (ref) => SupabaseRepository(null),
            ),
            openJobsProvider.overrideWith(
              (ref) => const AsyncValue<List<Job>>.data(<Job>[]),
            ),
            chatProvider.overrideWith(() => _ChatStub()),
            myWorkerProfileProvider.overrideWith((ref) async => _mockProfile),
            workerApplicationsProvider.overrideWith(
              (ref) async => _mockApplications,
            ),
            workerCompletedJobsProvider.overrideWith(
              (ref) async => _mockCompletedJobs,
            ),
            currentRoleProvider.overrideWith(() => _RoleStub()),
          ],
          child: const MaterialApp(home: WorkerDashboard()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Availability'), findsOneWidget);
    });

    testWidgets('shows recent applications from mock data', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => _mockUser),
            supabaseRepositoryProvider.overrideWith(
              (ref) => SupabaseRepository(null),
            ),
            openJobsProvider.overrideWith(
              (ref) => const AsyncValue<List<Job>>.data(<Job>[]),
            ),
            chatProvider.overrideWith(() => _ChatStub()),
            myWorkerProfileProvider.overrideWith((ref) async => _mockProfile),
            workerApplicationsProvider.overrideWith(
              (ref) async => _mockApplications,
            ),
            workerCompletedJobsProvider.overrideWith(
              (ref) async => _mockCompletedJobs,
            ),
            currentRoleProvider.overrideWith(() => _RoleStub()),
          ],
          child: const MaterialApp(home: WorkerDashboard()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bathroom plumbing fix'), findsOneWidget);
      expect(find.text('AC maintenance'), findsOneWidget);
      expect(find.text('Hired'), findsWidgets);
      expect(find.text('Interested'), findsOneWidget);
    });

    testWidgets('shows earnings log from mock completed jobs', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => _mockUser),
            supabaseRepositoryProvider.overrideWith(
              (ref) => SupabaseRepository(null),
            ),
            openJobsProvider.overrideWith(
              (ref) => const AsyncValue<List<Job>>.data(<Job>[]),
            ),
            chatProvider.overrideWith(() => _ChatStub()),
            myWorkerProfileProvider.overrideWith((ref) async => _mockProfile),
            workerApplicationsProvider.overrideWith(
              (ref) async => _mockApplications,
            ),
            workerCompletedJobsProvider.overrideWith(
              (ref) async => _mockCompletedJobs,
            ),
            currentRoleProvider.overrideWith(() => _RoleStub()),
          ],
          child: const MaterialApp(home: WorkerDashboard()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AC repair - 3 hours'), findsOneWidget);
      expect(find.text('Plumbing - 2 hours'), findsOneWidget);
      expect(find.text('Electrical - 4 hours'), findsOneWidget);
      expect(find.text('PKR 4500'), findsOneWidget);
    });

    testWidgets('availability button opens bottom sheet with status chips', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => _mockUser),
            supabaseRepositoryProvider.overrideWith(
              (ref) => SupabaseRepository(null),
            ),
            openJobsProvider.overrideWith(
              (ref) => const AsyncValue<List<Job>>.data(<Job>[]),
            ),
            chatProvider.overrideWith(() => _ChatStub()),
            myWorkerProfileProvider.overrideWith((ref) async => _mockProfile),
            workerApplicationsProvider.overrideWith(
              (ref) async => _mockApplications,
            ),
            workerCompletedJobsProvider.overrideWith(
              (ref) async => _mockCompletedJobs,
            ),
            currentRoleProvider.overrideWith(() => _RoleStub()),
          ],
          child: const MaterialApp(home: WorkerDashboard()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Availability'));
      await tester.pumpAndSettle();

      expect(find.text('Set Availability'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Tomorrow'), findsOneWidget);
      expect(find.text('Weekdays'), findsOneWidget);
      expect(find.text('Weekends'), findsOneWidget);
      expect(find.text('Morning'), findsOneWidget);
      expect(find.text('Evening'), findsOneWidget);
      expect(find.text('Busy'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('edit profile button navigates to EditWorkerProfileView', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => _mockUser),
            supabaseRepositoryProvider.overrideWith(
              (ref) => SupabaseRepository(null),
            ),
            openJobsProvider.overrideWith(
              (ref) => const AsyncValue<List<Job>>.data(<Job>[]),
            ),
            chatProvider.overrideWith(() => _ChatStub()),
            myWorkerProfileProvider.overrideWith((ref) async => _mockProfile),
            workerApplicationsProvider.overrideWith(
              (ref) async => _mockApplications,
            ),
            workerCompletedJobsProvider.overrideWith(
              (ref) async => _mockCompletedJobs,
            ),
            currentRoleProvider.overrideWith(() => _RoleStub()),
          ],
          child: const MaterialApp(home: WorkerDashboard()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit Profile'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.byType(EditWorkerProfileView), findsOneWidget);
    });
  });
}
