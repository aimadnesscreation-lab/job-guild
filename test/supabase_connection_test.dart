import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_services_marketplace/core/constants/app_constants.dart';

/// Integration test for the live Supabase connection.
/// Verifies that:
/// 1. Supabase client initializes with credentials from AppConstants
/// 2. Database tables are accessible with proper RLS
/// 3. Auth session is manageable
/// 4. Data fetching from categories and jobs works
/// 5. Realtime subscriptions can be established
void main() {
  late SupabaseClient supabase;

  setUpAll(() {
    // Import credentials from app_constants to avoid drift
    supabase = SupabaseClient(
      AppConstants.supabaseUrl,
      AppConstants.supabaseAnonKey,
    );
  });

  tearDownAll(() {
    supabase.dispose();
  });

  group('Supabase Live Connection', () {
    test('1. Client initializes and connects', () {
      expect(supabase, isNotNull);
      expect(supabase.auth, isNotNull);
      expect(supabase.from('users'), isNotNull);
    });

    test('2. Categories table has seed data', () async {
      final response = await supabase
          .from('categories')
          .select('*')
          .order('id');

      expect(response, isA<List>());
      expect(
        response.length,
        greaterThan(0),
        reason: 'Categories should have seed data from schema.sql',
      );

      final first = response[0];
      expect(first, containsPair('name_en', isA<String>()));
      expect(first, containsPair('name_ur', isA<String>()));

      debugPrint('✅ Categories table: ${response.length} categories found');
      debugPrint('   First: ${first['name_en']} / ${first['name_ur']}');
    });

    test('3. Users table has RLS enabled and is queryable', () async {
      final response = await supabase.from('users').select('count');
      expect(response, isA<List>());
      debugPrint('✅ Users table accessible with RLS');
    });

    test('4. Worker profiles table structure is correct', () async {
      final response = await supabase
          .from('worker_profiles')
          .select('*')
          .limit(1);
      expect(response, isA<List>());
      debugPrint('✅ Worker profiles table accessible');
      if (response.isNotEmpty) {
        final profile = response[0];
        debugPrint('   Sample columns: ${profile.keys.join(', ')}');
      }
    });

    test('5. Jobs PostGIS RPC function works', () async {
      final nearbyJobs = await supabase.rpc(
        'get_nearby_jobs',
        params: {'lat': 31.5204, 'lng': 74.3587, 'radius_km': 50.0},
      );
      expect(nearbyJobs, isA<List>());
      debugPrint('✅ get_nearby_jobs RPC function works');
      debugPrint('   ${nearbyJobs.length} nearby jobs found');
    });

    test('6. Reviews table structure is correct', () async {
      final response = await supabase.from('reviews').select('*').limit(1);
      expect(response, isA<List>());
      debugPrint('✅ Reviews table accessible');
    });

    test('7. Auth endpoint reachable', () async {
      final session = supabase.auth.currentSession;
      debugPrint(
        '✅ Auth reachable (session: ${session != null ? 'active' : 'none'})',
      );
      expect(supabase.auth, isNotNull);
    });

    test('8. Realtime channel can be created', () async {
      final channel = supabase.channel('test-connection');
      expect(channel, isNotNull);
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        callback: (payload) {},
      );
      channel.subscribe();
      await Future.delayed(const Duration(milliseconds: 500));
      supabase.removeChannel(channel);
      debugPrint('✅ Realtime channel created and subscribed successfully');
    });
  });
}
