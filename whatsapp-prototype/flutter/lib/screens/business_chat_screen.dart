import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/chatbot_api.dart';
import '../theme/whatsapp_theme.dart';
import '../widgets/message_bubble.dart';

class BusinessChatScreen extends StatefulWidget {
  final Conversation conversation;
  const BusinessChatScreen({super.key, required this.conversation});

  @override
  State<BusinessChatScreen> createState() => _BusinessChatScreenState();
}

class _BusinessChatScreenState extends State<BusinessChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage> _messages = [];
  late ConversationState _convState;
  bool _loading = true;
  bool _sending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _convState = widget.conversation.state;
    _loadMessages();
    // Poll for new messages from the user
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadMessages());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final msgs = await ChatbotApiService.instance
        .getConversationMessages(widget.conversation.id);
    if (!mounted) return;
    setState(() {
      _messages = msgs;
      _loading = false;
    });
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _intervene() async {
    final ok = await ChatbotApiService.instance
        .intervene(widget.conversation.id);
    if (ok && mounted) {
      setState(() => _convState = ConversationState.intervened);
      await _loadMessages();
    }
  }

  Future<void> _leave() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: waHeaderGrey,
        title: const Text('Leave conversation?',
            style: TextStyle(color: waWhite)),
        content: const Text(
          'The bot will resume. The conversation will be marked as Attended.',
          style: TextStyle(color: waGrey),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: waGrey))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Leave', style: TextStyle(color: waGreen))),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = await ChatbotApiService.instance
        .leaveConversation(widget.conversation.id);
    if (ok && mounted) {
      setState(() => _convState = ConversationState.attended);
      await _loadMessages();
    }
  }

  Future<void> _sendMessage() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _convState != ConversationState.intervened) return;

    setState(() => _sending = true);
    _ctrl.clear();

    await ChatbotApiService.instance
        .sendAgentMessage(widget.conversation.id, text);
    await _loadMessages();
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final conv = widget.conversation;

    return Scaffold(
      backgroundColor: waChatBg,
      appBar: AppBar(
        backgroundColor: waHeaderGrey,
        titleSpacing: 0,
        title: Row(
          children: [
            _UserAvatar(name: conv.userName),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conv.userName,
                      style: const TextStyle(
                          color: waWhite, fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(
                    _stateLabel,
                    style: TextStyle(
                        color: _stateColor, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_convState == ConversationState.waitingForAgent)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.support_agent, size: 18),
                label: const Text('Intervene'),
                onPressed: _intervene,
                style: TextButton.styleFrom(
                  foregroundColor: waAgentOrange,
                  backgroundColor: waAgentOrange.withOpacity(0.15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ),
          if (_convState == ConversationState.intervened)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Leave'),
                onPressed: _leave,
                style: TextButton.styleFrom(
                  foregroundColor: waGrey,
                  backgroundColor: waLightGrey,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // State banner
          _StateBanner(state: _convState),

          // Messages
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: waGreen))
                : _messages.isEmpty
                    ? const Center(
                        child: Text('No messages yet',
                            style: TextStyle(color: waGrey)))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => MessageBubble(
                          message: _messages[i],
                          isBusinessView: true,
                        ),
                      ),
          ),

          // Input (only when agent has intervened)
          if (_convState == ConversationState.intervened)
            _AgentInput(
              controller: _ctrl,
              sending: _sending,
              onSend: _sendMessage,
            )
          else
            const _ReadOnlyBar(),
        ],
      ),
    );
  }

  String get _stateLabel {
    switch (_convState) {
      case ConversationState.waitingForAgent: return '⏳ Waiting for agent';
      case ConversationState.intervened:      return '🎧 Agent active';
      case ConversationState.attended:        return '✅ Attended';
      default:                               return '🤖 Bot handling';
    }
  }

  Color get _stateColor {
    switch (_convState) {
      case ConversationState.waitingForAgent: return waAgentOrange;
      case ConversationState.intervened:      return waGreen;
      case ConversationState.attended:        return waGrey;
      default:                               return waGrey;
    }
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────

class _StateBanner extends StatelessWidget {
  final ConversationState state;
  const _StateBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state == ConversationState.botActive) return const SizedBox.shrink();

    late String msg;
    late Color col;
    switch (state) {
      case ConversationState.waitingForAgent:
        msg = '⏳ User is requesting a human agent. Tap "Intervene" to take over.';
        col = waAgentOrange;
        break;
      case ConversationState.intervened:
        msg = '🎧 You are now in this conversation. The bot is paused.';
        col = waGreen;
        break;
      case ConversationState.attended:
        msg = '✅ This conversation has been attended and closed.';
        col = waGrey;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: col.withOpacity(0.12),
      child: Text(msg,
          style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center),
    );
  }
}

class _AgentInput extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _AgentInput(
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
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: waWhite, fontSize: 15),
                cursorColor: waGreen,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: waLightGrey,
                  hintText: 'Type as agent…',
                  hintStyle: const TextStyle(color: waGrey),
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
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                    color: waGreen, shape: BoxShape.circle),
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyBar extends StatelessWidget {
  const _ReadOnlyBar();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: waInputBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, color: waGrey.withOpacity(0.6), size: 14),
            const SizedBox(width: 6),
            Text('Read-only view — bot is active',
                style: TextStyle(color: waGrey.withOpacity(0.7), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String name;
  const _UserAvatar({required this.name});
  @override
  Widget build(BuildContext context) {
    final initials = name.split(' ').length >= 2
        ? '${name.split(' ')[0][0]}${name.split(' ')[1][0]}'.toUpperCase()
        : name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
    return CircleAvatar(
      radius: 18,
      backgroundColor: waLightGrey,
      child: Text(initials,
          style: const TextStyle(
              color: waWhite, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }
}
