import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/chatbot_api.dart';
import '../theme/whatsapp_theme.dart';
import '../widgets/message_bubble.dart';

const _uuid = Uuid();

class ChatScreen extends StatefulWidget {
  final Organization organization;
  final String sessionId;

  const ChatScreen({
    super.key,
    required this.organization,
    this.sessionId = 'user_001',
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _botTyping = false;
  bool _sending   = false;
  bool _offline   = false;
  // ignore: unused_field
  bool _initialised = false;
  String? _convId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Init: load history or start fresh greeting ─────────────────────────

  Future<void> _init() async {
    final online = await ChatbotApiService.instance.isOnline();
    if (!mounted) return;
    if (!online) { setState(() => _offline = true); return; }

    // Send greeting to create/resume conversation
    setState(() { _botTyping = true; });
    final r = await ChatbotApiService.instance.sendMessage(
      sessionId: widget.sessionId,
      organizationId: widget.organization.id,
      message: 'hello',
    );
    if (!mounted) return;

    if (r.hasError || r.conversationId == null) {
      setState(() { _offline = true; _botTyping = false; });
      return;
    }
    _convId = r.conversationId;

    // Load full history from server (includes prior sessions)
    final history = await ChatbotApiService.instance.getHistory(_convId!);
    if (!mounted) return;

    setState(() {
      _messages
        ..clear()
        ..addAll(history.where((m) => m.text.isNotEmpty));
      _botTyping  = false;
      _initialised = true;
    });
    _scrollDown();
  }

  // ── Send message ───────────────────────────────────────────────────────

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;
    _inputCtrl.clear();

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      conversationId: _convId ?? '',
      senderId: widget.sessionId,
      senderType: SenderType.user,
      text: trimmed,
      messageType: MessageType.text,
      status: MessageStatus.sending,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _botTyping = true;
      _sending   = true;
      // Deactivate earlier menus — like WhatsApp, a list-reply can be used once
      _deactivateMenus();
    });
    _scrollDown();

    final r = await ChatbotApiService.instance.sendMessage(
      sessionId: widget.sessionId,
      organizationId: widget.organization.id,
      message: trimmed,
    );
    if (!mounted) return;

    // Update user bubble to read
    final idx = _messages.indexOf(userMsg);
    if (idx >= 0) {
      _messages[idx] = ChatMessage(
        id: userMsg.id, conversationId: userMsg.conversationId,
        senderId: userMsg.senderId, senderType: userMsg.senderType,
        text: userMsg.text, messageType: userMsg.messageType,
        status: MessageStatus.read, options: userMsg.options,
        timestamp: userMsg.timestamp,
      );
    }

    if (r.hasError) {
      setState(() { _botTyping = false; _sending = false; _offline = true; });
      return;
    }

    _convId ??= r.conversationId;

    // Add bot response
    final List<ChatMessage> toAdd = [];
    if (r.botResponded && r.message != null && r.message!.isNotEmpty) {
      toAdd.add(ChatMessage(
        id: _uuid.v4(),
        conversationId: _convId ?? '',
        senderId: 'BOT',
        senderType: SenderType.bot,
        text: r.message!,
        messageType: r.options.isNotEmpty ? MessageType.option : MessageType.text,
        status: MessageStatus.delivered,
        options: r.options,
        timestamp: DateTime.now(),
      ));
    }

    // System pill for agent escalation
    if (r.conversationState == 'WAITING_FOR_AGENT') {
      toAdd.add(ChatMessage(
        id: _uuid.v4(),
        conversationId: _convId ?? '',
        senderId: 'SYSTEM',
        senderType: SenderType.bot,
        text: 'Your request has been forwarded to the school team.',
        messageType: MessageType.system,
        status: MessageStatus.delivered,
        timestamp: DateTime.now(),
        isSystem: true,
      ));
    }

