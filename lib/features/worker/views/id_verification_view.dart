// ignore_for_file: use_build_context_synchronously, use_null_aware_elements

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_services_marketplace/core/localization/locale_provider.dart';
import 'package:local_services_marketplace/core/theme/app_theme.dart';

/// ID verification flow — user uploads a photo of their CNIC/ID card and
/// optionally a selfie. The verification status is tracked on the `users`
/// table via the `id_verification_status` column.
///
/// Flow:
///   1. User sees instructions + upload CTA
///   2. Takes/selectes photo of ID card (front)
///   3. Optionally uploads selfie
///   4. Submits — status goes to "pending" for manual review
///   5. On approval, `is_verified` becomes true and badge is earned
class IdVerificationView extends ConsumerStatefulWidget {
  const IdVerificationView({super.key});

  @override
  ConsumerState<IdVerificationView> createState() => _IdVerificationViewState();
}

class _IdVerificationViewState extends ConsumerState<IdVerificationView> {
  final _picker = ImagePicker();
  XFile? _idFrontImage;
  XFile? _selfieImage;
  bool _isSubmitting = false;

  Future<void> _pickImage(bool isIdFront) async {
    final s = ref.read(appStringsProvider);
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SourceButton(
                  icon: Icons.photo_library_rounded,
                  label: s.gallery,
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                _SourceButton(
                  icon: Icons.camera_alt_rounded,
                  label: s.camera,
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
              ],
            ),
          ),
        ),
      );

      if (source == null) return;

      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (picked != null) {
        setState(() {
          if (isIdFront) {
            _idFrontImage = picked;
          } else {
            _selfieImage = picked;
          }
        });
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${s.verifyPickImageFailed}$e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _submitVerification() async {
    final s = ref.read(appStringsProvider);
    if (_idFrontImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.verifyUploadIdFirst)),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      // Web uses XFile bytes instead of File for storage uploads
      Future<void> uploadFile(String fileName, XFile file) async {
        if (kIsWeb) {
          final bytes = await file.readAsBytes();
          await client.storage
              .from('verification_docs')
              .uploadBinary(fileName, bytes);
        } else {
          await client.storage
              .from('verification_docs')
              .upload(fileName, File(file.path));
        }
      }

      // Upload ID front image to Supabase storage
      final idFileName =
          'verification/$userId/id_front_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await uploadFile(idFileName, _idFrontImage!);

      String? selfieUrl;
      String? selfieFileName;
      if (_selfieImage != null) {
        selfieFileName =
            'verification/$userId/selfie_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await uploadFile(selfieFileName, _selfieImage!);
        selfieUrl = client.storage
            .from('verification_docs')
            .getPublicUrl(selfieFileName);
      }

      final idUrl = client.storage
          .from('verification_docs')
          .getPublicUrl(idFileName);

      // Update user's verification status
      try {
        await client
            .from('users')
            .update({
              'id_verification_status': 'pending',
              'id_document_url': idUrl,
              if (selfieUrl != null) 'selfie_url': selfieUrl,
            })
            .eq('id', userId);
      } catch (e) {
        // If the users table update fails, clean up the uploaded verification
        // files so they do not become orphaned in storage.
        try {
          await client.storage.from('verification_docs').remove([idFileName]);
          if (selfieFileName != null) {
            await client.storage.from('verification_docs').remove([selfieFileName]);
          }
        } catch (_) {
          // Best-effort cleanup; original error is more important.
        }
        rethrow;
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.verifySubmittedSuccess),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${s.verifySubmitFailed}$e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (context.mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.verification)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Header ─────────────────────────────────────
            const Icon(
              Icons.verified_rounded,
              size: 64,
              color: AppTheme.verifiedBadge,
            ),
            const SizedBox(height: 12),
            Text(
              s.verifyTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              s.verifyInstruction,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // ─── ID Front Upload ───────────────────────────
            _UploadCard(
              label: s.verifyIdCardLabel,
              icon: Icons.badge_rounded,
              image: _idFrontImage,
              onTap: () => _pickImage(true),
              onRemove: () => setState(() => _idFrontImage = null),
              tapToUploadText: s.verifyTapToUpload,
            ),
            const SizedBox(height: 12),

            // ─── Selfie Upload (optional) ──────────────────
            _UploadCard(
              label: s.verifySelfieLabel,
              icon: Icons.camera_alt_rounded,
              image: _selfieImage,
              onTap: () => _pickImage(false),
              onRemove: () => setState(() => _selfieImage = null),
              tapToUploadText: s.verifyTapToUpload,
            ),
            const SizedBox(height: 24),

            // ─── Submit Button ─────────────────────────────
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submitVerification,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: Text(
                _isSubmitting ? s.verifySubmitting : s.verifySubmitButton,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.verifyDoLater),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final XFile? image;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final String tapToUploadText;

  const _UploadCard({
    required this.label,
    required this.icon,
    required this.image,
    required this.onTap,
    required this.onRemove,
    required this.tapToUploadText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: AppTheme.primaryColor),
            title: Text(label),
            trailing: image != null
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppTheme.errorColor,
                    ),
                    onPressed: onRemove,
                  )
                : null,
          ),            if (image != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              child: kIsWeb
                  ? FutureBuilder<Uint8List>(
                      future: image!.readAsBytes(),
                      builder: (context, snapshot) {
                        final bytes = snapshot.data;
                        if (bytes == null) {
                          return const SizedBox(
                            height: 160,
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        return Image.memory(
                          bytes,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Center(child: Icon(Icons.broken_image)),
                        );
                      },
                    )
                  : Image.file(
                      File(image!.path),
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Center(child: Icon(Icons.broken_image)),
                    ),
            )
          else
            InkWell(
              onTap: onTap,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_photo_alternate_rounded,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tapToUploadText,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 28, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
