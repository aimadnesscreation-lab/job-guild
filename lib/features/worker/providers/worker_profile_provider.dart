import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_services_marketplace/core/constants/app_constants.dart';
import 'package:local_services_marketplace/core/services/ai_service_provider.dart';
import 'package:local_services_marketplace/features/worker/models/worker_profile_model.dart';
import 'package:local_services_marketplace/features/worker/providers/worker_provider.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';

/// State holder for the worker profile editing flow.
/// Manages form fields, availability, portfolio, and AI generation state.
class WorkerProfileState {
  final WorkerProfile profile;
  final bool isSaving;
  final bool isGeneratingBio;
  final String? errorMessage;
  final String? aiSuggestionText;
  final List<String>? aiSuggestedCategories;
  final String tempBioInput; // raw user input for AI generation

  const WorkerProfileState({
    required this.profile,
    this.isSaving = false,
    this.isGeneratingBio = false,
    this.errorMessage,
    this.aiSuggestionText,
    this.aiSuggestedCategories,
    this.tempBioInput = '',
  });

  WorkerProfileState copyWith({
    WorkerProfile? profile,
    bool? isSaving,
    bool? isGeneratingBio,
    String? errorMessage,
    String? aiSuggestionText,
    List<String>? aiSuggestedCategories,
    String? tempBioInput,
    bool clearError = false,
    bool clearAiSuggestion = false,
  }) {
    return WorkerProfileState(
      profile: profile ?? this.profile,
      isSaving: isSaving ?? this.isSaving,
      isGeneratingBio: isGeneratingBio ?? this.isGeneratingBio,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      aiSuggestionText: clearAiSuggestion
          ? null
          : (aiSuggestionText ?? this.aiSuggestionText),
      aiSuggestedCategories: clearAiSuggestion
          ? null
          : (aiSuggestedCategories ?? this.aiSuggestedCategories),
      tempBioInput: tempBioInput ?? this.tempBioInput,
    );
  }
}

class WorkerProfileNotifier extends Notifier<WorkerProfileState> {
  /// The user ID for which this notifier was last seeded from the async
  /// profile provider. This prevents in-progress form edits from being
  /// overwritten when the FutureProvider re-emits after the initial load,
  /// and correctly detects account switches (where a stale profile from
  /// the previous user could otherwise be shown).
  String? _seededForUserId;

  @override
  WorkerProfileState build() {
    // Seed from the real logged-in user's profile when available.
    // myWorkerProfileProvider is a FutureProvider; ref.watch gives us its
    // current AsyncValue so we can use the resolved profile synchronously
    // (falling back to an EMPTY placeholder bound to the real user id until
    // it loads). We intentionally do NOT fabricate a name, bio, rating, or
    // "verified" badge — those must come from real data, otherwise the form
    // shows someone else's details before the user has set anything up.
    final asyncProfile = ref.watch(myWorkerProfileProvider);
    final real = asyncProfile.value;

    final currentUserId = ref.watch(currentUserProvider)?.id;
    final userId = currentUserId ?? 'user-placeholder';

    // Preserve in-progress edits across rebuilds of the watched provider.
    // Once we have a real profile (or the fallback), keep that state so
    // unsaved form changes are not silently discarded. Also detects account
    // switches: if the logged-in user changed, re-seed from the new profile.
    if (_seededForUserId != null && _seededForUserId == currentUserId) {
      return state;
    }

    _seededForUserId = currentUserId;
    return WorkerProfileState(
      profile:
          real ??
          WorkerProfile(
            userId: userId,
            // No name yet — the user hasn't set up a profile. The UI shows an
            // empty state / "Your Name" placeholder instead of fake data.
            fullName: '',
          ),
    );
  }

  // ─── Field updaters ──────────────────────────────────────────

  void updateFullName(String value) {
    state = state.copyWith(profile: state.profile.copyWith(fullName: value));
  }

