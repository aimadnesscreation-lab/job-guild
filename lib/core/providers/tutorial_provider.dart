import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the first-launch tutorial (coach marks) has been completed.
/// Persisted in SharedPreferences so it only shows once.
final tutorialCompletedProvider = NotifierProvider<TutorialNotifier, bool>(
  TutorialNotifier.new,
);

class TutorialNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    // Default to true (assume completed) to prevent the overlay from
    // briefly flashing on every launch. On first launch, _load() will
    // set state to false and the overlay appears once.
    return true;
  }

  static const _key = 'tutorial_completed';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> complete() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  Future<void> reset() async {
    state = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
