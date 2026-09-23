
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../services/chatbot_api.dart';
import '../theme/whatsapp_theme.dart';
import 'chat_screen.dart';
import 'mode_selection_screen.dart';

class OrganizationSearchScreen extends StatefulWidget {
  const OrganizationSearchScreen({super.key});
  @override
  State<OrganizationSearchScreen> createState() => _OrganizationSearchScreenState();
}

class _OrganizationSearchScreenState extends State<OrganizationSearchScreen> {
  final _searchCtrl = TextEditingController();
  List<Organization> _results = [];
  List<Organization> _all = [];
  bool _loading = true;
  bool _searching = false;
  String _error = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = ''; });
    final orgs = await ChatbotApiService.instance.searchOrganizations('');
    if (!mounted) return;
    if (orgs.isEmpty) {
      setState(() {
        _error = 'Could not reach the server.\nMake sure the backend is running.';
        _loading = false;
      });
    } else {
      setState(() { _all = orgs; _results = orgs; _loading = false; });
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(_searchCtrl.text));
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() { _results = _all; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    final results = await ChatbotApiService.instance.searchOrganizations(q.trim());
    if (!mounted) return;
    setState(() { _results = results; _searching = false; });
  }

  void _openOrg(Organization org) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(organization: org)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: waDarkGrey,
      appBar: AppBar(
        backgroundColor: waHeaderGrey,
        automaticallyImplyLeading: false,
        title: const Text('Find an Organisation',
            style: TextStyle(color: waWhite, fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: waGrey),
            tooltip: 'Switch Mode',
            onPressed: () {
              context.read<AppState>().resetMode();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ModeSelectionScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: waHeaderGrey,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              style: const TextStyle(color: waWhite, fontSize: 15),
              cursorColor: waGreen,
              decoration: InputDecoration(
                filled: true,
                fillColor: waLightGrey,
                hintText: 'Search schools, hospitals, businesses…',
                hintStyle: const TextStyle(color: waGrey, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: waGrey, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: waGrey, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _results = _all);
                        })
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),

          // Results or states
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: waGreen))
                : _error.isNotEmpty
                    ? _ErrorState(message: _error, onRetry: _loadAll)
                    : _searching
                        ? const Center(child: CircularProgressIndicator(color: waGreen, strokeWidth: 2))
                        : _results.isEmpty
                            ? _EmptySearch(query: _searchCtrl.text)
                            : RefreshIndicator(
                                onRefresh: _loadAll,
                                color: waGreen,
                                backgroundColor: waHeaderGrey,
                                child: ListView.separated(
                                  padding: const EdgeInsets.only(top: 8),
                                  itemCount: _results.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 0, color: waDivider, indent: 72),
                                  itemBuilder: (_, i) => _OrgListItem(
                                    org: _results[i],
                                    onTap: () => _openOrg(_results[i]),
                                  ),
                                ),
                              ),
          ),
        ],
      ),
    );
  }
}

// ── Org list item ──────────────────────────────────────────────────────────

class _OrgListItem extends StatelessWidget {
  final Organization org;
  final VoidCallback onTap;
  const _OrgListItem({required this.org, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final col = _hexColor(org.avatarColor);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundColor: col,
              child: Text(
                org.initials,
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          org.name,
                          style: const TextStyle(
                              color: waWhite, fontSize: 16, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (org.verified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: waVerifiedBlue, size: 15),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(org.category,
                      style: const TextStyle(color: waGreen, fontSize: 12)),
                  if (org.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      org.description,
                      style: const TextStyle(color: waGrey, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: waGrey, size: 20),
          ],
        ),
      ),
    );
  }
}

Color _hexColor(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll("#", "")}', radix: 16));
  } catch (_) {
    return const Color(0xFF075E54);
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, color: waGrey.withOpacity(0.5), size: 56),
              const SizedBox(height: 16),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: waGrey, fontSize: 14, height: 1.5)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: waGreen, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
}

class _EmptySearch extends StatelessWidget {
  final String query;
  const _EmptySearch({required this.query});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, color: waGrey.withOpacity(0.4), size: 56),
            const SizedBox(height: 12),
            Text(
              query.isEmpty
                  ? 'No organisations available'
                  : 'No results for "$query"',
              style: const TextStyle(color: waGrey, fontSize: 15),
            ),
          ],
        ),
      );
}
