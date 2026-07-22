import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current mode the user is acting as.
/// Determines what the Home feed tab shows — job listings (worker mode)
/// or worker search (employer mode).
enum AppRole { employer, worker }

/// Notifier for the user's currently active role.
/// Defaults to [AppRole.employer].
class RoleNotifier extends Notifier<AppRole> {
  @override
  AppRole build() => AppRole.employer;

  void setRole(AppRole role) => state = role;

  void toggle() =>
      state = state == AppRole.employer ? AppRole.worker : AppRole.employer;
}

/// Provider for the user's currently active role.
final currentRoleProvider = NotifierProvider<RoleNotifier, AppRole>(
  () => RoleNotifier(),
);
