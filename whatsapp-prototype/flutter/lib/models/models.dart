// ── Models — WhatsApp Chatbot Prototype ──────────────────────────────────

enum SenderType { user, bot, agent }
enum MessageType { text, option, system }
enum MessageStatus { sending, sent, delivered, read }
enum ConversationState { botActive, waitingForAgent, intervened, attended }

// ── ChatOption ─────────────────────────────────────────────────────────────
class ChatOption {
  final String id;
  final String label;
  const ChatOption({required this.id, required this.label});

  factory ChatOption.fromJson(Map<String, dynamic> j) =>
      ChatOption(id: j['id'], label: j['label']);
}

// ── ChatMessage ─────────────────────────────────────────────────────────────
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final SenderType senderType;
  final String text;
  final MessageType messageType;
  final MessageStatus status;
  final List<ChatOption> options;
  final DateTime timestamp;
  final bool isSystem;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderType,
    required this.text,
    this.messageType = MessageType.text,
    this.status = MessageStatus.sent,
    this.options = const [],
    required this.timestamp,
    this.isSystem = false,
  });

  bool get isOutgoing => senderType == SenderType.user;
  bool get isBot => senderType == SenderType.bot;
  bool get isAgent => senderType == SenderType.agent;

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final senderTypeStr = (j['sender_type'] ?? 'USER').toString().toUpperCase();
    final SenderType st = senderTypeStr == 'BOT'
        ? SenderType.bot
        : senderTypeStr == 'AGENT'
            ? SenderType.agent
            : SenderType.user;

    final msgTypeStr = (j['message_type'] ?? 'TEXT').toString().toUpperCase();
    final MessageType mt = msgTypeStr == 'OPTION'
        ? MessageType.option
        : msgTypeStr == 'SYSTEM'
            ? MessageType.system
            : MessageType.text;

    final meta = j['metadata'] as Map<String, dynamic>? ?? {};
    final optsList = (meta['options'] as List<dynamic>? ?? [])
        .map((o) => ChatOption.fromJson(Map<String, dynamic>.from(o)))
        .toList();

    return ChatMessage(
      id: j['id'] ?? '',
      conversationId: j['conversation_id'] ?? '',
      senderId: j['sender_id'] ?? '',
      senderType: st,
      text: j['text'] ?? '',
      messageType: mt,
      status: MessageStatus.delivered,
      options: optsList,
      timestamp: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
      isSystem: mt == MessageType.system,
    );
  }
}

// ── Organization ────────────────────────────────────────────────────────────
class Organization {
  final String id;
  final String name;
  final String category;
  final String description;
  final bool verified;
  final String avatarColor;

  const Organization({
    required this.id,
    required this.name,
    required this.category,
    this.description = '',
    this.verified = false,
    this.avatarColor = '#075E54',
  });

  factory Organization.fromJson(Map<String, dynamic> j) => Organization(
        id: j['id'],
        name: j['name'],
        category: j['category'] ?? 'Organization',
        description: j['description'] ?? '',
        verified: j['verified'] == true || j['verified'] == 1,
        avatarColor: j['avatar_color'] ?? '#075E54',
      );

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }
}

// ── Conversation ─────────────────────────────────────────────────────────────
class Conversation {
  final String id;
  final String organizationId;
  final String userId;
  final String userName;
  final String? userPhone;
  final ConversationState state;
  final String chatbotState;
  final String lastMessage;
  final String lastMessageTime;
  final DateTime updatedAt;

  const Conversation({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.userName,
    this.userPhone,
    required this.state,
    required this.chatbotState,
    this.lastMessage = '',
    this.lastMessageTime = '',
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) {
    ConversationState s;
    switch ((j['state'] ?? 'BOT_ACTIVE').toString().toUpperCase()) {
      case 'WAITING_FOR_AGENT':
        s = ConversationState.waitingForAgent;
        break;
      case 'INTERVENED':
        s = ConversationState.intervened;
        break;
      case 'ATTENDED':
        s = ConversationState.attended;
        break;
      default:
        s = ConversationState.botActive;
    }
    return Conversation(
      id: j['id'],
      organizationId: j['organization_id'],
      userId: j['user_id'],
      userName: j['user_name'] ?? 'Unknown',
      userPhone: j['user_phone'],
      state: s,
      chatbotState: j['chatbot_state'] ?? 'START',
      lastMessage: j['last_message'] ?? '',
      lastMessageTime: j['last_message_time'] ?? '',
      updatedAt: DateTime.tryParse(j['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  String get stateLabel {
    switch (state) {
      case ConversationState.waitingForAgent: return 'Waiting for Agent';
      case ConversationState.intervened:      return 'Agent Active';
      case ConversationState.attended:        return 'Attended';
      default:                               return 'Bot Active';
    }
  }
}

// ── ChatbotResponse ──────────────────────────────────────────────────────────
class ChatbotApiResponse {
  final String? conversationId;
  final String? message;
  final List<ChatOption> options;
  final String conversationState;
  final String chatbotState;
  final bool agentRequired;
  final bool botResponded;
  final bool hasError;

  const ChatbotApiResponse({
    this.conversationId,
    this.message,
    this.options = const [],
    required this.conversationState,
    required this.chatbotState,
    this.agentRequired = false,
    this.botResponded = true,
    this.hasError = false,
  });

  factory ChatbotApiResponse.fromJson(Map<String, dynamic> j) =>
      ChatbotApiResponse(
        conversationId: j['conversation_id'],
        message: j['message'],
        options: (j['options'] as List<dynamic>? ?? [])
            .map((o) => ChatOption.fromJson(Map<String, dynamic>.from(o)))
            .toList(),
        conversationState: j['conversation_state'] ?? 'BOT_ACTIVE',
        chatbotState: j['chatbot_state'] ?? 'START',
        agentRequired: j['agent_required'] == true,
        botResponded: j['bot_responded'] != false,
        hasError: j['error'] == true,
      );

  factory ChatbotApiResponse.error(String msg) => ChatbotApiResponse(
        message: msg,
        conversationState: 'BOT_ACTIVE',
        chatbotState: 'START',
        hasError: true,
      );
}

// ── BusinessProfile ──────────────────────────────────────────────────────────
class BusinessProfile {
  final String organizationId;
  final String name;
  final bool verified;
  final String description;
  final String category;
  final String avatarColor;

  const BusinessProfile({
    required this.organizationId,
    required this.name,
    this.verified = false,
    this.description = '',
    this.category = 'Education',
    this.avatarColor = '#075E54',
  });

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'organization_id': organizationId,
        'name': name,
        'verified': verified,
        'description': description,
        'category': category,
        'avatar_color': avatarColor,
      };
}
