import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// All HTTP communication with the FastAPI backend lives here.
/// No HTTP calls anywhere else in the app.
///
/// Base URL:
///   - Android emulator  → http://10.0.2.2:8000
///   - Web / Desktop dev → http://localhost:8000
///   - iOS simulator     → http://localhost:8000
///   Change [_base] to match your environment.
class ChatbotApiService {
  // ── Change this if running on a physical device ──────────────────────────
  static const String _base = 'http://localhost:8000';
  // For Android emulator use: 'http://10.0.2.2:8000'

  static const Duration _timeout = Duration(seconds: 12);
  static final ChatbotApiService instance = ChatbotApiService._();
  ChatbotApiService._();

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _get(String path) async {
    try {
      final res = await http.get(Uri.parse('$_base$path')).timeout(_timeout);
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<List<dynamic>?> _getList(String path) async {
    try {
      final res = await http.get(Uri.parse('$_base$path')).timeout(_timeout);
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _post(String path, Map<String, dynamic> body) async {
    try {
      final res = await http.post(
        Uri.parse('$_base$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(_timeout);
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  // ── Health ────────────────────────────────────────────────────────────────

  Future<bool> isOnline() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/health'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Organisations ──────────────────────────────────────────────────────────

  Future<List<Organization>> searchOrganizations(String query) async {
    final list = await _getList(
      '/api/chat/organizations${query.isNotEmpty ? '?q=${Uri.encodeQueryComponent(query)}' : ''}',
    );
    if (list == null) return [];
    return list.map((j) => Organization.fromJson(Map<String, dynamic>.from(j))).toList();
  }

  Future<Organization?> getOrganization(String orgId) async {
    final d = await _get('/api/chat/organizations/$orgId');
    return d == null ? null : Organization.fromJson(d);
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  Future<ChatbotApiResponse> sendMessage({
    required String sessionId,
    required String organizationId,
    required String message,
  }) async {
    final d = await _post('/api/chat', {
      'session_id': sessionId,
      'organization_id': organizationId,
      'message': message,
    });
    if (d == null) return ChatbotApiResponse.error('Could not reach the server.');
    return ChatbotApiResponse.fromJson(d);
  }

  Future<List<ChatMessage>> getHistory(String conversationId) async {
    final list = await _getList('/api/chat/history/$conversationId');
    if (list == null) return [];
    return list.map((j) => ChatMessage.fromJson(Map<String, dynamic>.from(j))).toList();
  }

  // ── Business Profile ───────────────────────────────────────────────────────

  Future<bool> saveBusinessProfile(BusinessProfile profile) async {
    final d = await _post('/api/agent/profile', profile.toJson());
    return d != null && d['success'] == true;
  }

  Future<BusinessProfile?> getBusinessProfile(String orgId) async {
    final d = await _get('/api/agent/profile/$orgId');
    if (d == null) return null;
    return BusinessProfile(
      organizationId: d['organization_id'],
      name: d['name'],
      verified: d['verified'] == true || d['verified'] == 1,
      description: d['description'] ?? '',
      category: d['category'] ?? 'Education',
      avatarColor: d['avatar_color'] ?? '#075E54',
    );
  }

  // ── Agent / Business ───────────────────────────────────────────────────────

  Future<List<Conversation>> getAllConversations(String orgId) async {
    final list = await _getList('/api/agent/conversations/$orgId');
    if (list == null) return [];
    return list.map((j) => Conversation.fromJson(Map<String, dynamic>.from(j))).toList();
  }

  Future<List<Conversation>> getAgentRequests(String orgId) async {
    final list = await _getList('/api/agent/requests/$orgId');
    if (list == null) return [];
    return list.map((j) => Conversation.fromJson(Map<String, dynamic>.from(j))).toList();
  }

  Future<int> getAgentRequestCount(String orgId) async {
    final d = await _get('/api/agent/requests/$orgId/count');
    return (d?['count'] as int?) ?? 0;
  }

  Future<List<ChatMessage>> getConversationMessages(String convId) async {
    final list = await _getList('/api/agent/conversation/$convId/messages');
    if (list == null) return [];
    return list.map((j) => ChatMessage.fromJson(Map<String, dynamic>.from(j))).toList();
  }

  Future<bool> intervene(String convId) async {
    final d = await _post('/api/agent/conversations/$convId/intervene', {});
    return d != null && d['success'] == true;
  }

  Future<bool> leaveConversation(String convId) async {
    final d = await _post('/api/agent/conversations/$convId/leave', {});
    return d != null && d['success'] == true;
  }

  Future<bool> sendAgentMessage(String convId, String text) async {
    final d = await _post('/api/agent/conversations/$convId/message',
        {'text': text, 'agent_id': 'agent_001'});
    return d != null && d['success'] == true;
  }
}
