// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_services_marketplace/core/services/supabase_repository.dart';
import 'package:local_services_marketplace/core/utils/responsive.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/core/utils/location_utils.dart';
import 'package:local_services_marketplace/features/jobs/models/job_model.dart';
import 'package:local_services_marketplace/features/jobs/views/job_detail_worker_view.dart';
import 'package:local_services_marketplace/features/auth/providers/auth_provider.dart';
import 'package:local_services_marketplace/features/chat/providers/voice_recorder_provider.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';
import 'package:local_services_marketplace/features/chat/models/message_model.dart';
import 'package:local_services_marketplace/features/chat/providers/chat_provider.dart';

/// WhatsApp-style individual chat view with messages, text input, and typing indicator.
class ChatDetailView extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String jobTitle;

  const ChatDetailView({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    required this.jobTitle,
  });

  @override
  ConsumerState<ChatDetailView> createState() => _ChatDetailViewState();
}

class _ChatDetailViewState extends ConsumerState<ChatDetailView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).loadConversation(widget.conversationId);
    });
  }

  @override
  void dispose() {
    ref.read(chatProvider.notifier).disposeChannel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;

    _messageController.clear();
    await ref.read(chatProvider.notifier).sendMessage(text);

    // Scroll to bottom AFTER the new message has been laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Pick and send an image from gallery or camera
  Future<void> _sendImageFromSource(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (picked == null) return;

      // Upload to Supabase Storage
      final fileName = 'chat_${DateTime.now().millisecondsSinceEpoch}.jpg';
      const bucket = 'chat_images';

      // Ensure bucket exists (best-effort)
      try {
        await Supabase.instance.client.storage.createBucket(bucket);
      } catch (_) {}

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await Supabase.instance.client.storage
            .from(bucket)
            .uploadBinary(fileName, bytes);
      } else {
        await Supabase.instance.client.storage
            .from(bucket)
            .upload(fileName, File(picked.path));
      }

      final publicUrl = Supabase.instance.client.storage
          .from(bucket)
          .getPublicUrl(fileName);

      // Send as image message
      await ref.read(chatProvider.notifier).sendImage(publicUrl);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send image: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  /// Show the voice recording sheet with real recording functionality
  void _showVoiceRecordingSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _VoiceRecorderSheet(
          conversationId: widget.conversationId,
          onClose: () => Navigator.pop(sheetContext),
        );
      },
    );
  }

  /// Share current location as a message using actual GPS position
  Future<void> _shareCurrentLocation() async {
    try {
      // Get actual current location with graceful fallback
      final (lat, lng) = await LocationUtils.getCurrentLatLng();
      final locationText =
          '📍 Current location: https://maps.google.com/?q=$lat,$lng';
      await ref.read(chatProvider.notifier).sendMessage(locationText);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location shared'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share location: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              child: Text(
                widget.otherUserName.isNotEmpty
                    ? widget.otherUserName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.jobTitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textDisabled,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_outlined, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Voice calling — coming soon'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            onPressed: () => _showOptions(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Messages ──────────────────────────────────────
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ReadableContainer(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: state.currentMessages.length,
                      itemBuilder: (context, index) {
                        final msg = state.currentMessages[index];
                        final currentUserId = ref
                            .watch(currentUserProvider)
                            ?.id;
                        final isMine = msg.senderId == currentUserId;
                        return _MessageBubble(message: msg, isMine: isMine);
                      },
                    ),
                  ),
          ),

          // ─── Typing indicator ──────────────────────────────
          if (state.isTyping)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.otherUserName} ${ref.watch(appStringsProvider).isTyping}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          // ─── Input bar ─────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              8,
              6,
              8,
              6 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: ReadableContainer(
              child: Row(
                children: [
                  // Attach button
                  IconButton(
                    icon: const Icon(
                      Icons.attach_file_rounded,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () => _showAttachmentOptions(context),
                  ),
                  // Text field
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: ref.watch(appStringsProvider).typeAMessage,
                        filled: true,
                        fillColor: AppTheme.surfaceColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onChanged: (val) {
                        ref
                            .read(chatProvider.notifier)
                            .setTyping(val.isNotEmpty);
                      },
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Send button
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primaryColor,
                    child: IconButton(
                      icon: const Icon(
                        Icons.send_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      onPressed: state.isSending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(ref.watch(appStringsProvider).reportUser),
              onTap: () {
                Navigator.pop(ctx);
                _reportUser(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: Text(ref.watch(appStringsProvider).blockUser),
              onTap: () {
                Navigator.pop(ctx);
                _blockUser(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.work_outline),
              title: Text(ref.watch(appStringsProvider).viewJobDetails),
              onTap: () {
                Navigator.pop(ctx);
                // Use the conversationId (which is the job_id) to navigate
                // to the worker-safe job detail view with a minimal job.
                // We fall back to the worker view since it doesn't show
                // employer-only controls (hire buttons, etc.) when the
                // job data is incomplete.
                final job = Job(
                  id: widget.conversationId,
                  title: widget.jobTitle,
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JobDetailWorkerView(job: job),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Opens a dialog to submit a report against the other user.
  void _reportUser(BuildContext context) async {
    final reasonController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ref.read(appStringsProvider).reportUser),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Describe the issue...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.read(appStringsProvider).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (result == null || result.trim().isEmpty) return;

    try {
      final repo = ref.read(supabaseRepositoryProvider);
      final currentUserId = ref.read(currentUserProvider)?.id;
      await repo.submitReport(
        reporterId: currentUserId ?? '',
        reportedUserId: _otherUserId,
        jobId: widget.conversationId,
        reason: result.trim(),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted. Thank you.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  /// Block the other user — persists to a local block list.
  void _blockUser(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final blockedKey = 'blocked_users';
      final blockedJson = prefs.getString(blockedKey);
      final blockedUsers = blockedJson != null
          ? List<String>.from(jsonDecode(blockedJson) as List)
          : <String>[];
      final otherId = _otherUserId;
      if (otherId.isEmpty || blockedUsers.contains(otherId)) return;
      blockedUsers.add(otherId);
      await prefs.setString(blockedKey, jsonEncode(blockedUsers));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User blocked. You will no longer receive messages from them.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to block user: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  /// The user ID of the person on the other side of this conversation.
  String get _otherUserId {
    final state = ref.read(chatProvider);
    final conv = state.conversations
        .where((c) => c.id == widget.conversationId)
        .firstOrNull;
    return conv?.otherUserId ?? '';
  }

  void _showAttachmentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AttachmentButton(
                icon: Icons.image_rounded,
                label: ref.watch(appStringsProvider).gallery,
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(ctx);
                  _sendImageFromSource(ImageSource.gallery);
                },
              ),
              _AttachmentButton(
                icon: Icons.camera_alt_rounded,
                label: ref.watch(appStringsProvider).camera,
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(ctx);
                  _sendImageFromSource(ImageSource.camera);
                },
              ),
              _AttachmentButton(
                icon: Icons.mic_rounded,
                label: ref.watch(appStringsProvider).voice,
                color: AppTheme.accentColor,
                onTap: () {
                  Navigator.pop(ctx);
                  _showVoiceRecordingSheet(context);
                },
              ),
              _AttachmentButton(
                icon: Icons.location_on_rounded,
                label: ref.watch(appStringsProvider).location,
                color: AppTheme.primaryColor,
                onTap: () {
                  Navigator.pop(ctx);
                  _shareCurrentLocation();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Message Bubble ──────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${message.sentAt.hour.toString().padLeft(2, '0')}:${message.sentAt.minute.toString().padLeft(2, '0')}';

    // Render voice message differently with playback controls
    if (message.contentType == MessageContentType.voice &&
        message.content.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: isMine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    message.senderName.isNotEmpty
                        ? message.senderName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: isMine
                      ? AppTheme.primaryColor.withValues(alpha: 0.12)
                      : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMine ? 16 : 4),
                    bottomRight: Radius.circular(isMine ? 4 : 16),
                  ),
                  border: Border.all(
                    color: isMine
                        ? AppTheme.primaryColor.withValues(alpha: 0.2)
                        : AppTheme.borderColor,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _VoiceMessageWidget(url: message.content, isMine: isMine),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 10,
                            color: isMine
                                ? AppTheme.textSecondary
                                : AppTheme.textDisabled,
                          ),
                        ),
                        if (isMine) ...[
                          const SizedBox(width: 3),
                          Icon(
                            message.isRead
                                ? Icons.done_all_rounded
                                : Icons.done_rounded,
                            size: 14,
                            color: message.isRead
                                ? AppTheme.verifiedBadge
                                : AppTheme.textDisabled,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for others
          if (!isMine)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Text(
                  message.senderName.isNotEmpty
                      ? message.senderName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // Bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMine
                    ? AppTheme.primaryColor.withValues(alpha: 0.12)
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
                border: Border.all(
                  color: isMine
                      ? AppTheme.primaryColor.withValues(alpha: 0.2)
                      : AppTheme.borderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 15,
                      color: isMine
                          ? AppTheme.textPrimary
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMine
                              ? AppTheme.textSecondary
                              : AppTheme.textDisabled,
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 3),
                        Icon(
                          message.isRead
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 14,
                          color: message.isRead
                              ? AppTheme.verifiedBadge
                              : AppTheme.textDisabled,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Voice Recording Sheet ─────────────────────────────────────────────

/// Bottom sheet for recording voice messages with real recording via [record] package.
class _VoiceRecorderSheet extends ConsumerStatefulWidget {
  final String conversationId;
  final VoidCallback onClose;

  const _VoiceRecorderSheet({
    required this.conversationId,
    required this.onClose,
  });

  @override
  ConsumerState<_VoiceRecorderSheet> createState() =>
      _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends ConsumerState<_VoiceRecorderSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _recordingStarted = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    await ref.read(voiceRecorderProvider.notifier).startRecording();
    if (!mounted) return;
    _pulseController.repeat(reverse: true);
  }

  Future<void> _stopAndSend() async {
    _pulseController.stop();
    _pulseController.reset();

    final notifier = ref.read(voiceRecorderProvider.notifier);
    await notifier.stopRecording();

    // Upload and send
    final url = await notifier.uploadAudio(widget.conversationId);
    if (url != null) {
      // Send as a voice message via the chat provider with proper content_type
      await ref.read(chatProvider.notifier).sendVoice(url);
    }
    widget.onClose();
  }

  Future<void> _cancel() async {
    _pulseController.stop();
    _pulseController.reset();
    await ref.read(voiceRecorderProvider.notifier).cancelRecording();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceRecorderProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Recording indicator
          if (voiceState.isRecording) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) => Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(
                        alpha: 0.5 + (_pulseController.value * 0.5),
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  voiceState.durationDisplay,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w300,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Recording...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ] else ...[
            const Icon(
              Icons.mic_rounded,
              size: 64,
              color: AppTheme.accentColor,
            ),
            const SizedBox(height: 12),
            const Text(
              'Tap and hold to record',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const Text(
              'Release to send',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],

          const SizedBox(height: 24),

          // Error message
          if (voiceState.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                voiceState.error!,
                style: const TextStyle(
                  color: AppTheme.errorColor,
                  fontSize: 13,
                ),
              ),
            ),

          // Recording button
          //
          // Uses onLongPressStart/End/Cancel — matching the "Tap and hold to
          // record, release to send" UX described in the UI. This avoids the
          // race condition that onTapDown+onTapUp creates (where a quick tap
          // fires stop before startRecording's async setup completes).
          GestureDetector(
            onLongPressStart: (_) async {
              // Set the flag BEFORE awaiting so onLongPressEnd can observe
              // even on quick releases.
              _recordingStarted = true;
              try {
                await _startRecording();
              } catch (_) {
                if (mounted) _recordingStarted = false;
              }
            },
            onLongPressEnd: (_) async {
              if (!mounted) return;
              if (_recordingStarted) {
                _recordingStarted = false;
                await _stopAndSend();
              }
            },
            onLongPressCancel: () async {
              if (!mounted) return;
              if (_recordingStarted) {
                _recordingStarted = false;
                await _cancel();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: voiceState.isRecording ? 64 : 72,
              height: voiceState.isRecording ? 64 : 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: voiceState.isRecording
                    ? AppTheme.errorColor
                    : AppTheme.accentColor,
                boxShadow: [
                  BoxShadow(
                    color:
                        (voiceState.isRecording
                                ? AppTheme.errorColor
                                : AppTheme.accentColor)
                            .withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                voiceState.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: voiceState.isRecording ? 28 : 32,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Cancel button
          TextButton(
            onPressed: _cancel,
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),

          // Sending indicator
          if (voiceState.isSending)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Sending voice message...',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Voice message widget with real audio playback via [audioplayers].
class _VoiceMessageWidget extends StatefulWidget {
  final String url;
  final bool isMine;

  const _VoiceMessageWidget({required this.url, required this.isMine});

  @override
  State<_VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<_VoiceMessageWidget> {
  late final AudioPlayer _player;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _stateSub;
  Timer? _waveformTick;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    // Listen to position updates (~200ms on most platforms)
    _positionSub = _player.onPositionChanged.listen((pos) {
      if (context.mounted) setState(() => _position = pos);
    });

    // Listen to duration
    _durationSub = _player.onDurationChanged.listen((dur) {
      if (context.mounted) setState(() => _duration = dur);
    });

    // Listen to state changes
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!context.mounted) return;
      setState(() => _playerState = state);
      if (state == PlayerState.playing) {
        _startWaveformTick();
      } else {
        _stopWaveformTick();
      }
    });

    // Set source with error handling for expired/invalid URLs.
    // Can't await in initState, so we handle errors via the state listener.
    _player.setSourceUrl(widget.url).catchError((_) {
      if (mounted) setState(() => _playerState = PlayerState.stopped);
    });
  }

  @override
  void dispose() {
    _stopWaveformTick();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  // Timer to drive waveform animation tick during playback
  void _startWaveformTick() {
    _waveformTick?.cancel();
    _waveformTick = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (context.mounted) setState(() {});
    });
  }

  void _stopWaveformTick() {
    _waveformTick?.cancel();
    _waveformTick = null;
  }

  void _togglePlayback() async {
    try {
      if (_playerState == PlayerState.playing) {
        await _player.pause();
      } else if (_playerState == PlayerState.paused) {
        await _player.resume();
      } else {
        // Stopped or completed — play from start
        await _player.stop();
        await _player.seek(Duration.zero);
        await _player.resume();
      }
    } catch (_) {
      if (context.mounted) setState(() => _playerState = PlayerState.stopped);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get _displayTime {
    if (_playerState == PlayerState.playing ||
        _playerState == PlayerState.paused) {
      return _formatDuration(_position);
    }
    if (_duration > Duration.zero) {
      return _formatDuration(_duration);
    }
    return '00:00';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;

    return GestureDetector(
      onTap: _togglePlayback,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: widget.isMine
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 20,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            // Waveform with playback progress
            SizedBox(
              width: 80,
              height: 20,
              child: CustomPaint(
                size: const Size(80, 20),
                painter: _WaveformPainter(
                  color: widget.isMine
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                  isPlaying: isPlaying,
                  progress: _duration.inMilliseconds > 0
                      ? _position.inMilliseconds / _duration.inMilliseconds
                      : 0.0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _displayTime,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Waveform visualizer with playback progress indication.
class _WaveformPainter extends CustomPainter {
  final Color color;
  final bool isPlaying;
  final double progress; // 0.0 - 1.0

  _WaveformPainter({
    required this.color,
    required this.isPlaying,
    this.progress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = 12;
    final barWidth = size.width / (barCount * 2);
    final midY = size.height / 2;
    final progressX = size.width * progress;

    for (int i = 0; i < barCount; i++) {
      final x = barWidth * 2 * i + barWidth / 2;
      final height = isPlaying
          ? (size.height * 0.2 + (i % 3) * size.height * 0.2)
          : size.height * 0.35;

      // Played portion vs unplayed
      final isPlayed = x <= progressX;

      final paint = Paint()
        ..color = isPlayed ? color : color.withValues(alpha: 0.3)
        ..strokeWidth = barWidth * 1.2
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(x, midY - height / 2),
        Offset(x, midY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.isPlaying != isPlaying ||
        oldDelegate.progress != progress;
  }
}

// ─── Attachment button ───────────────────────────────────────────────────

class _AttachmentButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
