import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the first-launch tutorial (coach marks) has been completed.
/// Persisted in SharedPreferences so it only shows once.
final tutorialCompletedProvider = AsyncNotifierProvider<TutorialNotifier, bool>(
  TutorialNotifier.new,
);

class TutorialNotifier extends AsyncNotifier<bool> {
  static const _key = 'tutorial_completed';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    state = const AsyncValue.data(true);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    state = const AsyncValue.data(false);
  }
}
