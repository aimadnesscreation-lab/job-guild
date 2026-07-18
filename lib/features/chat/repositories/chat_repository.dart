import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';

class ChatRepository {
  final SupabaseClient _supabase;

  ChatRepository(this._supabase);

  Stream<List<Message>> watchMessages(String jobId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('job_id', jobId)
        .order('sent_at', ascending: true)
        .map((data) => data.map((json) => Message.fromJson(json)).toList());
  }

  Future<void> sendMessage(Message message) async {
    await _supabase.from('messages').insert(message.toJson());
  }

  Future<List<Map<String, dynamic>>> getMyConversations() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // This is a complex query to get unique conversations based on job_id and participants.
    // For MVP, we can fetch all messages involving the user and group them in the UI.
    // Ideally, this would be a specialized View or RPC in Postgres.
    final response = await _supabase
        .from('messages')
        .select('*, jobs(title, employer_id)')
        .or('sender_id.eq.$userId,jobs.employer_id.eq.$userId');
    
    return List<Map<String, dynamic>>.from(response);
  }
}
