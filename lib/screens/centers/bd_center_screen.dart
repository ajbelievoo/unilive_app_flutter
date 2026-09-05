/// BD Center — native replacement for the web-based BD (Business Development) panel.
///
/// Features:
/// - BD dashboard with earnings, agency count, host count
/// - Agency list under the BD
/// - Host requests management
/// - Settlement/payout history
/// - Weekly earning breakdown
library centers;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/json_annotation_helper.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart' show formatCount;
import '../../utils/log.dart';
import '../../widgets/premium_ui.dart';
import '../../widgets/user_avatar.dart';

class BdCenterScreen extends StatefulWidget {
  const BdCenterScreen({super.key});

  @override
  State<BdCenterScreen> createState() => _BdCenterScreenState();
}

class _BdCenterScreenState extends State<BdCenterScreen>
    with SingleTickerProviderStateMixin {
  static const String _tag = 'BdCenter';

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _agencyData;
  Map<String, dynamic>? _earning;
  Map<String, dynamic>? _settlement;
  Map<String, dynamic>? _hostRequests;
  bool _loading = true;
  String? _error;

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final session = context.read<SessionManager>();
    final userId = session.userId;
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, 1).toIso8601String().split('T').first;
    final endDate = DateTime(now.year, now.month + 1, 0).toIso8601String().split('T').first;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // First try getBdProfile with userId — if it fails, get hostBd from host/profile
      var bdId = userId;
      var profileRes = await ApiService.getBdProfile(bdId);
      
      // If BD profile not found with userId, try getting hostBd from host/profile
      if (profileRes['status'] != true) {
        final hostRes = await ApiService.getHostProfile(userId);
        final hostData = hostRes['data'] as Map<String, dynamic>?;
        final hostBd = hostData?['hostBd']?.toString();
        if (hostBd != null && hostBd.isNotEmpty) {
          bdId = hostBd;
          profileRes = await ApiService.getBdProfile(bdId);
        }
      }

      final results = await Future.wait([
        ApiService.getBdAgencyData(bdId),
        ApiService.getBdEarning(bdId, startDate: startDate, endDate: endDate),
        ApiService.getBdSettlement(bdId, startDate: startDate, endDate: endDate),
        ApiService.getBdHostRequests(bdId),
      ]);
      _profile = profileRes;
      _agencyData = results[0];
      _earning = results[1];
      _settlement = results[2];
      _hostRequests = results[3];
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: Column(children: [
            _buildHeader(),
            if (_loading)
              const Expanded(child: Center(child: PremiumLoading()))
            else if (_error != null || _profile?['status'] == false)
              Expanded(
                child: EmptyState(
                  icon: Icons.person_off,
                  title: 'Not a BD Member',
                  subtitle: _profile?['message']?.toString() ?? _error ?? 'You need BD access to view this page',
                ),
              )
            else ...[
              _buildStatsRow(),
              const SizedBox(height: 12),
              _buildTabBar(),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildDashboardTab(),
                    _buildAgenciesTab(),
                    _buildSettlementTab(),
                    _buildRequestsTab(),
                  ],
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = context.read<SessionManager>().getUser();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        UserAvatar(
          imageUrl: user?.image,
          size: 40,
          isVIP: user?.isVIP ?? false,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.name ?? user?.username ?? 'BD',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'BD Center',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white70),
          onPressed: _loadAll,
        ),
      ]),
    );
  }

  Widget _buildStatsRow() {
    final data = _profile?['data'] as Map<String, dynamic>? ?? {};
    final currentCoin = parseInt(data['currentCoin'] ?? 0);
    final agencyCount = parseInt(data['totalbdWiseAgency'] ?? 0);
    final lifetimeCoin = parseInt(data['lifetimeCoin'] ?? 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        _statCard('Current Diamonds', formatCount(currentCoin),
            Icons.account_balance_wallet, const [Color(0xFF4F8DFD), Color(0xFF3B7BFF)]),
        const SizedBox(width: 12),
        _statCard('Agencies', '$agencyCount',
            Icons.business, const [Color(0xFF6A5AE0), Color(0xFF4A3FB8)]),
        const SizedBox(width: 12),
        _statCard('Lifetime Diamonds', formatCount(lifetimeCoin),
            Icons.diamond, const [Color(0xFFFF6B9D), Color(0xFFE84B8A)]),
      ]),
    );
  }

  Widget _statCard(String label, String value, IconData icon, List<Color> gradient) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: gradient[0].withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabCtrl,
      indicatorColor: AppTheme.primary,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white54,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      tabs: const [
        Tab(text: 'Dashboard'),
        Tab(text: 'Agencies'),
        Tab(text: 'Payouts'),
        Tab(text: 'Requests'),
      ],
    );
  }

  Widget _buildDashboardTab() {
    final data = _profile?['data'] as Map<String, dynamic>? ?? {};
    final earningData = _earning?['data'] as List? ?? [];
    final currentCoin = parseInt(data['currentCoin'] ?? 0);
    final currentAgencyCoin = parseInt(data['currentAgencyCoin'] ?? 0);
    final currentHostCoin = parseInt(data['currentHostCoin'] ?? 0);
    final lifetimeCoin = parseInt(data['lifetimeCoin'] ?? 0);
    final lastSettlementCoin = parseInt(data['lastSettlementCoin'] ?? 0);
    final totalAgencies = parseInt(data['totalbdWiseAgency'] ?? 0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('BD Profile', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _infoRow('BD Name', data['name']?.toString() ?? 'N/A', Icons.person),
                _infoRow('BD Code', data['bdCode']?.toString() ?? 'N/A', Icons.code),
                _infoRow('Unique ID', data['uniqueId']?.toString() ?? 'N/A', Icons.badge),
                _infoRow('Total Agencies', '$totalAgencies', Icons.business),
                _infoRow('Bank Details', data['bankDetails']?.toString() ?? 'N/A', Icons.account_balance),
                _infoRow('Invite Link', data['inviteLink']?.toString() ?? 'N/A', Icons.link),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Earnings', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _infoRow('Current Diamonds', formatCount(currentCoin), Icons.diamond),
                _infoRow('Agency Diamonds', formatCount(currentAgencyCoin), Icons.business),
                _infoRow('Host Diamonds', formatCount(currentHostCoin), Icons.people),
                _infoRow('Lifetime Diamonds', formatCount(lifetimeCoin), Icons.trending_up),
                _infoRow('Last Settlement Diamonds', formatCount(lastSettlementCoin), Icons.history),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (earningData.isNotEmpty) ...[
          const Text('Weekly Earnings', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...earningData.take(7).map((item) {
            final d = item as Map<String, dynamic>;
            return _earningTile(d);
          }),
        ],
      ],
    );
  }

  Widget _buildAgenciesTab() {
    final agencies = _agencyData?['data'] as List? ?? [];
    if (agencies.isEmpty) {
      return const Center(child: EmptyState(icon: Icons.business, title: 'No Agencies', subtitle: 'Agencies under your BD will appear here'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: agencies.length,
      itemBuilder: (_, i) {
        final a = agencies[i] as Map<String, dynamic>;
        return _agencyTile(a);
      },
    );
  }

  Widget _buildSettlementTab() {
    final history = _settlement?['data'] as List? ?? _settlement?['history'] as List? ?? [];
    final total = parseInt(_settlement?['total'] ?? 0);
    if (history.isEmpty && total == 0) {
      return const Center(child: EmptyState(icon: Icons.account_balance_wallet, title: 'No Payouts Yet', subtitle: 'Your settlement history will appear here'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Settled', style: TextStyle(color: Colors.white70, fontSize: 14)),
                Text(formatCount(total), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...history.map((item) {
          final d = item as Map<String, dynamic>;
          return _settlementTile(d);
        }),
      ],
    );
  }

  Widget _buildRequestsTab() {
    final requests = _hostRequests?['data'] as List? ?? [];
    if (requests.isEmpty) {
      return const Center(child: EmptyState(icon: Icons.person_add, title: 'No Host Requests', subtitle: 'Pending host requests will appear here'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (_, i) {
        final r = requests[i] as Map<String, dynamic>;
        return _requestTile(r);
      },
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _earningTile(Map<String, dynamic> d) {
    final coins = parseInt(d['coin'] ?? d['earning'] ?? 0);
    final week = d['week']?.toString() ?? d['date']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4F8DFD).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.trending_up, color: Color(0xFF4F8DFD), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(week, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ),
        Text(formatCount(coins), style: const TextStyle(color: Color(0xFFFFB800), fontSize: 15, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _agencyTile(Map<String, dynamic> a) {
    // bdWiseAgencyTypeWise returns {agency: {...}, totalCurrentCoin, hostCount}
    final agency = a['agency'] as Map<String, dynamic>? ?? a;
    final name = agency['name']?.toString() ?? 'Agency';
    final image = agency['image']?.toString() ?? agency['logo']?.toString();
    final agencyCode = agency['agencyCode']?.toString();
    final hostCount = parseInt(a['hostCount'] ?? agency['hostCount'] ?? 0);
    final totalCurrentCoin = parseInt(a['totalCurrentCoin'] ?? agency['currentCoin'] ?? 0);
    final isActive = parseBool(agency['isActive']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: image != null && image.isNotEmpty
              ? Image.network(image, width: 48, height: 48, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 48, height: 48, color: const Color(0xFF6A5AE0).withValues(alpha: 0.2),
                    child: const Icon(Icons.business, color: Color(0xFF6A5AE0))))
              : Container(
                  width: 48, height: 48, color: const Color(0xFF6A5AE0).withValues(alpha: 0.2),
                  child: const Icon(Icons.business, color: Color(0xFF6A5AE0))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.people, color: Colors.white.withValues(alpha: 0.5), size: 14),
                const SizedBox(width: 4),
                Text('$hostCount hosts', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                if (agencyCode != null) ...[
                  const SizedBox(width: 12),
                  Text('Code: $agencyCode', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                ],
              ]),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatCount(totalCurrentCoin), style: const TextStyle(color: Color(0xFFFFB800), fontSize: 14, fontWeight: FontWeight.bold)),
            if (isActive)
              const Text('Active', style: TextStyle(color: Colors.green, fontSize: 10)),
          ],
        ),
      ]),
    );
  }

  Widget _settlementTile(Map<String, dynamic> d) {
    final amount = parseInt(d['coin'] ?? d['amount'] ?? 0);
    final status = d['status']?.toString() ?? 'pending';
    final date = d['date']?.toString() ?? d['createdAt']?.toString() ?? '';
    final Color statusColor = status == 'approved' || status == 'completed'
        ? Colors.green
        : status == 'rejected'
            ? Colors.red
            : Colors.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.account_balance_wallet, color: statusColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatCount(amount), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              if (date.isNotEmpty)
                Text(date.split('T').first, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _requestTile(Map<String, dynamic> r) {
    final name = r['name']?.toString() ?? r['username']?.toString() ?? 'Unknown';
    final image = r['image']?.toString() ?? r['userImage']?.toString();
    final status = r['status']?.toString() ?? 'pending';
    final mobile = r['mobileNumber']?.toString() ?? '';
    final Color statusColor = status == 'approved'
        ? Colors.green
        : status == 'rejected'
            ? Colors.red
            : Colors.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: image != null && image.isNotEmpty
              ? Image.network(image, width: 50, height: 50, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      width: 50, height: 50, color: const Color(0xFFFF6B9D).withValues(alpha: 0.2),
                      child: const Icon(Icons.person, color: Color(0xFFFF6B9D))))
              : Container(
                  width: 50, height: 50, color: const Color(0xFFFF6B9D).withValues(alpha: 0.2),
                  child: const Icon(Icons.person, color: Color(0xFFFF6B9D))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              if (mobile.isNotEmpty)
                Text(mobile, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}
