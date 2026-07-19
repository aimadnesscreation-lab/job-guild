import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_services_marketplace/core/constants/app_constants.dart';
import 'package:local_services_marketplace/core/services/ai_service_provider.dart';
import 'package:local_services_marketplace/features/jobs/models/job_model.dart';
import 'package:local_services_marketplace/core/services/supabase_repository.dart';

final nearbyJobsProvider = FutureProvider<List<Job>>((ref) async {
  final repo = ref.watch(supabaseRepositoryProvider);
  return repo.getNearbyJobs();
});

/// State for the job posting form
class PostJobState {
  final String freeformText;
  final bool isParsingWithAi;
  final JobAiMetadata? parsedResult;
  final Job draftJob;
  final bool isPosting;
  final String? errorMessage;

  PostJobState({
    this.freeformText = '',
    this.isParsingWithAi = false,
    this.parsedResult,
    Job? draftJob,
    this.isPosting = false,
    this.errorMessage,
  }) : draftJob = draftJob ?? Job();

  PostJobState copyWith({
    String? freeformText,
    bool? isParsingWithAi,
    JobAiMetadata? parsedResult,
    Job? draftJob,
    bool? isPosting,
    String? errorMessage,
    bool clearError = false,
    bool clearParseResult = false,
  }) {
    return PostJobState(
      freeformText: freeformText ?? this.freeformText,
      isParsingWithAi: isParsingWithAi ?? this.isParsingWithAi,
      parsedResult:
          clearParseResult ? null : (parsedResult ?? this.parsedResult),
      draftJob: draftJob ?? this.draftJob,
      isPosting: isPosting ?? this.isPosting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  bool get hasAiResult => parsedResult != null;
}

class PostJobNotifier extends Notifier<PostJobState> {
  @override
  PostJobState build() => PostJobState();

  // ─── Freeform text ──────────────────────────────────────────

  void updateFreeformText(String text) {
    state = state.copyWith(
      freeformText: text,
      clearParseResult: true,
    );
  }

  // ─── AI Job Parsing ─────────────────────────────────────────

  /// Call the bright-api Edge Function to parse the job description.
  /// Falls back to the direct OpenRouter service (client-side) if the
  /// Edge Function is unavailable, and to keyword-based mock as last resort.
  Future<Map<String, dynamic>> _callEdgeFunction(String text) async {
    final client = Supabase.instance.client;
    final response = await client.functions.invoke(
      'bright-api',
      body: {'description': text},
    );
    // The response data is already a Map<String, dynamic>
    return response.data as Map<String, dynamic>;
  }

  Future<void> parseWithAi() async {
    final text = state.freeformText.trim();
    if (text.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Please describe what you need first',
      );
      return;
    }

    state = state.copyWith(
      isParsingWithAi: true,
      errorMessage: null,
      clearParseResult: true,
    );

    try {
      JobAiMetadata metadata;

      if (!AppConstants.useMockAi &&
          AppConstants.enableAiJobParsing) {
        try {
          // Try Edge Function first (server-side, API key protected)
          final result = await _callEdgeFunction(text);
          metadata = JobAiMetadata.fromJson(result);
        } catch (edgeError) {
          print('[AI] Edge Function failed: $edgeError');
          if (!AppConstants.isOpenRouterConfigured) {
            print('[AI] No client OpenRouter key configured — using keyword mock');
            metadata = _mockParse(text);
          } else {
            try {
              // Fall back to direct OpenRouter call from client
              final aiService = ref.read(aiServiceProvider);
              final result = await aiService.generateJson(
                prompt: 'Parse this job request: "$text"\n\n'
                    'Return JSON with exactly: {\n'
                    '  "category": string,\n'
                    '  "urgency": "instant"|"today"|"scheduled",\n'
                    '  "suggested_budget_pkr": number,\n'
                    '  "estimated_duration_hours": number,\n'
                    '  "required_skills": string[]\n'
                    '}',
              );
              metadata = JobAiMetadata.fromJson(result);
            } catch (directError) {
              print('[AI] Direct API also failed: $directError — using keyword mock');
              // Last resort: keyword-based mock
              metadata = _mockParse(text);
            }
          }
        }
      } else {
        // Mock parsing
        await Future.delayed(const Duration(milliseconds: 600));
        metadata = _mockParse(text);
      }

      final categoryId = categoryNameToId[metadata.category] ?? 12;
      final urgency = _parseUrgency(metadata.urgency);

      state = state.copyWith(
        isParsingWithAi: false,
        parsedResult: metadata,
        draftJob: state.draftJob.copyWith(
          title: _generateTitle(text),
          description: text,
          categoryId: categoryId,
          aiExtractedMetadata: metadata,
          budgetAmount: metadata.suggestedBudgetPkr > 0
              ? metadata.suggestedBudgetPkr
              : null,
          urgency: urgency,
        ),
      );
    } catch (e) {
      state = state.copyWith(
        isParsingWithAi: false,
        errorMessage: 'Failed to parse your request. Please fill in the fields manually.',
      );
    }
  }

  // ─── Manual field edits (after AI parsing) ──────────────────

  void updateTitle(String title) {
    state = state.copyWith(
      draftJob: state.draftJob.copyWith(title: title),
    );
  }

  void updateDescription(String desc) {
    state = state.copyWith(
      draftJob: state.draftJob.copyWith(description: desc),
    );
  }

  void updateBudget(int? amount) {
    state = state.copyWith(
      draftJob: state.draftJob.copyWith(budgetAmount: amount),
    );
  }

  void updateBudgetType(BudgetType type) {
    state = state.copyWith(
      draftJob: state.draftJob.copyWith(budgetType: type),
    );
  }

  void updateUrgency(Urgency urgency) {
    state = state.copyWith(
      draftJob: state.draftJob.copyWith(urgency: urgency),
    );
  }

  void updateCategoryId(int id) {
    state = state.copyWith(
      draftJob: state.draftJob.copyWith(categoryId: id),
    );
  }

  void updateLocation(String text, double lat, double lng) {
    state = state.copyWith(
      draftJob: state.draftJob.copyWith(
        locationText: text,
        lat: lat,
        lng: lng,
      ),
    );
  }

  void updateScheduledFor(DateTime? date) {
    state = state.copyWith(
      draftJob: state.draftJob.copyWith(scheduledFor: date),
    );
  }

  // ─── Post job ───────────────────────────────────────────────

  Future<void> postJob() async {
    final job = state.draftJob;
    if (job.title.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Please enter a job title',
      );
      return;
    }

    state = state.copyWith(isPosting: true, errorMessage: null);

    try {
      final repo = ref.read(supabaseRepositoryProvider);
      await repo.postJob(job);

      // Reset form on success
      state = PostJobState();
    } catch (e) {
      state = state.copyWith(
        isPosting: false,
        errorMessage: 'Failed to post job. Please try again.',
      );
    }
  }

