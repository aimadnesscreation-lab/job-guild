import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Whether voice recording is supported on this platform.
/// Web and all desktop platforms (Linux, macOS, Windows) may lack reliable
/// encoder support for the `record` package. Short-circuit to avoid runtime
/// exceptions on unsupported platforms.
bool get _voiceRecordingSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// State for the voice recorder
class VoiceRecorderState {
  final bool isRecording;
  final bool isSending;
  final String? audioPath;
  final Duration duration;
  final String? error;

  const VoiceRecorderState({
    this.isRecording = false,
    this.isSending = false,
    this.audioPath,
    this.duration = Duration.zero,
    this.error,
  });

  VoiceRecorderState copyWith({
    bool? isRecording,
    bool? isSending,
    String? audioPath,
    Duration? duration,
    String? error,
    bool clearError = false,
    bool clearPath = false,
  }) {
    return VoiceRecorderState(
      isRecording: isRecording ?? this.isRecording,
      isSending: isSending ?? this.isSending,
      audioPath: clearPath ? null : (audioPath ?? this.audioPath),
      duration: duration ?? this.duration,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Duration formatted as MM:SS for display in the recorder UI.
  String get durationDisplay {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Notifier for voice recording — record, upload, and send voice messages.
class VoiceRecorderNotifier extends Notifier<VoiceRecorderState> {
  final AudioRecorder _recorder = AudioRecorder();
  String? _outputPath;
  Timer? _timer;

  @override
  VoiceRecorderState build() {
    // Ensure the timer is cancelled if the provider is disposed while
    // recording is in progress.
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    return const VoiceRecorderState();
  }

  /// Request microphone permission
  Future<bool> requestPermission() async {
    if (!_voiceRecordingSupported) return false;
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('[VoiceRecorder] Permission check failed: $e');
      return false;
    }
  }

  /// Start recording audio
  Future<void> startRecording() async {
    if (!_voiceRecordingSupported) {
      state = state.copyWith(
        error: 'Voice recording is not supported on this platform',
      );
      return;
    }
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        state = state.copyWith(error: 'Microphone permission denied');
        return;
      }

      final dir = await getTemporaryDirectory();
      _outputPath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: _outputPath!,
      );

      state = state.copyWith(
        isRecording: true,
        duration: Duration.zero,
        clearPath: true,
        clearError: true,
      );

      // Update duration every 200ms while recording
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (state.isRecording) {
          state = state.copyWith(
            duration: state.duration + const Duration(milliseconds: 200),
          );
        }
      });
    } catch (e) {
      debugPrint('[VoiceRecorder] Start failed: $e');
      state = state.copyWith(error: 'Failed to start recording');
    }
  }

  /// Stop recording and return the file path
  Future<String?> stopRecording() async {
    _timer?.cancel();
    _timer = null;
    try {
      _outputPath = await _recorder.stop();
      state = state.copyWith(isRecording: false, audioPath: _outputPath);
      return _outputPath;
    } catch (e) {
      debugPrint('[VoiceRecorder] Stop failed: $e');
      state = state.copyWith(
        isRecording: false,
        error: 'Failed to stop recording',
      );
      return null;
    }
  }

  /// Cancel the current recording (discard audio)
  Future<void> cancelRecording() async {
    _timer?.cancel();
    _timer = null;
    try {
      await _recorder.stop();
      if (_outputPath != null) {
        final file = File(_outputPath!);
        if (await file.exists()) await file.delete();
      }
      state = const VoiceRecorderState();
    } catch (e) {
      debugPrint('[VoiceRecorder] Cancel failed: $e');
      state = const VoiceRecorderState();
    }
  }

  /// Upload recorded audio to Supabase Storage and return the public URL
  Future<String?> uploadAudio(String conversationId) async {
    final path = state.audioPath;
    if (path == null) return null;

    state = state.copyWith(isSending: true);

    try {
      final file = File(path);
      if (!await file.exists()) {
        throw Exception('Recording file not found');
      }

      final fileName =
          'voice_${conversationId}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      const bucket = 'voice_messages';

      try {
        await Supabase.instance.client.storage.createBucket(bucket);
      } catch (_) {}

      await Supabase.instance.client.storage
          .from(bucket)
          .upload(fileName, file);
      final publicUrl = Supabase.instance.client.storage
          .from(bucket)
          .getPublicUrl(fileName);

      state = state.copyWith(isSending: false, clearPath: true);
      return publicUrl;
    } catch (e) {
      debugPrint('[VoiceRecorder] Upload failed: $e');
      state = state.copyWith(
        isSending: false,
        error: 'Failed to upload voice message',
      );
      return null;
    }
  }
}

/// Provider for voice recording
final voiceRecorderProvider =
    NotifierProvider<VoiceRecorderNotifier, VoiceRecorderState>(
      () => VoiceRecorderNotifier(),
    );
