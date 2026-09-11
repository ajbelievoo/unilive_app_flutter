/// Create Family screen — Bigo Live / screenshot style.
///
/// Hexagon cover picker, name/notification fields, join mode, level
/// requirement and 6,000,000 coins create button.
library family_create_honor;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

class FamilyCreateHonorScreen extends StatefulWidget {
  const FamilyCreateHonorScreen({super.key});

  @override
  State<FamilyCreateHonorScreen> createState() => _FamilyCreateHonorScreenState();
}

class _FamilyCreateHonorScreenState extends State<FamilyCreateHonorScreen> {
  static const String _tag = 'FamilyCreateHonor';

  final _nameCtrl = TextEditingController();
  final _noticeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _imagePath;
  String _joinMode = 'Leader/Co-Leader Review';
  int _requiredLevel = 0;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noticeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(source: ImageSource.gallery);
      if (xFile != null) setState(() => _imagePath = xFile.path);
    } catch (e, s) {
      Log.e(_tag, 'pickImage failed', e, s);
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      Fluttertoast.showToast(msg: 'Enter family name');
      return;
    }

    final session = context.read<SessionManager>();
    const cost = 6000000;
    final user = session.getUser();
    if ((user?.coin ?? 0) < cost) {
      Fluttertoast.showToast(msg: 'You need at least $cost diamonds to create a family');
      return;
    }

    setState(() => _submitting = true);
    try {
      final res = await ApiService.createFamily(
        userId: session.userId,
        name: name,
        description: _noticeCtrl.text.trim(),
        logoFile: _imagePath != null ? File(_imagePath!) : null,
        coverFile: _imagePath != null ? File(_imagePath!) : null,
        isPublic: _joinMode == 'Anyone can join',
        minLevelToJoin: _requiredLevel,
        requireApproval: _joinMode == 'Leader/Co-Leader Review',
        welcomeMessage: _noticeCtrl.text.trim(),
      );
      if (res.status) {
        Fluttertoast.showToast(msg: 'Family created successfully!');
        if (mounted) context.pop();
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Failed to create family');
      }
    } catch (e, s) {
      Log.e(_tag, 'createFamily failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to create family');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDF8E8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: const Text('Create Family', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          children: [
            // Hexagon cover picker
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: SizedBox(
                  width: 130,
                  height: 130,
                  child: CustomPaint(
                    painter: _HexagonBorderPainter(color: const Color(0xFFD2B48C)),
                    child: ClipPath(
                      clipper: _HexagonClipper(),
                      child: _imagePath != null
                          ? Image.file(File(_imagePath!), fit: BoxFit.cover)
                          : Container(
                              color: const Color(0xFFD2B48C).withValues(alpha: 0.6),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt, color: Colors.white, size: 34),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Center(child: Text('Tap to change family cover', style: TextStyle(color: Colors.black54, fontSize: 13))),
            const SizedBox(height: 24),

            // Family Name
            _labeledInput('Family Name', controller: _nameCtrl, maxLength: 15, hint: 'Enter your family name'),
            const SizedBox(height: 16),

            // Gift badge decorative
            Center(
              child: Container(
                width: 140,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF8E8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8D990)),
                ),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ImageIcon(AssetImage("assets/gift/official_gift.png"), color: Color(0xFF2E7D32), size: 22),
                      SizedBox(width: 4),
                      Text('1', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Family notification
            _labeledInput('Family notification', controller: _noticeCtrl, maxLength: 200, hint: 'Enter your family notification', maxLines: 3),
            const SizedBox(height: 20),

            // Join mode row
            _optionRow('Join mode', _joinMode, () => _selectJoinMode()),
            const SizedBox(height: 16),

            // Join level requirement
            _optionRow('Join level Requirements', 'Lv.$_requiredLevel', () => _selectLevel()),
            const SizedBox(height: 30),

            // Create button
            GestureDetector(
              onTap: _submitting ? null : _submit,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF00C897), Color(0xFF00B386)]),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [BoxShadow(color: const Color(0xFF00C897).withValues(alpha: 0.3), blurRadius: 12, spreadRadius: 1)],
                ),
                child: Center(
                  child: _submitting
                      ? const SizedBox(width: 22, height: 22, child: Preloader(color: Colors.white, strokeWidth: 2))
                      : const Text(
                          'Create with 6000000 diamonds',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Rules
            const Text(
              '1.Only SVIP4 and above users can create a family for free\n'
              '2.The family will be automatically disbanded if the number of family members is 1 for 7 consecutive days\n'
              '3.The family portrait and family name can be modified only once a month',
              style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _labeledInput(
    String label, {
    required TextEditingController controller,
    int maxLength = 100,
    String hint = '',
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLength: maxLength,
          maxLines: maxLines,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
              Text('$currentLength/$maxLength', style: const TextStyle(color: Colors.black38, fontSize: 11)),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF1F1F1),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _optionRow(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.black54, fontSize: 14)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.black54, size: 20),
        ],
      ),
    );
  }

  void _selectJoinMode() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Leader/Co-Leader Review'),
              onTap: () {
                setState(() => _joinMode = 'Leader/Co-Leader Review');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Anyone can join'),
              onTap: () {
                setState(() => _joinMode = 'Anyone can join');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _selectLevel() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: 260,
          child: ListView.builder(
            itemCount: 21,
            itemBuilder: (_, i) => ListTile(
              title: Text('Lv.$i'),
              onTap: () {
                setState(() => _requiredLevel = i);
                Navigator.pop(context);
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Hexagon helpers -------------------------------------------------------
class _HexagonBorderPainter extends CustomPainter {
  final Color color;
  _HexagonBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(_hexagonPath(size), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _hexagonPath(size);

  @override
  bool shouldReclip(_) => false;
}

Path _hexagonPath(Size size) {
  final path = Path();
  final center = Offset(size.width / 2, size.height / 2);
  final radius = size.width / 2;
  for (int i = 0; i < 6; i++) {
    final angle = i * math.pi / 3;
    final x = center.dx + radius * math.cos(angle);
    final y = center.dy + radius * math.sin(angle);
    if (i == 0) path.moveTo(x, y);
    path.lineTo(x, y);
  }
  path.close();
  return path;
}
