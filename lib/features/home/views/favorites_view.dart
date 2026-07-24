import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/services/supabase_repository.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import 'package:local_services_marketplace/features/worker/models/worker_profile_model.dart';
import 'package:local_services_marketplace/features/worker/views/worker_public_profile_view.dart';

/// Provider that fetches the current user's favorite workers.
final favoritesListProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final repo = ref.watch(supabaseRepositoryProvider);
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return [];
  return repo.getFavorites(userId);
});

/// Favorites view — shows the user's saved/favorite workers.
class FavoritesView extends ConsumerWidget {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesListProvider);
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.savedWorkers)),
      body: favoritesAsync.when(
        data: (favorites) {
          if (favorites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.favorite_border_rounded,
                    size: 64,
                    color: AppTheme.textDisabled,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.noSavedWorkers,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.favoritesHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textDisabled,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final worker = favorites[index];
              // The getFavorites() query returns data nested under favorited_user_id
              // with worker_profiles as a sub-object.
              final Map<String, dynamic> favoritedUser =
                  (worker['favorited_user_id'] as Map<String, dynamic>?) ??
                  worker;
              final Map<String, dynamic>? wp =
                  favoritedUser['worker_profiles'] as Map<String, dynamic>?;
              final name = favoritedUser['full_name'] as String? ?? 'Worker';
              final headline = wp?['headline'] as String? ?? '';
              final workerId = favoritedUser['id'] as String? ?? '';
              final isVerified = favoritedUser['is_verified'] as bool? ?? false;
              final averageRating =
                  (wp?['average_rating'] as num?)?.toDouble() ?? 0;
              final totalJobsCompleted =
                  (wp?['total_jobs_completed'] as num?)?.toInt() ?? 0;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(name),
                subtitle: headline.isNotEmpty ? Text(headline) : null,
                trailing: IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppTheme.textDisabled,
                  ),
                  onPressed: () {
                    final userId = ref.read(currentUserProvider)?.id;
                    if (userId != null && workerId.isNotEmpty) {
                      ref
                          .read(supabaseRepositoryProvider)
                          .toggleFavorite(userId, workerId)
                          .then((_) => ref.invalidate(favoritesListProvider));
                    }
                  },
                ),
                onTap: () async {
                  // Fetch the full worker profile for a complete view.
                  final repo = ref.read(supabaseRepositoryProvider);
                  final fullProfile = await repo.getWorkerProfile(workerId);
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkerPublicProfileView(
                        profile:
                            fullProfile ??
                            WorkerProfile(
                              userId: workerId,
                              fullName: name,
                              headline: headline,
                              averageRating: averageRating,
                              totalJobsCompleted: totalJobsCompleted,
                              isVerified: isVerified,
                            ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(height: 12),
                Text(
                  '${s.error}: $err',
                  style: const TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(favoritesListProvider),
                  child: Text(s.retry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
