import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../services/session_manager.dart';

/// Room type option shown to the host.
class RoomTypeOption {
  const RoomTypeOption({
    required this.people,
    required this.requiredUserLevel,
  });

  final int people;
  final int requiredUserLevel;
}

/// Full-screen room type chooser matching the native Chamet/Bigo style.
///
/// - Big preview at the top shows how the room will look.
/// - Bottom cards show 9/13/17/21 people options.
/// - Options are locked until the host reaches the configured user/host level.
/// - Returns the selected people count when the user taps "Using".
class ChooseRoomTypeScreen extends StatefulWidget {
  const ChooseRoomTypeScreen({
    super.key,
    required this.currentPeople,
  });

  final int currentPeople;

  @override
  State<ChooseRoomTypeScreen> createState() => _ChooseRoomTypeScreenState();
}

class _ChooseRoomTypeScreenState extends State<ChooseRoomTypeScreen> {
  late int _selectedPeople;

  // Default unlock config. Admin panel should be able to override these per
  // user level.  Backend: store `roomTypeUnlockLevels: {9:0, 13:10, 17:25, 21:41}`.
  final List<RoomTypeOption> _options = const [
    RoomTypeOption(people: 9, requiredUserLevel: 0),
    RoomTypeOption(people: 13, requiredUserLevel: 10),
    RoomTypeOption(people: 17, requiredUserLevel: 25),
    RoomTypeOption(people: 21, requiredUserLevel: 41),
  ];

  @override
  void initState() {
    super.initState();
    _selectedPeople = widget.currentPeople.clamp(9, 21);
  }

  int get _userLevel {
    final user = SessionManager.instance?.getUser();
    final name = user?.level?.name ?? '';
    final match = RegExp(r'(\d+)').firstMatch(name);
    return match != null ? int.tryParse(match.group(0) ?? '0') ?? 0 : 0;
  }

  bool _isUnlocked(RoomTypeOption option) {
    return _userLevel >= option.requiredUserLevel;
  }

  @override
  Widget build(BuildContext context) {
    final previewOption = _options.firstWhere((o) => o.people == _selectedPeople);
    final isUnlocked = _isUnlocked(previewOption);

    return PopScope(
      canPop: isUnlocked,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Fluttertoast.showToast(msg: 'User level ≥${previewOption.requiredUserLevel} required');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Choose room type', style: TextStyle(color: Colors.black, fontSize: 18)),
      ),
      body: Column(
        children: [
          // Big preview of selected room layout.
          Expanded(
            flex: 5,
            child: Center(
              child: _buildPreview(previewOption.people),
            ),
          ),

          // Room type cards.
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      'Select room type',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _options.length,
                      padding: EdgeInsets.zero,
                      itemBuilder: (_, i) => _buildOptionCard(_options[i]),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Using button.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isUnlocked ? () => Navigator.pop(context, _selectedPeople) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00D6A0),
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: Text(
                  isUnlocked ? 'Using' : 'User level ≥${previewOption.requiredUserLevel}',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildPreview(int people) {
    final gridCount = people - 1; // host seat not in grid
    const cols = 4;
    final rows = (gridCount / cols).ceil();
    const seatSize = 12.0;

    return Container(
      width: 220,
      height: 360,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7E3FF2), Color(0xFF4A00E0)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, spreadRadius: 2),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Top owner seat.
          _buildMiniSeat(seatSize, isOwner: true),
          const Text('Owner', style: TextStyle(color: Colors.white70, fontSize: 8)),
          const SizedBox(height: 10),
          // Grid rows.
          for (int r = 0; r < rows; r++) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int c = 0; c < cols; c++)
                  if (r * cols + c < gridCount)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: Column(
                        children: [
                          _buildMiniSeat(seatSize),
                          const SizedBox(height: 2),
                          Text(
                            'No.${r * cols + c + 1}',
                            style: const TextStyle(color: Colors.white70, fontSize: 6),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
            if (r < rows - 1) const SizedBox(height: 5),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniSeat(double size, {bool isOwner = false}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isOwner ? Colors.amber.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Icon(Icons.mic, size: size * 0.45, color: Colors.white70),
    );
  }

  Widget _buildOptionCard(RoomTypeOption option) {
    final selected = _selectedPeople == option.people;
    final unlocked = _isUnlocked(option);
    final gridCount = option.people - 1;

    return GestureDetector(
      onTap: unlocked ? () => setState(() => _selectedPeople = option.people) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE6FAF5) : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF00D6A0) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            // Mini card thumbnail.
            Container(
              width: 64,
              height: 84,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7E3FF2), Color(0xFF4A00E0)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people, color: Colors.white, size: 18),
                  const SizedBox(height: 4),
                  Text(
                    '$gridCount+1',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  if (!unlocked)
                    const Icon(Icons.lock, color: Colors.white70, size: 14),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${option.people} people',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                      color: selected ? const Color(0xFF00D6A0) : (unlocked ? Colors.black87 : Colors.black54),
                    ),
                  ),
                  if (!unlocked)
                    Text(
                      'User level ≥${option.requiredUserLevel}',
                      style: const TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                ],
              ),
            ),
            if (selected && unlocked)
              const Icon(Icons.check_circle, color: Color(0xFF00D6A0)),
            if (!unlocked)
              const Icon(Icons.lock, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}
