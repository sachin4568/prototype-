import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../theme/whatsapp_theme.dart';
import 'business_home_screen.dart';

class BusinessSetupScreen extends StatefulWidget {
  const BusinessSetupScreen({super.key});
  @override
  State<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends State<BusinessSetupScreen> {
  final _nameCtrl = TextEditingController(text: 'Sunrise International School');
  final _descCtrl = TextEditingController(text: 'Excellence in education since 1995.');
  String _category = 'K-12 Education';
  bool _verified = true;
  String _avatarColor = '#075E54';
  bool _saving = false;

  static const _categories = [
    'K-12 Education', 'Higher Education', 'Healthcare',
    'Business', 'Government', 'Non-profit', 'Other'
  ];

  static const _avatarColors = [
    '#075E54', '#128C7E', '#25D366', '#34B7F1',
    '#1a7e3a', '#6b4c9a', '#c0392b', '#e67e22',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an organisation name')),
      );
      return;
    }
    setState(() => _saving = true);

    final profile = BusinessProfile(
      organizationId: 'org_001',
      name: _nameCtrl.text.trim(),
      verified: _verified,
      description: _descCtrl.text.trim(),
      category: _category,
      avatarColor: _avatarColor,
    );

    final ok = await context.read<AppState>().saveBusinessProfile(profile);
    setState(() => _saving = false);

    if (ok && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BusinessHomeScreen()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved locally — backend may be offline'),
          backgroundColor: Colors.orange,
        ),
      );
      // Still navigate even on backend error (offline-first UX)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BusinessHomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: waDarkGrey,
      appBar: AppBar(
        backgroundColor: waHeaderGrey,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: waGrey),
          onPressed: () {
            context.read<AppState>().resetMode();
            Navigator.pop(context);
          },
        ),
        title: const Text('Set Up Business Profile',
            style: TextStyle(color: waWhite, fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar preview
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  _AvatarPreview(
                    name: _nameCtrl.text,
                    color: _avatarColor,
                    size: 90,
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: waGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Profile image is generated from initials',
                style: TextStyle(color: waGrey.withOpacity(0.7), fontSize: 11),
              ),
            ),
            const SizedBox(height: 28),

            // Color picker
            _SectionLabel('Avatar Color'),
            const SizedBox(height: 10),
            Row(
              children: _avatarColors.map((c) {
                final selected = c == _avatarColor;
                final col = _hexToColor(c);
                return GestureDetector(
                  onTap: () => setState(() => _avatarColor = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: col,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? waWhite : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Organisation name
            _SectionLabel('Organisation Name *'),
            const SizedBox(height: 8),
            _WaTextField(
              controller: _nameCtrl,
              hint: 'e.g. ABC International School',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Description
            _SectionLabel('Description'),
            const SizedBox(height: 8),
            _WaTextField(
              controller: _descCtrl,
              hint: 'Short description of your organisation',
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Category
            _SectionLabel('Category'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: waLightGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _category,
                  isExpanded: true,
                  dropdownColor: waHeaderGrey,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  style: const TextStyle(color: waWhite, fontSize: 15),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Verified toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: waLightGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: waVerifiedBlue, size: 22),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Verified Badge',
                            style: TextStyle(color: waWhite, fontWeight: FontWeight.w600)),
                        Text('Show ✓ verification indicator',
                            style: TextStyle(color: waGrey, fontSize: 12)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _verified,
                    activeColor: waGreen,
                    onChanged: (v) => setState(() => _verified = v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: waAgentOrange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: waAgentOrange.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: waAgentOrange, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Prototype only — this does not actually verify with WhatsApp.',
                      style: TextStyle(color: waAgentOrange, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: waGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('Continue',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            color: waGrey, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8),
      );
}

class _WaTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final void Function(String)? onChanged;
  const _WaTextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLines: maxLines,
        onChanged: onChanged,
        style: const TextStyle(color: waWhite, fontSize: 15),
        cursorColor: waGreen,
        decoration: InputDecoration(
          filled: true,
          fillColor: waLightGrey,
          hintText: hint,
          hintStyle: const TextStyle(color: waGrey, fontSize: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
}

class _AvatarPreview extends StatelessWidget {
  final String name;
  final String color;
  final double size;
  const _AvatarPreview(
      {required this.name, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').length >= 2
            ? '${name.trim().split(' ')[0][0]}${name.trim().split(' ')[1][0]}'.toUpperCase()
            : name.trim().substring(0, name.trim().length >= 2 ? 2 : 1).toUpperCase();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: _hexToColor(color),
      child: Text(initials,
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.35,
              fontWeight: FontWeight.bold)),
    );
  }
}

Color _hexToColor(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.parse('FF$h', radix: 16));
}
