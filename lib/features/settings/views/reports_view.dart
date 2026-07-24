// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/core/services/supabase_repository.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';

/// Reports view — shows the user's submitted reports and allows submitting new ones.
class ReportsView extends ConsumerStatefulWidget {
  const ReportsView({super.key});

  @override
  ConsumerState<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends ConsumerState<ReportsView> {
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _loading = true);
    final userId = ref.read(currentUserProvider)?.id;
    final repo = ref.read(supabaseRepositoryProvider);
    if (userId != null) {
      final list = await repo.getUserReports(userId);
      if (context.mounted) {
        setState(() {
          _reports = list;
          _loading = false;
        });
      }
    } else {
      if (context.mounted) setState(() => _loading = false);
    }
  }

  void _showSubmitReportDialog() {
    final s = ref.read(appStringsProvider);
    final detailsController = TextEditingController();
    String selectedReason =
        'Spam'; // Internal value matching dropdown item values

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(ref.watch(appStringsProvider).reportUser),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: selectedReason,
                  decoration: InputDecoration(labelText: s.reportReasonLabel),
                  items: [
                    DropdownMenuItem(
                      value: 'Spam',
                      child: Text(s.reportReasonSpam),
                    ),
                    DropdownMenuItem(
                      value: 'Harassment',
                      child: Text(s.reportReasonHarassment),
                    ),
                    DropdownMenuItem(
                      value: 'Fake profile',
                      child: Text(s.reportReasonFakeProfile),
                    ),
                    DropdownMenuItem(
                      value: 'Scam',
                      child: Text(s.reportReasonScam),
                    ),
                    DropdownMenuItem(
                      value: 'Other',
                      child: Text(s.reportReasonOther),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedReason = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsController,
                  decoration: InputDecoration(
                    labelText: s.reportDetailsLabel,
                    hintText: s.reportDetailsHint,
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  maxLength: 500,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ref.watch(appStringsProvider).cancel),
            ),
            FilledButton(
              onPressed: () async {
                final userId = ref.read(currentUserProvider)?.id;
                if (userId == null) return;
                try {
                  await ref
                      .read(supabaseRepositoryProvider)
                      .submitReport(
                        reporterId: userId,
                        reason: selectedReason,
                        details: detailsController.text.trim(),
                      );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${s.reportSubmitFailed}$e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _loadReports();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ref.read(appStringsProvider).reportSubmitted),
                    backgroundColor: AppTheme.primaryColor,
                  ),
                );
              },
              child: Text(ref.watch(appStringsProvider).submit),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.reportUser),
        actions: [
          TextButton.icon(
            onPressed: _showSubmitReportDialog,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(s.newReport),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.flag_outlined,
                    size: 64,
                    color: AppTheme.textDisabled,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.noReports,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.reportsHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textDisabled,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _reports.length,
              itemBuilder: (context, index) {
                final r = _reports[index];
                final reason = r['reason'] as String? ?? '';
                final status = r['status'] as String? ?? 'open';
                final createdAt = r['created_at'] as String? ?? '';
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.flag_outlined,
                      color: AppTheme.errorColor,
                      size: 20,
                    ),
                  ),
                  title: Text(reason),
                  subtitle: Text(
                    'Status: $status\n$createdAt',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: status == 'open'
                          ? AppTheme.accentColor.withValues(alpha: 0.1)
                          : AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        color: status == 'open'
                            ? AppTheme.accentColor
                            : AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
