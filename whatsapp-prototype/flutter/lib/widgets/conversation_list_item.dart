import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/whatsapp_theme.dart';

class ConversationListItem extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const ConversationListItem({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _initials(conversation.userName);
    final isRequest = conversation.state == ConversationState.waitingForAgent;
    final isActive  = conversation.state == ConversationState.intervened;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Avatar with state indicator
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: _avatarColor(conversation.userId),
                  child: Text(
                    initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                if (isRequest || isActive)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isRequest ? waAgentOrange : waGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: waDarkGrey, width: 2),
                      ),
                      child: Icon(
                        isRequest ? Icons.support_agent : Icons.headset_mic,
                        size: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Name + last message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.userName,
                          style: const TextStyle(
                              color: waWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _timeStr(conversation.lastMessageTime.isNotEmpty
                            ? conversation.lastMessageTime
                            : conversation.updatedAt.toIso8601String()),
                        style: TextStyle(
                          color: isRequest ? waAgentOrange : waGrey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage.isNotEmpty
                              ? conversation.lastMessage
                              : conversation.stateLabel,
                          style: TextStyle(
                            color: isRequest ? waAgentOrange : waGrey,
                            fontSize: 13,
                            fontWeight: isRequest
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (isRequest)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: waAgentOrange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Agent Req',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      if (isActive)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: waGreen,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Live',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Color _avatarColor(String userId) {
    const colors = [
      Color(0xFF1a7e3a), Color(0xFF34B7F1), Color(0xFF6b4c9a),
      Color(0xFFc0392b), Color(0xFFe67e22), Color(0xFF075E54),
    ];
    return colors[userId.hashCode.abs() % colors.length];
  }

  String _timeStr(String iso) {
    try {
      final dt = DateTime.tryParse(iso)?.toLocal();
      if (dt == null) return '';
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return DateFormat('h:mm a').format(dt);
      }
      final yesterday = now.subtract(const Duration(days: 1));
      if (dt.day == yesterday.day) return 'Yesterday';
      return DateFormat('d MMM').format(dt);
    } catch (_) {
      return '';
    }
  }
}