  void updateHeadline(String value) {
    state = state.copyWith(profile: state.profile.copyWith(headline: value));
  }

  void updateBio(String value) {
    state = state.copyWith(profile: state.profile.copyWith(bio: value));
  }

  void updateYearsExperience(int years) {
    state = state.copyWith(
      profile: state.profile.copyWith(yearsExperience: years),
    );
  }

  void updateHourlyRate(int? rate) {
    state = state.copyWith(
      profile: state.profile.copyWith(hourlyRatePkr: rate),
    );
  }

  void updateServiceRadius(int km) {
    state = state.copyWith(
      profile: state.profile.copyWith(serviceRadiusKm: km),
    );
  }

  void updateAvailability(AvailabilityStatus status) {
    state = state.copyWith(
      profile: state.profile.copyWith(availabilityStatus: status),
    );
  }

  void toggleCategory(String category) {
    final current = state.profile.categories;
    final updated = current.contains(category)
        ? current.where((c) => c != category).toList()
        : [...current, category];
    state = state.copyWith(
      profile: state.profile.copyWith(categories: updated),
    );
  }

  void setProfilePhotoUrl(String url) {
    state = state.copyWith(
      profile: state.profile.copyWith(profilePhotoUrl: url),
    );
  }

  // ─── Portfolio ────────────────────────────────────────────────

  void addPortfolioImage(String url) {
    final updated = [...state.profile.portfolioMediaUrls, url];
    state = state.copyWith(
      profile: state.profile.copyWith(portfolioMediaUrls: updated),
    );
  }

  void removePortfolioImage(int index) {
    if (index < 0 || index >= state.profile.portfolioMediaUrls.length) return;
    final updated = List<String>.from(state.profile.portfolioMediaUrls)
      ..removeAt(index);
    state = state.copyWith(
      profile: state.profile.copyWith(portfolioMediaUrls: updated),
    );
  }

  // ─── AI Bio Generation ────────────────────────────────────────

  void setTempBioInput(String input) {
    state = state.copyWith(tempBioInput: input);
  }

  Future<void> generateAiBio() async {
    final rawInput = state.tempBioInput.trim();
    if (rawInput.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Please describe your experience first',
        clearAiSuggestion: true,
      );
      return;
    }

    state = state.copyWith(
      isGeneratingBio: true,
      errorMessage: null,
      clearAiSuggestion: true,
    );

