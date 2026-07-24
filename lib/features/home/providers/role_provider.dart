import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';

/// The current mode the user is acting as.
/// Determines what the Home feed tab shows — job listings (worker mode)
/// or worker search (employer mode).
enum AppRole { employer, worker }

/// Notifier for the user's currently active role.
/// Reads the persisted role flags from the `users` table. Falls back to
/// `employer` if the DB query is unavailable (e.g. not signed in).
///
/// Users who have both roles can switch between them via Settings.
/// The role is persisted in local state during the session and can be
/// changed via [setRole].
class RoleNotifier extends Notifier<AppRole> {
  bool _initialized = false;

  @override
  AppRole build() {
    // Load the persisted role from the users table when the user is signed in.
    // Also listen to auth state changes so we can load the role as soon as the
    // user becomes available on cold start (when auth state arrives async).
    if (!_initialized) {
      _initialized = true;
      _loadPersistedRole();
      // Listen for user changes to handle cold-start race conditions.
      ref.listen(currentUserProvider, (_, next) {
        if (next != null) {
          _loadPersistedRole();
        }
      });
    }
    return AppRole.employer; // safe default until loaded
  }

  Future<void> _loadPersistedRole() async {
    try {
      final userId = ref.read(currentUserProvider)?.id;
      if (userId == null) return;

      final client = Supabase.instance.client;
      final response = await client
          .from('users')
          .select('is_employer, is_worker')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return;

      final isWorker = response['is_worker'] as bool? ?? false;
      final isEmployer = response['is_employer'] as bool? ?? false;
      // When both roles are enabled, prefer employer (the app default).
      // Worker-only users still get worker mode automatically.
      if (isWorker && !isEmployer) {
        state = AppRole.worker;
      }
      // Otherwise stay employer (the safe default)
    } catch (_) {
      // If the query fails (e.g. new migration not yet applied), keep default.
    }
  }

  void setRole(AppRole role) => state = role;

  void toggle() =>
      state = state == AppRole.employer ? AppRole.worker : AppRole.employer;
}

/// Provider for the user's currently active role.
final currentRoleProvider = NotifierProvider<RoleNotifier, AppRole>(
  () => RoleNotifier(),
);

/// Provider that reads which roles the user has enabled from the DB.
/// Used by Settings to show/hide the role toggle.
final userRolesProvider = FutureProvider<({bool isEmployer, bool isWorker})>((
  ref,
) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return (isEmployer: true, isWorker: false);

  try {
    final client = Supabase.instance.client;
    final response = await client
        .from('users')
        .select('is_employer, is_worker')
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return (isEmployer: true, isWorker: false);

    return (
      isEmployer: response['is_employer'] as bool? ?? true,
      isWorker: response['is_worker'] as bool? ?? false,
    );
  } catch (_) {
    return (isEmployer: true, isWorker: false);
  }
});

/// Enable or disable a role for the current user.
///
/// This is a plain async function, not a FutureProvider — it performs a
/// mutation (database write + cache invalidation), not a data read.
Future<void> updateUserRole({
  required Ref ref,
  required AppRole role,
  required bool enabled,
}) async {
  final userId = ref.read(currentUserProvider)?.id;
  if (userId == null) return;

  final client = Supabase.instance.client;
  final column = role == AppRole.employer ? 'is_employer' : 'is_worker';
  await client.from('users').update({column: enabled}).eq('id', userId);
  ref.invalidate(userRolesProvider);
}

/// Convenience: enable a role for the current user.
Future<void> enableRole(Ref ref, AppRole role) =>
    updateUserRole(ref: ref, role: role, enabled: true);

/// Convenience: disable a role for the current user.
Future<void> disableRole(Ref ref, AppRole role) =>
    updateUserRole(ref: ref, role: role, enabled: false);