    setState(() {
      _messages.addAll(toAdd);
      _botTyping = false;
      _sending   = false;
    });
    _scrollDown();
  }

  /// Replaces option menus on older bot messages with their read-only form.
  /// Mirrors real WhatsApp behaviour: an interactive list is single-use.
  void _deactivateMenus() {
    for (int i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      if (m.options.isNotEmpty) {
        _messages[i] = ChatMessage(
          id: m.id, conversationId: m.conversationId,
          senderId: m.senderId, senderType: m.senderType,
          text: m.text, messageType: m.messageType,
          status: m.status, options: const [],
          timestamp: m.timestamp, isSystem: m.isSystem,
        );
      }
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final org = widget.organization;
    return Scaffold(
      backgroundColor: waChatBg,
      appBar: AppBar(
        backgroundColor: waHeaderGrey,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: waWhite),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _hexColor(org.avatarColor),
              child: Text(org.initials,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(org.name,
                            style: const TextStyle(
                                color: waWhite, fontSize: 15, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (org.verified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: waVerifiedBlue, size: 14),
                      ],
                    ],
                  ),
                  Text(
                    _botTyping ? 'typing…' : org.category,
                    style: TextStyle(
                        color: _botTyping ? waGreen : waGrey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.more_vert, color: waGrey), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          if (_offline) _OfflineBanner(onRetry: _init),
          Expanded(
            child: _messages.isEmpty && !_botTyping
                ? const _WelcomeHint()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                    itemCount: _messages.length + (_botTyping ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _messages.length) return const _TypingBubble();
                      return MessageBubble(
                        message: _messages[i],
                        isBusinessView: false,
                        onOptionTap: (opt) => _send(opt.id),
                      );
                    },
                  ),
          ),
          _ChatInputBar(
            controller: _inputCtrl,
            sending: _sending,
            onSend: () => _send(_inputCtrl.text),
          ),
        ],
      ),
    );
  }
}

// ── Typing indicator ───────────────────────────────────────────────────────

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: waLightGrey,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10), topRight: Radius.circular(10),
                bottomRight: Radius.circular(10), bottomLeft: Radius.circular(2),
              ),
            ),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Opacity(
                    opacity: (i == 0 ? _anim.value
                        : i == 1 ? (_anim.value + 0.35).clamp(0.0, 1.0)
                        : (_anim.value + 0.65).clamp(0.0, 1.0)),
                    child: Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(
                          color: waGrey, shape: BoxShape.circle),
                    ),
                  ),
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input bar ──────────────────────────────────────────────────────────────

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _ChatInputBar(
      {required this.controller, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: waInputBg,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.emoji_emotions_outlined, color: waGrey, size: 24),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: waWhite, fontSize: 15),
                cursorColor: waGreen,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: waLightGrey,
                  hintText: 'Message',
                  hintStyle: const TextStyle(color: waGrey, fontSize: 15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 46, height: 46,
                decoration:
                    const BoxDecoration(color: waGreen, shape: BoxShape.circle),
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Offline / empty ────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _OfflineBanner({required this.onRetry});
  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFFFF3C9),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, color: Color(0xFF54656F), size: 16),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Cannot reach backend. Run: uvicorn app.main:app --reload (port 8000)',
                style: TextStyle(color: Color(0xFF54656F), fontSize: 11),
              ),
            ),
            TextButton(
                onPressed: onRetry,
                child: const Text('Retry',
                    style: TextStyle(color: waGreen, fontSize: 12))),
          ],
        ),
      );
}

class _WelcomeHint extends StatelessWidget {
  const _WelcomeHint();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline,
                color: waGrey.withOpacity(0.3), size: 56),
            const SizedBox(height: 12),
            Text('Starting conversation…',
                style: TextStyle(color: waGrey.withOpacity(0.6), fontSize: 14)),
          ],
        ),
      );
}

Color _hexColor(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll("#", "")}', radix: 16));
  } catch (_) {
    return const Color(0xFF075E54);
  }
}
