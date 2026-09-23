import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/whatsapp_theme.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isBusinessView;
  final void Function(ChatOption)? onOptionTap;

  const MessageBubble({
    super.key,
    required this.message,
    this.isBusinessView = false,
    this.onOptionTap,
  });

  @override
  Widget build(BuildContext context) {
    // System messages (agent join/leave) centred
    if (message.isSystem || message.messageType == MessageType.system) {
      return _SystemMessage(text: message.text);
    }

    final isOut = isBusinessView
        ? message.senderType == SenderType.agent
        : message.senderType == SenderType.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment:
            isOut ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOut) const SizedBox(width: 4),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isOut ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Sender label in business view
                if (isBusinessView && !isOut)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 2),
                    child: Text(
                      _senderLabel,
                      style: const TextStyle(
                          color: waGreen, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),

                // Bubble
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  margin: EdgeInsets.only(
                    left: isOut ? 60 : 0,
                    right: isOut ? 0 : 60,
                  ),
                  decoration: BoxDecoration(
                    color: isOut ? waGreenDark : waLightGrey,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(10),
                      topRight:    const Radius.circular(10),
                      bottomLeft:  Radius.circular(isOut ? 10 : 2),
                      bottomRight: Radius.circular(isOut ? 2 : 10),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Message text (supports *bold* markdown-style)
                        _FormattedText(text: message.text),

                        // Timestamp + status row
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              DateFormat('h:mm a').format(message.timestamp.toLocal()),
                              style: TextStyle(
                                  color: waGrey.withOpacity(0.8),
                                  fontSize: 10),
                            ),
                            if (isOut) ...[
                              const SizedBox(width: 4),
                              _StatusTick(status: message.status),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Option buttons (below the bubble)
                if (message.options.isNotEmpty && !isOut && onOptionTap != null)
                  _OptionButtons(
                    options: message.options,
                    onTap: onOptionTap!,
                  ),
              ],
            ),
          ),
          if (isOut) const SizedBox(width: 4),
        ],
      ),
    );
  }

  String get _senderLabel {
    switch (message.senderType) {
      case SenderType.bot:   return '🤖 School Assistant';
      case SenderType.agent: return '👨‍💼 School Representative';
      default:               return 'User';
    }
  }
}

// ── System message (centred pill) ─────────────────────────────────────────

class _SystemMessage extends StatelessWidget {
  final String text;
  const _SystemMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: waSystemBg.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: waSystemMsg, fontSize: 12, height: 1.4),
        ),
      ),
    );
  }
}

// ── Quick-reply option buttons ─────────────────────────────────────────────

class _OptionButtons extends StatelessWidget {
  final List<ChatOption> options;
  final void Function(ChatOption) onTap;

  const _OptionButtons({required this.options, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: options.map((opt) {
          return InkWell(
            onTap: () => onTap(opt),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: waLightGrey,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: waGreen.withOpacity(0.5), width: 1),
              ),
              child: Text(
                opt.label,
                style: const TextStyle(
                  color: waGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Delivery tick ──────────────────────────────────────────────────────────

class _StatusTick extends StatelessWidget {
  final MessageStatus status;
  const _StatusTick({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time, size: 12, color: waGrey);
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 13, color: waGrey);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 13, color: waGrey);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 13, color: waDelivered);
    }
  }
}

// ── Bold-text formatter (*text* → bold) ────────────────────────────────────

class _FormattedText extends StatelessWidget {
  final String text;
  const _FormattedText({required this.text});

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*(.*?)\*');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: const TextStyle(color: waWhite, fontSize: 14.5, height: 1.45),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(
            color: waWhite,
            fontSize: 14.5,
            height: 1.45,
            fontWeight: FontWeight.bold),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(color: waWhite, fontSize: 14.5, height: 1.45),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }
}
