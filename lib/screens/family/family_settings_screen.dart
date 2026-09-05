/// Family Settings screen — owner-only configuration.
///
/// Owner can set:
/// - Daily sign-in reward (exp/coins per day)
/// - Minimum level to join
/// - Require approval for join requests
/// - Family announcement
/// - Family slogan
/// - Welcome message for new members
library family_settings;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../models/family_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import '../../widgets/premium_ui.dart';

class FamilySettingsScreen extends StatefulWidget {
  const FamilySettingsScreen({super.key, required this.familyId});

  final String familyId;

  @override
  State<FamilySettingsScreen> createState() => _FamilySettingsScreenState();
}

class _FamilySettingsScreenState extends State<FamilySettingsScreen> {
  static const String _tag = 'FamilySettings';

  FamilyItem? _family;
  bool _loading = true;
  bool _saving = false;

  late final TextEditingController _rewardCtrl;
  late final TextEditingController _minLevelCtrl;
  late final TextEditingController _announcementCtrl;
  late final TextEditingController _sloganCtrl;
  late final TextEditingController _welcomeCtrl;
  bool _requireApproval = false;

  @override
  void initState() {
    super.initState();
    _rewardCtrl = TextEditingController();
    _minLevelCtrl = TextEditingController();
    _announcementCtrl = TextEditingController();
    _sloganCtrl = TextEditingController();
    _welcomeCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _rewardCtrl.dispose();
    _minLevelCtrl.dispose();
    _announcementCtrl.dispose();
    _sloganCtrl.dispose();
    _welcomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getFamilyDetail(widget.familyId);
      if (res.status && res.data.isNotEmpty) {
        _family = res.data.first;
        _rewardCtrl.text = '${_family?.dailySignInReward ?? 10}';
        _minLevelCtrl.text = '${_family?.minLevelToJoin ?? 0}';
        _announcementCtrl.text = _family?.announcement ?? '';
        _sloganCtrl.text = _family?.slogan ?? '';
        _welcomeCtrl.text = _family?.welcomeMessage ?? '';
        _requireApproval = _family?.requireApproval ?? false;
      }
    } catch (e) {
      Log.e(_tag, 'load failed', e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.updateFamilySettings(
        familyId: widget.familyId,
        userId: session.userId,
        dailySignInReward: int.tryParse(_rewardCtrl.text) ?? 10,
        minLevelToJoin: int.tryParse(_minLevelCtrl.text) ?? 0,
        requireApproval: _requireApproval,
        announcement: _announcementCtrl.text.trim(),
        slogan: _sloganCtrl.text.trim(),
        welcomeMessage: _welcomeCtrl.text.trim(),
      );
      if (mounted) {
        Fluttertoast.showToast(
          msg: res.status ? 'Settings saved!' : (res.message ?? 'Failed to save'),
        );
        if (res.status) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) Fluttertoast.showToast(msg: 'Save failed. Check connection.');
      Log.e(_tag, 'save failed', e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        title: const Text('Family Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: PremiumLoading())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection('Daily Sign-in Reward', [
                    _buildTextField(
                      controller: _rewardCtrl,
                      label: 'Exp per daily sign-in',
                      hint: 'e.g. 10',
                      icon: Icons.card_giftcard,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Each member gets this much exp when they sign in daily.',
                              style: TextStyle(fontSize: 12, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _buildSection('Join Requirements', [
                    _buildTextField(
                      controller: _minLevelCtrl,
                      label: 'Minimum level to join',
                      hint: '0 = no restriction',
                      icon: Icons.lock_outline,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Require approval for join requests'),
                      subtitle: const Text('Members must be approved by leader/co-leader', style: TextStyle(fontSize: 12)),
                      value: _requireApproval,
                      activeColor: AppTheme.primary,
                      onChanged: (v) => setState(() => _requireApproval = v),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _buildSection('Family Info', [
                    _buildTextField(
                      controller: _sloganCtrl,
                      label: 'Family Slogan',
                      hint: 'A short tagline for your family',
                      icon: Icons.format_quote,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _announcementCtrl,
                      label: 'Announcement',
                      hint: 'Important message for members',
                      icon: Icons.campaign,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _welcomeCtrl,
                      label: 'Welcome Message',
                      hint: 'Shown to new members when they join',
                      icon: Icons.waving_hand,
                      maxLines: 2,
                    ),
                  ]),
                  const SizedBox(height: 30),
                  GradientButton(
                    label: 'Save Settings',
                    icon: Icons.save,
                    onPressed: _save,
                    loading: _saving,
                    height: 50,
                    borderRadius: 25,
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
}
