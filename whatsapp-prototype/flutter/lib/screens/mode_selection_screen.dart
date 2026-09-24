import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/whatsapp_theme.dart';
import 'business_setup_screen.dart';
import 'business_home_screen.dart';
import 'organization_search_screen.dart';

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: waDarkGrey,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: waGreen,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: waGreen.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.chat, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              const Text('WhatsApp Business',
                  style: TextStyle(color: waWhite, fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Prototype Platform', style: TextStyle(color: waGrey, fontSize: 15)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: waGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: waGreen.withOpacity(0.3)),
                ),
                child: const Text('Phase 2 — School Edition',
                    style: TextStyle(color: waGreen, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 60),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('CHOOSE YOUR VIEW',
                    style: TextStyle(color: waGrey, fontSize: 11,
                        fontWeight: FontWeight.w600, letterSpacing: 1.2)),
              ),
              const SizedBox(height: 14),
              _ModeCard(
                icon: Icons.business_center_outlined,
                iconBg: waGreen,
                title: 'Business Mode',
                subtitle: 'Manage conversations & agent\nrequests as the school.',
                badge: 'SCHOOL STAFF',
                onTap: () => _goBusinessMode(context),
              ),
              const SizedBox(height: 14),
              _ModeCard(
                icon: Icons.person_outline,
                iconBg: waVerifiedBlue,
                title: 'User Mode',
                subtitle: 'Search the school and chat\nwith the automated assistant.',
                badge: 'PARENT / USER',
                onTap: () => _goUserMode(context),
              ),
              const Spacer(),
              const Text(
                'No Meta credentials or internet connection required.',
                textAlign: TextAlign.center,
                style: TextStyle(color: waGrey, fontSize: 11),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _goBusinessMode(BuildContext context) async {
    final state = context.read<AppState>();
    state.selectMode(AppMode.business);
    await state.loadBusinessProfile();
    if (!context.mounted) return;
    if (state.hasBusinessProfile) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const BusinessHomeScreen()));
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const BusinessSetupScreen()));
    }
  }

  void _goUserMode(BuildContext context) {
    context.read<AppState>().selectMode(AppMode.user);
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const OrganizationSearchScreen()));
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon, required this.iconBg, required this.title,
    required this.subtitle, required this.badge, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: iconBg.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconBg, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: const TextStyle(
                            color: waWhite, fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                    Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconBg.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(badge, style: TextStyle(
                              color: iconBg, fontSize: 9,
                              fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(color: waGrey, fontSize: 13, height: 1.4)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: waGrey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