    try {
      String generatedBio;
      List<String> suggestedCategories;

      if (AppConstants.enableAiProfileGeneration && !AppConstants.useMockAi) {
        // Real OpenRouter API call
        final aiService = ref.read(aiServiceProvider);
        final systemPrompt =
            'You are a professional profile writer for a '
            'local services marketplace in Pakistan. Write a 2-3 sentence '
            'professional bio based on the user\'s description. Keep it '
            'concise, positive, and focused on skills. Also suggest relevant '
            'service categories from this list: Plumbing, Electrical, Painting, '
            'Carpentry, Masonry, Mechanic, Bike Repair, Car Wash, Labor, '
            'Welding, Steel Fixing, Tutor, Language Teacher, Laptop Repair, '
            'Mobile Repair, Web Developer, Photographer, DJ, Cook, Cleaning, '
            'Moving, Healthcare, Beauty, Pet Care, General Labor. ';

        final result = await aiService.generateJson(
          prompt:
              'Generate a professional bio and suggest categories for '
              'someone with this experience: "$rawInput"\n\n'
              'Return JSON with format: {"bio": "...", "categories": ["..."]}',
          systemPrompt: systemPrompt,
        );
        final rawBio = result['bio'];
        final rawCategories = result['categories'];
        generatedBio = (rawBio is String && rawBio.trim().isNotEmpty)
            ? rawBio.trim()
            : _mockTextResponse(rawInput);
        suggestedCategories = (rawCategories is List)
            ? rawCategories.whereType<String>().toList()
            : _inferCategories(rawInput);
      } else {
        // Demo/mock mode
        await Future.delayed(const Duration(milliseconds: 800));
        generatedBio = _mockTextResponse(rawInput);
        suggestedCategories = _inferCategories(rawInput);
      }

      state = state.copyWith(
        isGeneratingBio: false,
        aiSuggestionText: generatedBio,
        aiSuggestedCategories: suggestedCategories,
      );
    } catch (e) {
      state = state.copyWith(
        isGeneratingBio: false,
        errorMessage: 'Failed to generate profile. Please try again.',
      );
    }
  }

  /// Mock text response for demo mode
  String _mockTextResponse(String input) {
    return 'Professional with $input. Dedicated to providing high-quality '
        'service with attention to detail and customer satisfaction. '
        'Available for projects of all sizes.';
  }

  void applyAiBioSuggestion() {
    final bio = state.aiSuggestionText;
    final categories = state.aiSuggestedCategories;
    if (bio == null) return;
    state = state.copyWith(
      profile: state.profile.copyWith(bio: bio, categories: categories),
      clearAiSuggestion: true,
    );
  }

  void dismissAiSuggestion() {
    state = state.copyWith(clearAiSuggestion: true);
  }

  // ─── Save ─────────────────────────────────────────────────────

  Future<void> saveProfile() async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final repo = ref.read(workerRepositoryProvider);
      if (repo == null) {
        state = state.copyWith(
          isSaving: false,
          errorMessage: 'Not connected. Please check your network and retry.',
        );
        return;
      }
      final userId = ref.read(currentUserProvider)?.id ?? state.profile.userId;
      final profile = userId != state.profile.userId
          ? state.profile.copyWith(userId: userId)
          : state.profile;
      await repo.updateWorkerProfile(userId, profile);
      // `full_name` lives on the `users` table, so persist it there too.
      // This is best-effort — if it fails the profile data was already saved.
      if (profile.fullName.trim().isNotEmpty) {
        try {
          await repo.updateUserName(userId, profile.fullName.trim());
        } catch (_) {
          // Name update is non-fatal.
        }
      }
      state = state.copyWith(isSaving: false);
    } catch (e) {
      // Surface the real reason (e.g. PostgREST 400 with a column/constraint
      // message) instead of a generic toast, so the failure is debuggable.
      final message = e is PostgrestException
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Could not save: $message',
      );
    }
  }

  /// Simple rule-based category inference for demo purposes.
  /// In production this is replaced by the Claude API call.
  List<String> _inferCategories(String input) {
    final lower = input.toLowerCase();
    final matched = <String>[];
    const keywordMap = {
      'plumb': 'Plumbing',
      'electr': 'Electrical',
      'paint': 'Painting',
      'carpent': 'Carpentry',
      'mason': 'Masonry',
      'mechanic': 'Mechanic',
      'bike': 'Bike Repair',
      'car wash': 'Car Wash',
      'labor': 'Labor',
      'weld': 'Welding',
      'steel': 'Steel Fixing',
      'tutor': 'Tutor',
      'teach': 'Language Teacher',
      'laptop': 'Laptop Repair',
      'mobile': 'Mobile Repair',
      'web': 'Web Developer',
      'photo': 'Photographer',
      'dj': 'DJ',
      'cook': 'Cook',
      'clean': 'Cleaning',
      'move': 'Moving',
      'health': 'Healthcare',
      'beauty': 'Beauty',
      'pet': 'Pet Care',
      'general': 'General Labor',
    };
    for (final entry in keywordMap.entries) {
      if (lower.contains(entry.key)) {
        matched.add(entry.value);
      }
    }
    return matched.take(3).toList();
  }
}

final workerProfileProvider =
    NotifierProvider<WorkerProfileNotifier, WorkerProfileState>(() {
      return WorkerProfileNotifier();
    });
