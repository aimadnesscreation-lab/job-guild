import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:local_services_marketplace/core/providers/tutorial_provider.dart';
import 'package:local_services_marketplace/features/auth/views/language_selection_view.dart';
import 'package:local_services_marketplace/features/home/providers/role_provider.dart';
import 'package:local_services_marketplace/features/home/views/home_view.dart';
import 'package:local_services_marketplace/features/worker/models/worker_profile_model.dart';
import 'package:local_services_marketplace/features/worker/views/edit_worker_profile_view.dart';
import 'package:local_services_marketplace/features/worker/views/worker_public_profile_view.dart';

/// Helper to wrap a widget in MaterialApp + ProviderScope for testing.
/// ProviderScope wraps MaterialApp so that navigation overlays
/// (e.g. bottom sheets with ConsumerWidgets) can access providers.
Widget createTestApp(Widget child) {
  return ProviderScope(
    overrides: [
      // Role defaults to worker in tests so the feed shows job listings (the
      // most commonly tested path). Employer-mode tests can override this.
      currentRoleProvider.overrideWith(() => _TestRoleNotifier()),
      // Tutorial state completes immediately to avoid the loading gate in
      // HomeView tests.
      tutorialCompletedProvider.overrideWith(() => _TestTutorialNotifier()),
    ],
    child: MaterialApp(home: child),
  );
}

/// Test notifier that defaults to worker mode.
class _TestRoleNotifier extends RoleNotifier {
  @override
  AppRole build() => AppRole.worker;
}

/// Test notifier that completes the tutorial check immediately so HomeView
/// tests don't have to wait for SharedPreferences.
class _TestTutorialNotifier extends TutorialNotifier {
  @override
  Future<bool> build() async => true;
}

