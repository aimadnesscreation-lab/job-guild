import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:local_services_marketplace/core/services/supabase_repository.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import 'package:local_services_marketplace/features/home/providers/role_provider.dart';
import 'package:local_services_marketplace/features/ratings/views/reviews_list_view.dart';

// ─── Mock User ────────────────────────────────────────────────────────

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

// ─── Mock Reviews ────────────────────────────────────────────────────

/// A review that was GIVEN by the test user (reviewer_id matches test-user-1).
final _givenReview = <String, dynamic>{
  'id': 'review-1',
  'job_id': 'job-1',
  'reviewer_id': 'test-user-1',
  'reviewee_id': 'worker-1',
  'rating': 5,
  'comment': 'Excellent work! Very professional and on time.',
  'created_at': '2026-07-20T10:00:00Z',
  'reviewer': {'full_name': 'Test User'},
  'reviewee': {'full_name': 'Ali Worker'},
  'jobs': {'title': 'Bathroom plumbing fix'},
};

/// A review that was RECEIVED by the test user (reviewee_id matches test-user-1).
final _receivedReview = <String, dynamic>{
  'id': 'review-2',
  'job_id': 'job-2',
  'reviewer_id': 'employer-1',
  'reviewee_id': 'test-user-1',
  'rating': 4,
  'comment': 'Good job on the electrical work.',
  'created_at': '2026-07-19T14:30:00Z',
  'reviewer': {'full_name': 'Sara Employer'},
  'reviewee': {'full_name': 'Test User'},
  'jobs': {'title': 'Wiring repair'},
};

final _mockReviews = [_givenReview, _receivedReview];

// ─── Stub Providers ──────────────────────────────────────────────────

class _TestRoleNotifier extends RoleNotifier {
  @override
  AppRole build() => AppRole.worker;
}

// ═════════════════════════════════════════════════════════════════════
//  Tests
// ═════════════════════════════════════════════════════════════════════

void main() {
  group('ReviewsListView empty state', () {
    testWidgets('shows empty state when there are no reviews', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => _mockUser),
            userReviewsListProvider.overrideWith(
              (ref) async => <Map<String, dynamic>>[],
            ),
            supabaseRepositoryProvider.overrideWith(
              (ref) => SupabaseRepository(null),
            ),
            currentRoleProvider.overrideWith(() => _TestRoleNotifier()),
          ],
          child: const MaterialApp(home: ReviewsListView()),
        ),
      );
      // Let the FutureProvider resolve
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('My Reviews'), findsOneWidget);
      expect(find.text('No reviews yet'), findsOneWidget);
      expect(
        find.text(
          'Reviews will appear after you complete jobs or hire workers.',
        ),
        findsOneWidget,
      );
    });
  });

  group('ReviewsListView review cards', () {
    testWidgets('renders review cards with given review data', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => _mockUser),
            userReviewsListProvider.overrideWith((ref) async => _mockReviews),
            supabaseRepositoryProvider.overrideWith(
              (ref) => SupabaseRepository(null),
            ),
            currentRoleProvider.overrideWith(() => _TestRoleNotifier()),
          ],
          child: const MaterialApp(home: ReviewsListView()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Tab bar labels + direction badges — both appear on the All tab
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Given'), findsWidgets); // tab label + badge
      expect(find.text('Received'), findsWidgets); // tab label + badge

      // Both reviews should appear on the "All" tab
      expect(find.text('Ali Worker'), findsOneWidget);
      expect(find.text('Sara Employer'), findsOneWidget);
      expect(find.text('For job: Bathroom plumbing fix'), findsOneWidget);
      expect(find.text('For job: Wiring repair'), findsOneWidget);
      expect(
        find.text('Excellent work! Very professional and on time.'),
        findsOneWidget,
      );
      expect(find.text('Good job on the electrical work.'), findsOneWidget);
    });
  });

  group('ReviewsListView tab filtering', () {
    testWidgets('switching to Given tab shows only given reviews', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => _mockUser),
            userReviewsListProvider.overrideWith((ref) async => _mockReviews),
            supabaseRepositoryProvider.overrideWith(
              (ref) => SupabaseRepository(null),
            ),
            currentRoleProvider.overrideWith(() => _TestRoleNotifier()),
          ],
          child: const MaterialApp(home: ReviewsListView()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Tap the "Given" tab. In Scaffold's Stack layout, the body renders
      // before the AppBar, so `.last` picks the tab label (not the badge).
      await tester.tap(find.text('Given').last);
      await tester.pumpAndSettle();

      // Only the given review should show
      expect(find.text('Ali Worker'), findsOneWidget);
      expect(find.text('For job: Bathroom plumbing fix'), findsOneWidget);
      expect(
        find.text('Excellent work! Very professional and on time.'),
        findsOneWidget,
      );

      // The received review should NOT show
      expect(find.text('Sara Employer'), findsNothing);
      expect(find.text('For job: Wiring repair'), findsNothing);
    });

    testWidgets('switching to Received tab shows only received reviews', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => _mockUser),
            userReviewsListProvider.overrideWith((ref) async => _mockReviews),
            supabaseRepositoryProvider.overrideWith(
              (ref) => SupabaseRepository(null),
            ),
            currentRoleProvider.overrideWith(() => _TestRoleNotifier()),
          ],
          child: const MaterialApp(home: ReviewsListView()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Tap the "Received" tab
      await tester.tap(find.text('Received').last);
      await tester.pumpAndSettle();

      // Only the received review should show
      expect(find.text('Sara Employer'), findsOneWidget);
      expect(find.text('For job: Wiring repair'), findsOneWidget);
      expect(find.text('Good job on the electrical work.'), findsOneWidget);

      // The given review should NOT show
      expect(find.text('Ali Worker'), findsNothing);
      expect(find.text('For job: Bathroom plumbing fix'), findsNothing);
    });

    testWidgets('shows tab-specific empty state when no reviews match', (
      WidgetTester tester,
    ) async {
      // Only given reviews exist
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => _mockUser),
            userReviewsListProvider.overrideWith((ref) async => [_givenReview]),
            supabaseRepositoryProvider.overrideWith(
              (ref) => SupabaseRepository(null),
            ),
            currentRoleProvider.overrideWith(() => _TestRoleNotifier()),
          ],
          child: const MaterialApp(home: ReviewsListView()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Switch to "Received" tab
      await tester.tap(find.text('Received').last);
      await tester.pumpAndSettle();

      // Should show "No received reviews yet"
      expect(find.text('No received reviews yet'), findsOneWidget);

      // Switch back to "Given" tab — reviews should show
      await tester.tap(find.text('Given').last);
      await tester.pumpAndSettle();

      expect(find.text('Ali Worker'), findsOneWidget);
      expect(find.text('No given reviews yet'), findsNothing);
    });

    testWidgets('shows RefreshIndicator for pull-to-refresh', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => _mockUser),
            userReviewsListProvider.overrideWith((ref) async => _mockReviews),
            supabaseRepositoryProvider.overrideWith(
              (ref) => SupabaseRepository(null),
            ),
            currentRoleProvider.overrideWith(() => _TestRoleNotifier()),
          ],
          child: const MaterialApp(home: ReviewsListView()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });
}
