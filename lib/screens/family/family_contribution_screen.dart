import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../models/family_models.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../utils/format_utils.dart';
import 'package:belive/widgets/preloader.dart';

/// Per-member contribution leaderboard for a family — Bigo/Chamet parity.
/// Shows weekly / monthly / all-time contribution rankings.
class FamilyContributionScreen extends StatefulWidget {
  const FamilyContributionScreen({super.key, required this.familyId, this.familyName});

  final String familyId;
  final String? familyName;

  @override
  State<FamilyContributionScreen> createState() => _FamilyContributionScreenState();
}

class _FamilyContributionScreenState extends State<FamilyContributionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<FamilyMember> _weekly = [];
  List<FamilyMember> _monthly = [];
  List<FamilyMember> _allTime = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _loadData();
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final period = _tabController.index == 0 ? 'week'
        : _tabController.index == 1 ? 'month' : 'all';
    try {
      final members = await ApiService.getFamilyContributionLeaderboard(
        familyId: widget.familyId,
        period: period,
        limit: 100,
      );
      switch (_tabController.index) {
        case 0: _weekly = members; break;
        case 1: _monthly = members; break;
        case 2: _allTime = members; break;
      }
    } catch (e) {
      // Keep empty on error
    }
    if (mounted) setState(() => _loading = false);
  }

  List<FamilyMember> get _currentList {
    switch (_tabController.index) {
      case 0: return _weekly;
      case 1: return _monthly;
      case 2: return _allTime;
      default: return _weekly;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.familyName ?? 'Family'} Contribution'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'This Week'),
            Tab(text: 'This Month'),
            Tab(text: 'All-Time'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: Preloader())
          : _currentList.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _currentList.length,
                    itemBuilder: (_, i) => _buildMemberCard(_currentList[i], i + 1),
                  ),
                ),
    );
  }

  Widget _buildMemberCard(FamilyMember m, int rank) {
    final isTop3 = rank <= 3;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isTop3 ? 2 : 0.5,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => context.pushNamed(AppRoutes.guestProfile, extra: {
          'userId': m.userId ?? m.id,
          'username': m.name,
        }),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal,
                  color: rank == 1 ? Colors.amber
                      : rank == 2 ? Colors.grey.shade400
                      : rank == 3 ? Colors.brown.shade300
                      : Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isTop3 ? (rank == 1 ? Colors.amber : rank == 2 ? Colors.grey : Colors.brown) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: m.image != null && m.image!.isNotEmpty
                        ? CachedNetworkImage(imageUrl: m.image!, fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.grey))
                        : const Icon(Icons.person, color: Colors.grey),
                  ),
                ),
                if (m.isOnline)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
              ],
            ),
          ],
        ),
        title: Text(
          m.name ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Row(
          children: [
            if (m.role == 'leader' || m.role == 'co-leader')
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: m.role == 'leader' ? Colors.amber.shade100 : Colors.teal.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  m.role == 'leader' ? 'Leader' : 'Co-Leader',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                    color: m.role == 'leader' ? Colors.orange.shade700 : Colors.teal.shade700),
                ),
              ),
            const Icon(Icons.diamond, color: Colors.amber, size: 12),
            const SizedBox(width: 2),
            Text(
              formatCount(m.contribution),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
          ],
        ),
        trailing: Text(
          'Lv ${m.level}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No contribution data yet', style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text('Member contributions will appear here once they start earning.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