  // ─── Helpers ────────────────────────────────────────────────

  String _generateTitle(String text) {
    // Take first sentence or first 60 chars as title
    final firstSentence = text.split(RegExp(r'[.!?\n]')).first.trim();
    if (firstSentence.length <= 60) return firstSentence;
    return '${firstSentence.substring(0, 57)}...';
  }

  Urgency _parseUrgency(String u) {
    switch (u.toLowerCase()) {
      case 'instant':
        return Urgency.instant;
      case 'scheduled':
        return Urgency.scheduled;
      default:
        return Urgency.today;
    }
  }

  JobAiMetadata _mockParse(String text) {
    final lower = text.toLowerCase();
    String category = 'General Labor';
    if (lower.contains('plumb')) category = 'Plumbing';
    else if (lower.contains('electr')) category = 'Electrical';
    else if (lower.contains('paint')) category = 'Painting';
    else if (lower.contains('carpent')) category = 'Carpentry';
    else if (lower.contains('clean')) category = 'Cleaning';
    else if (lower.contains('tutor') || lower.contains('teach')) category = 'Tutor';
    else if (lower.contains('mechanic')) category = 'Mechanic';
    else if (lower.contains('cook') || lower.contains('food')) category = 'Cook';
    else if (lower.contains('move') || lower.contains('shift')) category = 'Moving';
    else if (lower.contains('photo')) category = 'Photographer';
    else if (lower.contains('laptop') || lower.contains('computer')) category = 'Laptop Repair';
    else if (lower.contains('mobile') || lower.contains('phone')) category = 'Mobile Repair';
    else if (lower.contains('web') || lower.contains('website')) category = 'Web Developer';

    final urgency = lower.contains('urgent') || lower.contains('emergency') || lower.contains('asap')
        ? 'instant'
        : lower.contains('next') || lower.contains('tomorrow') || lower.contains('schedule')
            ? 'scheduled'
            : 'today';

    int budget = 2000;
    final budgetMatch = RegExp(r'(\d+)\s*(k|rs|pkr)?').firstMatch(lower);
    if (budgetMatch != null) {
      final num = int.parse(budgetMatch.group(1)!);
      final suffix = budgetMatch.group(2) ?? '';
      budget = suffix == 'k' ? num * 1000 : num;
    }

    return JobAiMetadata(
      category: category,
      urgency: urgency,
      suggestedBudgetPkr: budget,
      estimatedDurationHours: lower.contains('hour') || lower.contains('hr') ? 1 : 2,
      requiredSkills: [category],
    );
  }
}

final postJobProvider =
    NotifierProvider<PostJobNotifier, PostJobState>(() => PostJobNotifier());
