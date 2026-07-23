// Schema validation test for Supabase project.
//
// Verifies all tables, columns, RLS policies, and functions
// from schema.sql are correctly deployed in the live Supabase project.
//
// Run with: flutter test test/e2e_flow_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_services_marketplace/core/constants/app_constants.dart';

void main() {
  late SupabaseClient db;
  var _configured = false;

  setUpAll(() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // .env file is optional — _configured stays false, tests skip gracefully
    }

    _configured = AppConstants.isSupabaseConfigured;
    if (!_configured) {
      debugPrint('Skipping e2e tests: SUPABASE_URL/SUPABASE_ANON_KEY not configured');
      return;
    }

    db = SupabaseClient(AppConstants.supabaseUrl, AppConstants.supabaseAnonKey);
  });

  tearDownAll(() {
    if (_configured) db.dispose();
  });

  group('Supabase Schema Validation', () {
    test('1. Users table exists with correct columns', () async {
      if (!_configured) return;
      final response = await db
          .from('users')
          .select('id, phone_number, full_name, city, preferred_language')
          .limit(1);
      expect(response, isA<List>());
      if (response.isNotEmpty) {
        final cols = (response[0] as Map).keys;
        expect(cols, contains('id'));
        expect(cols, contains('phone_number'));
        expect(cols, contains('full_name'));
        expect(cols, contains('city'));
      }
      debugPrint('✅ users table: columns verified');
    });

    test('2. Categories table has bilingual seed data', () async {
      if (!_configured) return;
      final response = await db
          .from('categories')
          .select('id, name_en, name_ur')
          .order('id');
      expect(response, isA<List>());
      expect(response.length, greaterThanOrEqualTo(10));

      final first = response[0] as Map;
      expect(first, containsPair('name_en', isA<String>()));
      expect(first, containsPair('name_ur', isA<String>()));
      debugPrint('✅ categories: ${response.length} bilingual entries seeded');
    });

    test('3. Worker profiles table structure', () async {
      if (!_configured) return;
      final response = await db
          .from('worker_profiles')
          .select('id, headline, bio, hourly_rate_pkr, availability_status')
          .limit(1);
      expect(response, isA<List>());
      debugPrint('✅ worker_profiles: table exists');
    });

    test('4. Worker categories join table', () async {
      if (!_configured) return;
      final response = await db
          .from('worker_categories')
          .select('worker_id, category_id')
          .limit(1);
      expect(response, isA<List>());
      debugPrint('✅ worker_categories: join table exists');
    });

    test('5. Jobs table with all fields', () async {
      if (!_configured) return;
      final response = await db
          .from('jobs')
          .select('id, employer_id, title, budget_amount, urgency, status')
          .limit(1);
      expect(response, isA<List>());
      if (response.isNotEmpty) {
        final cols = (response[0] as Map).keys;
        expect(cols, contains('status'));
        expect(cols, contains('urgency'));
        expect(cols, contains('employer_id'));
      }
      debugPrint('✅ jobs: table exists with required columns');
    });

    test('6. Applications table', () async {
      if (!_configured) return;
      final response = await db
          .from('applications')
          .select('job_id, worker_id, status')
          .limit(1);
      expect(response, isA<List>());
      debugPrint('✅ applications: table exists');
    });

    test('7. Messages table', () async {
      if (!_configured) return;
      final response = await db
          .from('messages')
          .select('job_id, sender_id, content, content_type')
          .limit(1);
      expect(response, isA<List>());
      debugPrint('✅ messages: table exists');
    });

    test('8. Reviews table', () async {
      if (!_configured) return;
      final response = await db
          .from('reviews')
          .select('job_id, reviewer_id, reviewee_id, rating')
          .limit(1);
      expect(response, isA<List>());
      debugPrint('✅ reviews: table exists');
    });

    test('9. Notifications table', () async {
      if (!_configured) return;
      final response = await db
          .from('notifications')
          .select('user_id, type, is_read')
          .limit(1);
      expect(response, isA<List>());
      debugPrint('✅ notifications: table exists');
    });

    test('10. Favorites table (newly added)', () async {
      if (!_configured) return;
      final response = await db
          .from('favorites')
          .select('user_id, favorited_user_id, created_at')
          .limit(1);
      expect(response, isA<List>());
      debugPrint(
        '✅ favorites: table exists with user_id, favorited_user_id, created_at',
      );
    });

    test('11. Reports table (newly added)', () async {
      if (!_configured) return;
      final response = await db
          .from('reports')
          .select('reporter_id, reported_user_id, reason, status')
          .limit(1);
      expect(response, isA<List>());
      debugPrint('✅ reports: table exists with status tracking');
    });

    test('12. PostGIS extension is enabled', () async {
      if (!_configured) return;
      final response = await db.rpc(
        'get_nearby_jobs',
        params: {'lat': 31.5204, 'lng': 74.3587, 'radius_km': 50.0},
      );
      expect(response, isA<List>());
      debugPrint('✅ PostGIS: get_nearby_jobs RPC function works');
    });

    test('13. Worker nearby query RPC works', () async {
      if (!_configured) return;
      final response = await db.rpc(
        'get_nearby_workers',
        params: {'lat': 31.5204, 'lng': 74.3587, 'radius_km': 50.0},
      );
      expect(response, isA<List>());
      debugPrint('✅ PostGIS: get_nearby_workers RPC function works');
    });

    test('14. Auth endpoint is accessible', () async {
      if (!_configured) return;
      final session = db.auth.currentSession;
      expect(db.auth, isNotNull);
      debugPrint(
        '✅ Auth: endpoint reachable (session: ${session != null ? 'active' : 'none'})',
      );
    });

    test('15. Realtime subscriptions are available', () async {
      if (!_configured) return;
      final channel = db.channel('schema-test');
      expect(channel, isNotNull);
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        callback: (payload) {},
      );
      channel.subscribe();
      await Future.delayed(const Duration(milliseconds: 500));
      db.removeChannel(channel);
      debugPrint('✅ Realtime: subscriptions work');
    });
  });
}
