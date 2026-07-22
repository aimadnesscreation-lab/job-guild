// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/constants/app_constants.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/features/jobs/models/job_model.dart';
import 'package:local_services_marketplace/features/jobs/providers/job_provider.dart';
import 'package:local_services_marketplace/features/jobs/views/map_picker_view.dart';

/// Post a Job screen — the most important conversion flow in the app.
/// Features AI parsing: type freeform → AI fills fields → review & edit → post.
/// If an existing [job] is provided, the form is pre-populated for editing.
class PostJobView extends ConsumerStatefulWidget {
  final Job? job;

  /// When true, the provider is reset when this view is created and disposed.
  /// Use this for pushed routes so they start fresh and don't leave stale state
  /// on the bottom-nav tab instance.
  final bool resetOnInit;

  const PostJobView({super.key, this.job, this.resetOnInit = false});

  @override
  ConsumerState<PostJobView> createState() => _PostJobViewState();
}

class _PostJobViewState extends ConsumerState<PostJobView> {
  final _freeformController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = widget.job;
    if (existing != null && existing.id.isNotEmpty) {
      // If an existing job was passed (editing), pre-populate the provider
      ref.read(postJobProvider.notifier).updateTitle(existing.title);
      ref
          .read(postJobProvider.notifier)
          .updateDescription(existing.description);
      ref.read(postJobProvider.notifier).updateCategoryId(existing.categoryId);
      ref.read(postJobProvider.notifier).updateBudget(existing.budgetAmount);
      ref.read(postJobProvider.notifier).updateBudgetType(existing.budgetType);
      ref.read(postJobProvider.notifier).updateUrgency(existing.urgency);
      if (existing.scheduledFor != null) {
        ref
            .read(postJobProvider.notifier)
            .updateScheduledFor(existing.scheduledFor);
      }
      if (existing.locationText != null) {
        ref
            .read(postJobProvider.notifier)
            .updateLocation(existing.locationText!, existing.lat, existing.lng);
      }
    } else if (widget.resetOnInit) {
      // Start with a clean form so a pushed route doesn't reuse the tab's
      // stale provider state.
      ref.read(postJobProvider.notifier).resetForm();
    }
    // Listen for draft job updates to sync controllers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(postJobProvider);
      if (state.draftJob.title.isNotEmpty) {
        _titleController.text = state.draftJob.title;
      }
      if (state.draftJob.description.isNotEmpty) {
        _descriptionController.text = state.draftJob.description;
      }
      if (state.draftJob.budgetAmount != null) {
        _budgetController.text = state.draftJob.budgetAmount.toString();
      }
    });
  }

  @override
  void dispose() {
    _freeformController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    if (widget.resetOnInit) {
      ref.read(postJobProvider.notifier).resetForm();
    }
    super.dispose();
  }

  void _onParseWithAi() {
    ref.read(postJobProvider.notifier).parseWithAi();
  }

  void _onPostJob() {
    // Sync any unsaved text fields
    ref.read(postJobProvider.notifier).updateTitle(_titleController.text);
    ref
        .read(postJobProvider.notifier)
        .updateDescription(_descriptionController.text);
    final budget = int.tryParse(_budgetController.text);
    ref.read(postJobProvider.notifier).updateBudget(budget);

    ref
        .read(postJobProvider.notifier)
        .postJob()
        .then((_) {
          // Check if posting succeeded (state reset means success)
          final state = ref.read(postJobProvider);
          if (!state.isPosting && state.errorMessage == null) {
            _freeformController.clear();
            _titleController.clear();
            _descriptionController.clear();
            _budgetController.clear();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                // Use ref.read inside an async callback; ref.watch is only
                // valid during build.
                content: Text(ref.read(appStringsProvider).jobPostedSuccess),
                backgroundColor: AppTheme.primaryColor,
              ),
            );
          }
        })
        .catchError((error) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to post job: $error'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(postJobProvider);
    final hasAiResult = state.hasAiResult;

    return Scaffold(
      appBar: AppBar(title: Text(ref.watch(appStringsProvider).postJob)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Freeform AI Input ────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.accentColor.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: AppTheme.accentColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ref.watch(appStringsProvider).describeWhatYouNeed,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _freeformController,
                    decoration: InputDecoration(
                      hintText: ref.watch(appStringsProvider).aiParsingHint,
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                    maxLength: AppConstants.maxJobDescriptionLength,
                    onChanged: (val) => ref
                        .read(postJobProvider.notifier)
                        .updateFreeformText(val),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: state.isParsingWithAi ? null : _onParseWithAi,
                      icon: state.isParsingWithAi
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        state.isParsingWithAi
                            ? ref.watch(appStringsProvider).analyzing
                            : ref.watch(appStringsProvider).parseWithAi,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── AI Parsed Result ─────────────────────────────
            if (state.isParsingWithAi)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _LoadingShimmer(),
              ),

            if (hasAiResult) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.primaryColor,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ref.watch(appStringsProvider).aiParsed,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ─── Title ────────────────────────────────────────
            _SectionHeader(
              title: ref.watch(appStringsProvider).jobTitle,
              icon: Icons.title_rounded,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: ref.watch(appStringsProvider).shortTitleHint,
                ),
                maxLength: AppConstants.maxJobTitleLength,
                onChanged: (val) =>
                    ref.read(postJobProvider.notifier).updateTitle(val),
              ),
            ),
            const SizedBox(height: 12),

            // ─── Description ──────────────────────────────────
            _SectionHeader(
              title: ref.watch(appStringsProvider).description,
              icon: Icons.description_outlined,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  hintText: ref.watch(appStringsProvider).describeWhatNeedsDone,
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                maxLength: AppConstants.maxJobDescriptionLength,
                onChanged: (val) =>
                    ref.read(postJobProvider.notifier).updateDescription(val),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Category ─────────────────────────────────────
            _SectionHeader(
              title: ref.watch(appStringsProvider).category,
              icon: Icons.category_rounded,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _CategorySelector(
                selectedCategoryId: state.draftJob.categoryId,
                aiSuggestedCategory: hasAiResult
                    ? state.parsedResult!.category
                    : null,
                onChanged: (id) =>
                    ref.read(postJobProvider.notifier).updateCategoryId(id),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Budget ───────────────────────────────────────
            _SectionHeader(
              title: ref.watch(appStringsProvider).budget,
              icon: Icons.monetization_on_outlined,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _budgetController,
                      decoration: InputDecoration(
                        labelText: ref.watch(appStringsProvider).amount,
                        prefixText: 'Rs. ',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        final amount = int.tryParse(val);
                        ref.read(postJobProvider.notifier).updateBudget(amount);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BudgetTypeSelector(
                      currentType: state.draftJob.budgetType,
                      onChanged: (type) => ref
                          .read(postJobProvider.notifier)
                          .updateBudgetType(type),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── Urgency & Scheduling ─────────────────────────
            _SectionHeader(
              title: ref.watch(appStringsProvider).whenLabel,
              icon: Icons.schedule_rounded,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _UrgencySelector(
                    currentUrgency: state.draftJob.urgency,
                    onChanged: (u) =>
                        ref.read(postJobProvider.notifier).updateUrgency(u),
                  ),
                  if (state.draftJob.urgency == Urgency.scheduled)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(
                              const Duration(days: 1),
                            ),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 90),
                            ),
                          );
                          if (date != null) {
                            ref
                                .read(postJobProvider.notifier)
                                .updateScheduledFor(date);
                          }
                        },
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text(
                          state.draftJob.scheduledFor != null
                              ? 'Scheduled: ${state.draftJob.scheduledFor!.toLocal().toString().split(' ')[0]}'
                              : 'Pick a Date',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── Location ─────────────────────────────────────
            _SectionHeader(
              title: ref.watch(appStringsProvider).location,
              icon: Icons.location_on_outlined,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(
                    Icons.location_on_rounded,
                    color: AppTheme.primaryColor,
                  ),
                  title: Text(
                    state.draftJob.locationText ??
                        ref.watch(appStringsProvider).yourCurrentLocation,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    '${state.draftJob.lat.toStringAsFixed(4)}, '
                    '${state.draftJob.lng.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.edit_location_alt_rounded),
                  onTap: () async {
                    final result = await Navigator.push<MapPickerResult>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MapPickerView(
                          initialLatitude: state.draftJob.lat,
                          initialLongitude: state.draftJob.lng,
                        ),
                      ),
                    );
                    if (result != null && context.mounted) {
                      ref
                          .read(postJobProvider.notifier)
                          .updateLocation(
                            result.address,
                            result.latitude,
                            result.longitude,
                          );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ─── AI Parse Result Summary ──────────────────────
            if (hasAiResult) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: AppTheme.accentColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            ref.watch(appStringsProvider).aiSuggestion,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _AiSuggestionRow(
                        label: ref.watch(appStringsProvider).category,
                        value: state.parsedResult!.category,
                      ),
                      _AiSuggestionRow(
                        label: ref.watch(appStringsProvider).urgency,
                        value: state.parsedResult!.urgency,
                      ),
                      _AiSuggestionRow(
                        label: ref.watch(appStringsProvider).budget,
                        value: 'PKR ${state.parsedResult!.suggestedBudgetPkr}',
                      ),
                      _AiSuggestionRow(
                        label: ref.watch(appStringsProvider).duration,
                        value:
                            '~${state.parsedResult!.estimatedDurationHours} ${ref.watch(appStringsProvider).hoursAbbrev}',
                      ),
                      if (state.parsedResult!.requiredSkills.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: state.parsedResult!.requiredSkills
                                .map(
                                  (s) => Chip(
                                    label: Text(
                                      s,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    backgroundColor: AppTheme.primaryColor
                                        .withValues(alpha: 0.1),
                                    side: BorderSide.none,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ─── Error Message ────────────────────────────────
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppTheme.errorColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: const TextStyle(color: AppTheme.errorColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // ─── Post Button ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: state.isPosting ? null : _onPostJob,
                  icon: state.isPosting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    state.isPosting
                        ? ref.watch(appStringsProvider).posting
                        : ref.watch(appStringsProvider).postJob,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _CategorySelector extends StatelessWidget {
  final int selectedCategoryId;
  final String? aiSuggestedCategory;
  final ValueChanged<int> onChanged;

  const _CategorySelector({
    required this.selectedCategoryId,
    this.aiSuggestedCategory,
    required this.onChanged,
  });

  static const _categories = [
    ('Plumbing', 13),
    ('Electrical', 14),
    ('Painting', 15),
    ('Carpentry', 16),
    ('Masonry', 17),
    ('Mechanic', 18),
    ('Cleaning', 7),
    ('Tutor', 24),
    ('Moving', 8),
    ('Cook', 31),
    ('Photographer', 29),
    ('General Labor', 12),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _categories.map((cat) {
        final isSelected = selectedCategoryId == cat.$2;
        final isAiSuggested = aiSuggestedCategory == cat.$1;
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(cat.$1),
              if (isAiSuggested && !isSelected) ...[
                const SizedBox(width: 4),
                Icon(Icons.auto_awesome, size: 12, color: AppTheme.accentColor),
              ],
            ],
          ),
          selected: isSelected,
          selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
          onSelected: (_) => onChanged(cat.$2),
          side: BorderSide(
            color: isAiSuggested && !isSelected
                ? AppTheme.accentColor
                : isSelected
                ? AppTheme.primaryColor
                : AppTheme.borderColor,
          ),
        );
      }).toList(),
    );
  }
}

class _BudgetTypeSelector extends ConsumerWidget {
  final BudgetType currentType;
  final ValueChanged<BudgetType> onChanged;

  const _BudgetTypeSelector({
    required this.currentType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<BudgetType>(
      segments: [
        ButtonSegment(
          value: BudgetType.fixed,
          label: Text(ref.watch(appStringsProvider).budgetTypeFixed),
        ),
        ButtonSegment(
          value: BudgetType.hourly,
          label: Text(ref.watch(appStringsProvider).budgetTypeHourly),
        ),
        ButtonSegment(
          value: BudgetType.negotiable,
          label: Text(ref.watch(appStringsProvider).budgetTypeFlex),
        ),
      ],
      selected: {currentType},
      onSelectionChanged: (selected) => onChanged(selected.first),
    );
  }
}

class _UrgencySelector extends ConsumerWidget {
  final Urgency currentUrgency;
  final ValueChanged<Urgency> onChanged;

  const _UrgencySelector({
    required this.currentUrgency,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _UrgencyCard(
            icon: Icons.electric_bolt_rounded,
            title: ref.watch(appStringsProvider).instant,
            subtitle: ref.watch(appStringsProvider).asap,
            color: AppTheme.accentColor,
            isSelected: currentUrgency == Urgency.instant,
            onTap: () => onChanged(Urgency.instant),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _UrgencyCard(
            icon: Icons.today_rounded,
            title: ref.watch(appStringsProvider).todayStr,
            subtitle: ref.watch(appStringsProvider).sameDay,
            color: AppTheme.primaryColor,
            isSelected: currentUrgency == Urgency.today,
            onTap: () => onChanged(Urgency.today),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _UrgencyCard(
            icon: Icons.calendar_today_rounded,
            title: ref.watch(appStringsProvider).scheduleLabel,
            subtitle: ref.watch(appStringsProvider).pickDateLabel,
            color: AppTheme.verifiedBadge,
            isSelected: currentUrgency == Urgency.scheduled,
            onTap: () => onChanged(Urgency.scheduled),
          ),
        ),
      ],
    );
  }
}

class _UrgencyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _UrgencyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppTheme.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? color : AppTheme.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : AppTheme.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiSuggestionRow extends StatelessWidget {
  final String label;
  final String value;

  const _AiSuggestionRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Simple shimmer loading effect while AI parses
class _LoadingShimmer extends ConsumerWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(
                ref.watch(appStringsProvider).aiIsAnalyzing,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
