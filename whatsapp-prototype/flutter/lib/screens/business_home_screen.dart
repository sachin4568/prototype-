import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../services/chatbot_api.dart';
import '../theme/whatsapp_theme.dart';
import '../widgets/conversation_list_item.dart';
import 'business_chat_screen.dart';
import 'mode_selection_screen.dart';

enum BusinessTab { all, requests, active, attended }

class BusinessHomeScreen extends StatefulWidget {
  const BusinessHomeScreen({super.key});
  @override
  State<BusinessHomeScreen> createState() => _BusinessHomeScreenState();
}

class _BusinessHomeScreenState extends State<BusinessHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Conversation> _allConvs = [];
  List<Conversation> _requests = [];
  List<Conversation> _active = [];
  List<Conversation> _attended = [];
  bool _loading = true;
  Timer? _refreshTimer;

  static const _orgId = 'org_001';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
    // Poll every 5 seconds so agent-request badge stays fresh
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final api = ChatbotApiService.instance;
    final futures = await Future.wait([
      api.getAllConversations(_orgId),
      api.getAgentRequests(_orgId),
    ]);
    final all = futures[0];
    final reqs = futures[1];

    if (!mounted) return;
    setState(() {
      _allConvs = all;
      _requests = reqs;
      _active = all
          .where((c) => c.state == ConversationState.intervened)
          .toList();
      _attended = all
          .where((c) => c.state == ConversationState.attended)
          .toList();
      _loading = false;
    });
    context.read<AppState>().refreshAgentCount();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final profile = appState.businessProfile;
    final reqCount = appState.agentRequestCount;

    return Scaffold(
      backgroundColor: waDarkGrey,
      appBar: AppBar(
        backgroundColor: waHeaderGrey,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            _OrgAvatar(
              initials: profile?.initials ?? 'OR',
              color: profile?.avatarColor ?? '#075E54',
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile?.name ?? 'Organisation',
                          style: const TextStyle(
                              color: waWhite, fontSize: 16, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (profile?.verified == true) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: waVerifiedBlue, size: 15),
                      ],
                    ],
                  ),
                  const Text('Business Mode',
                      style: TextStyle(color: waGreen, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: waGrey),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: waGrey),
            onPressed: () {
              context.read<AppState>().resetMode();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ModeSelectionScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: waGreen,
          labelColor: waGreen,
          unselectedLabelColor: waGrey,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: [
            const Tab(text: 'All'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Requests'),
                  if (reqCount > 0) ...[
                    const SizedBox(width: 5),
                    _Badge(count: reqCount, color: waAgentOrange),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Active'),
                  if (_active.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    _Badge(count: _active.length, color: waGreen),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Attended'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: waGreen))
          : RefreshIndicator(
              onRefresh: _load,
              color: waGreen,
              backgroundColor: waHeaderGrey,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _ConvList(convs: _allConvs, onTap: _openConv, emptyMsg: 'No conversations yet'),
                  _ConvList(convs: _requests, onTap: _openConv, emptyMsg: 'No agent requests', emptyIcon: Icons.support_agent_outlined),
                  _ConvList(convs: _active, onTap: _openConv, emptyMsg: 'No active agent sessions', emptyIcon: Icons.headset_mic_outlined),
                  _ConvList(convs: _attended, onTap: _openConv, emptyMsg: 'No attended conversations', emptyIcon: Icons.check_circle_outline),
                ],
              ),
            ),
    );
  }

  void _openConv(Conversation conv) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessChatScreen(conversation: conv),
      ),
    ).then((_) => _load());
  }
}

// ── Conversation list ──────────────────────────────────────────────────────

class _ConvList extends StatelessWidget {
  final List<Conversation> convs;
  final void Function(Conversation) onTap;
  final String emptyMsg;
  final IconData emptyIcon;

  const _ConvList({
    required this.convs,
    required this.onTap,
    required this.emptyMsg,
    this.emptyIcon = Icons.chat_bubble_outline,
  });

  @override
  Widget build(BuildContext context) {
    if (convs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, color: waGrey.withOpacity(0.4), size: 56),
            const SizedBox(height: 12),
            Text(emptyMsg,
                style: TextStyle(color: waGrey.withOpacity(0.6), fontSize: 15)),
          ],
        ),
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: convs.length,
      separatorBuilder: (_, __) => const Divider(
          height: 0, color: waDivider, indent: 74),
      itemBuilder: (ctx, i) => ConversationListItem(
        conversation: convs[i],
        onTap: () => onTap(convs[i]),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final int count;
  final Color color;
  const _Badge({required this.count, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
        child: Text('$count',
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      );
}

class _OrgAvatar extends StatelessWidget {
  final String initials;
  final String color;
  final double size;
  const _OrgAvatar(
      {required this.initials, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    final col =
        Color(int.parse('FF${color.replaceAll("#", "")}', radix: 16));
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: col,
      child: Text(initials,
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.38,
              fontWeight: FontWeight.bold)),
    );
  }
}
