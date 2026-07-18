import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:local_services_marketplace/features/auth/views/language_selection_view.dart';
import 'package:local_services_marketplace/features/home/views/home_view.dart';
import 'package:local_services_marketplace/features/worker/views/edit_worker_profile_view.dart';
import 'package:local_services_marketplace/features/worker/views/worker_public_profile_view.dart';

/// Helper to wrap a widget in MaterialApp + ProviderScope for testing
Widget createTestApp(Widget child) {
  return MaterialApp(
    home: ProviderScope(child: child),
  );
}

void main() {
  group('LanguageSelectionView', () {
    testWidgets('renders language selection cards for English and Urdu',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const LanguageSelectionView()));
      await tester.pumpAndSettle();

      expect(find.text('Local Services Marketplace'), findsOneWidget);
      expect(
        find.text(
          'Get your local jobs done by nearby professionals',
        ),
        findsOneWidget,
      );
      expect(find.text('English'), findsOneWidget);
      expect(find.text('اردو'), findsOneWidget);
    });

    testWidgets('tapping a language card shows phone number input',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const LanguageSelectionView()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your phone number'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('tapping back button returns to language selection',
        (WidgetTester tester) async {
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
    testWidgets('renders bottom navigation bar with all tabs',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const HomeView()));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Post Job'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('shows welcome card, live job feed header, and action buttons on home tab',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const HomeView()));
      // Don't pumpAndSettle — the Realtime stream will not settle without Supabase initialized
      await tester.pump();

      // Welcome card should still render
      expect(
        find.text('Welcome to Local Services Marketplace'),
        findsOneWidget,
      );
      // Live job feed header
      expect(find.text('Live Job Feed'), findsOneWidget);
      // Action buttons
      expect(find.text('Post a Job'), findsWidgets);
      expect(find.text('Find Workers'), findsOneWidget);
    });
  });

  group('EditWorkerProfileView', () {
    testWidgets('renders the edit profile screen with key sections',
        (WidgetTester tester) async {
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

      // Profile info
      expect(find.text('Ahmed Khan'), findsOneWidget);
      expect(find.text('127 jobs'), findsOneWidget);
    });

    testWidgets('shows AI bio generation button',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const EditWorkerProfileView()));
      await tester.pumpAndSettle();

      expect(find.text('Let AI write it'), findsOneWidget);
    });

    testWidgets('shows all availability options',
        (WidgetTester tester) async {
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

    testWidgets('tapping AI bio button opens bottom sheet',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const EditWorkerProfileView()));
      await tester.pumpAndSettle();

      // Tap the AI bio button
      await tester.tap(find.text('Let AI write it'));
      await tester.pumpAndSettle();

      // Bottom sheet appears
      expect(find.text('Let AI write your profile'), findsOneWidget);
      expect(find.text('Generate Bio'), findsOneWidget);
    });

    testWidgets('shows portfolio section',
        (WidgetTester tester) async {
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
    testWidgets('renders public profile with worker info',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(const WorkerPublicProfileView()),
      );
      await tester.pumpAndSettle();

      // App bar
      expect(find.text('Worker Profile'), findsOneWidget);

      // Worker info from the default provider state
      expect(find.text('Ahmed Khan'), findsOneWidget);
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

    testWidgets('shows availability badge when worker is available',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(const WorkerPublicProfileView()),
      );
      await tester.pumpAndSettle();

      // Default availability is 'Today', so badge should show
      expect(find.textContaining('Available: Today'), findsOneWidget);
    });

    testWidgets('shows verification status',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(const WorkerPublicProfileView()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Verified Worker'), findsOneWidget);
      expect(find.text('Identity confirmed'), findsOneWidget);
    });
  });
}