void main() {
  group('LanguageSelectionView', () {
    testWidgets('renders language selection cards for English and Urdu', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const LanguageSelectionView()));
      await tester.pumpAndSettle();

      expect(find.text('Local Services Marketplace'), findsOneWidget);
      expect(
        find.text('Get your local jobs done by nearby professionals'),
        findsOneWidget,
      );
      expect(find.text('English'), findsOneWidget);
      expect(find.text('اردو'), findsOneWidget);
    });

    testWidgets('tapping a language card shows continue to role selection', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const LanguageSelectionView()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      // After selecting a language, "Create your account" and "Continue"
      // appear (the flow now goes to RoleSelectionView instead of phone input).
      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('tapping back button returns to language selection', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const LanguageSelectionView()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('Continue'), findsOneWidget);

      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();
      expect(find.text('English'), findsOneWidget);
      expect(find.text('اردو'), findsOneWidget);
    });
  });

  group('HomeView', () {
    testWidgets('renders bottom navigation bar with worker-only tabs', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const HomeView()));
      await tester.pumpAndSettle();

      // Worker mode (test default) has 4 tabs: Home, Search, Messages, Dashboard.
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      // "Post Job" should NOT appear in worker mode
      expect(find.text('Post Job'), findsNothing);
    });

    testWidgets(
      'shows worker welcome card and live job feed header on home tab',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp(const HomeView()));
        // Don't pumpAndSettle — the Realtime stream will not settle
        await tester.pump();

        // Welcome card should still render
        expect(
          find.text('Welcome to Local Services Marketplace'),
          findsOneWidget,
        );
        // Live job feed header
        expect(find.text('Nearby Jobs'), findsOneWidget);
        // Worker mode: no employer action buttons
        expect(find.text('Post a Job'), findsNothing);
        expect(find.text('Find Workers'), findsNothing);
      },
    );
  });

  group('EditWorkerProfileView', () {
    testWidgets('renders the edit profile screen with key sections', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const EditWorkerProfileView()));
      await tester.pumpAndSettle();

      // App bar with Save button
      expect(find.text('Worker Profile'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Section headers
      expect(find.text('Headline'), findsOneWidget);
      expect(find.text('Bio'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Experience & Rate'), findsOneWidget);
      expect(find.text('Service Radius'), findsOneWidget);
      expect(find.text('Availability'), findsOneWidget);
      expect(find.text('Portfolio'), findsOneWidget);
      expect(find.text('Verification'), findsOneWidget);

      // With no worker profile set up, the form must NOT show fabricated
      // data. It should show an empty "Your Name" placeholder and 0 jobs,
      // not someone else's name/verification/stats.
      expect(find.text('Your Name'), findsOneWidget);
      expect(find.text('0 jobs'), findsOneWidget);
    });

    testWidgets('shows AI bio generation button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const EditWorkerProfileView()));
      await tester.pumpAndSettle();

      expect(find.text('Let AI write it'), findsOneWidget);
    });

    testWidgets('shows all availability options', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const EditWorkerProfileView()));
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Tomorrow'), findsOneWidget);
      expect(find.text('Weekdays'), findsOneWidget);
      expect(find.text('Weekends'), findsOneWidget);
      expect(find.text('Morning'), findsOneWidget);
      expect(find.text('Evening'), findsOneWidget);
      expect(find.text('Busy'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('tapping AI bio button opens bottom sheet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestApp(const EditWorkerProfileView()));
      await tester.pumpAndSettle();

      // Tap the AI bio button
      await tester.tap(find.text('Let AI write it'));
      await tester.pumpAndSettle();

      // Bottom sheet appears
      expect(find.text('Let AI write your profile'), findsOneWidget);
      expect(find.text('Generate Bio'), findsOneWidget);
    });

    testWidgets('shows portfolio section', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const EditWorkerProfileView()));
      await tester.pumpAndSettle();

      expect(find.text('0/10'), findsOneWidget);
      expect(
        find.text('No portfolio images yet. Tap "Add" to showcase your work.'),
        findsOneWidget,
      );
    });
  });

  group('WorkerPublicProfileView', () {
    // A real profile passed directly via the `profile` constructor param.
    final sampleWorker = WorkerProfile(
      userId: 'worker-1',
      fullName: 'Ali Raza',
      headline: 'Experienced Plumber & Electrician',
      bio: 'I have been working in home maintenance for over 8 years.',
      yearsExperience: 8,
      hourlyRatePkr: 500,
      availabilityStatus: AvailabilityStatus.today,
      serviceRadiusKm: 15,
      averageRating: 4.5,
      totalJobsCompleted: 127,
      responseTimeAvgMinutes: 12,
      categories: const ['Plumbing', 'Electrical', 'Painting'],
      isVerified: true,
    );

    testWidgets('renders public profile with worker info', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(WorkerPublicProfileView(profile: sampleWorker)),
      );
      await tester.pumpAndSettle();

      // App bar
      expect(find.text('Worker Profile'), findsOneWidget);

      // Worker info from the supplied profile
      expect(find.text('Ali Raza'), findsOneWidget);
      expect(find.text('Experienced Plumber & Electrician'), findsOneWidget);

      // Stats
      expect(find.textContaining('4.5'), findsOneWidget);
      expect(find.textContaining('127 jobs'), findsOneWidget);
      expect(find.textContaining('12 min'), findsOneWidget);

      // Bio
      expect(find.textContaining('home maintenance'), findsOneWidget);

      // Action buttons
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Hire'), findsOneWidget);
    });

    testWidgets('shows availability badge when worker is available', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(WorkerPublicProfileView(profile: sampleWorker)),
      );
      await tester.pumpAndSettle();

      // Availability is 'today', so the badge should show.
      expect(find.textContaining('Available: Today'), findsOneWidget);
    });

    testWidgets('shows verification status', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(WorkerPublicProfileView(profile: sampleWorker)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Verified Worker'), findsOneWidget);
      expect(find.text('Identity confirmed'), findsOneWidget);
    });
  });
}
