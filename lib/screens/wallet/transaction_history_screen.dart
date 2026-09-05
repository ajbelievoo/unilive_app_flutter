import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/transaction_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

/// Ported from native `TransactionHistoryActivity.java` — fully redesigned.
///
/// Premium glassmorphic UI with:
/// - Blurred decorative gradient orbs + glow
/// - 3D-style summary cards (Credit / Debit / Balance / Bet / Call)
/// - Pill filter tabs with animated glow indicator
/// - Shimmer loading skeletons
/// - Search bar to filter by title / description
/// - Transaction detail bottom sheet (balanceAfter, related user, gateway…)
/// - Relative time ("2h ago") + full date
/// - Pull-to-refresh, pagination, haptic feedback, share.
class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen>
    with TickerProviderStateMixin {
  static const String _tag = 'TransactionHistory';

  static const List<String> _tabLabels = [
    'All',
    'Credit',
    'Debit',
    'Bet',
    'Call',
    'Recharge',
  ];
  static const List<String> _tabFilters = [
    'all',
    'credit',
    'debit',
    'bet',
    'call',
    'credit',
  ];
  static const List<String?> _tabCategories = [
    null,
    null,
    null,
    null,
    null,
    'offline_recharge',
  ];
  static const int _pageLimit = 20;

  // ---- Brand colours ------------------------------------------------------
  static const Color _headerA = Color(0xFF4A148C);
  static const Color _headerB = Color(0xFF6A1B9A);
  static const Color _headerC = Color(0xFF8E24AA);
  static const Color _glowPurple = Color(0xFFB388FF);

  final _transactions = <TransactionItem>[];
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  late final TabController _tabController;

  TransactionSummaryRoot? _summary;
  int _currentStart = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMoreData = true;
  bool _searchVisible = false;
  String _searchQuery = '';
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _onTabSelected(_tabController.index);
    });
    _scrollController.addListener(_onScroll);
    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q != _searchQuery) {
        setState(() => _searchQuery = q);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (_loading || _loadingMore || !_hasMoreData) return;
    if (pos.pixels <= pos.maxScrollExtent - 240) return;
    _loadMore();
  }

  // ---- Data ---------------------------------------------------------------
  Future<void> _refresh() async {
    _currentStart = 0;
    _hasMoreData = true;
    _loadError = null;
    await _loadSummary();
    await _loadTransactions(refresh: true);
  }

  Future<void> _loadSummary() async {
    try {
      final session = context.read<SessionManager>();
      final s = await ApiService.getTransactionSummary(session.userId);
      if (mounted) setState(() => _summary = s);
    } catch (e, s) {
      Log.e(_tag, 'summary failed', e, s);
    }
  }

  Future<void> _loadTransactions({required bool refresh}) async {
    if (refresh) {
      setState(() => _loading = true);
    } else {
      if (_loadingMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.getTransactionHistoryFiltered(
        userId: session.userId,
        type: _tabFilters[_tabController.index],
        category: _tabCategories[_tabController.index],
        start: _currentStart,
        limit: _pageLimit,
      );
      if (res.status) {
        _loadError = null;
        final items = res.history;
        if (refresh) _transactions.clear();
        if (items.isNotEmpty) {
          _transactions.addAll(items);
          _currentStart += items.length;
          _hasMoreData = items.length >= _pageLimit;
        } else {
          _hasMoreData = false;
        }
      } else {
        if (refresh) _transactions.clear();
        _hasMoreData = false;
        _loadError = res.message ?? 'Transaction history request failed';
      }
    } catch (e, s) {
      if (refresh) _transactions.clear();
      _hasMoreData = false;
      _loadError = 'Could not load transaction history';
      Log.e(_tag, 'load failed', e, s);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMore() => _loadTransactions(refresh: false);

  Future<void> _onTabSelected(int index) async {
    HapticFeedback.selectionClick();
    _currentStart = 0;
    _hasMoreData = true;
    setState(() {
      _loading = true;
      _transactions.clear();
    });
    await _loadTransactions(refresh: true);
  }

  List<TransactionItem> get _filteredTransactions {
    if (_searchQuery.isEmpty) return _transactions;
    return _transactions.where((t) {
      final title = (t.title ?? '').toLowerCase();
      final desc = (t.description ?? '').toLowerCase();
      return title.contains(_searchQuery) || desc.contains(_searchQuery);
    }).toList();
  }

  // ---- Build --------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F4FB),
      extendBodyBehindAppBar: true,
      body: Stack(
        alignment: Alignment.topLeft,
        children: [
          // Decorative blurred gradient orbs in the background
          Positioned(
            top: -80,
            right: -60,
            child: _blurOrb(const Color(0xFFB388FF), 180, 0.35),
          ),
          Positioned(
            top: 220,
            left: -90,
            child: _blurOrb(const Color(0xFF7E3FF2), 200, 0.18),
          ),
          SafeArea(
            top: false,
            child: Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                if (_searchVisible) _buildSearchBar(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _blurOrb(Color color, double size, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
        ),
      ),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: const SizedBox.expand(),
      ),
    );
  }

  // ---- Premium glassmorphic header ----------------------------------------
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_headerA, _headerB, _headerC],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x4D6A1B9A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          // Glow accents inside header
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _glowPurple.withValues(alpha: 0.35),
                    _glowPurple.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
              child: Column(
                children: [
                  // Top bar
                  Row(
                    children: [
                      _glassIconButton(
                        icon: Icons.arrow_back_ios_new,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const Expanded(
                        child: Text(
                          'Transaction History',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            shadows: [
                              Shadow(
                                color: Color(0x66000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _glassIconButton(
                        icon: _searchVisible ? Icons.search_off : Icons.search,
                        onTap:
                            () => setState(() {
                              _searchVisible = !_searchVisible;
                              if (!_searchVisible) {
                                _searchController.clear();
                                _searchQuery = '';
                              }
                            }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  // Summary cards row 1
                  Row(
                    children: [
                      Expanded(
                        child: _summaryCard(
                          label: 'Credits',
                          value: _summary?.totalCredit ?? 0,
                          icon: Icons.savings,
                          gradient: const [
                            Color(0xFF11998E),
                            Color(0xFF38EF7D),
                          ],
                          glow: const Color(0xFF38EF7D),
                          labelColor: const Color(0xFFC8F7D4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _summaryCard(
                          label: 'Debits',
                          value: _summary?.totalDebit ?? 0,
                          icon: Icons.local_fire_department,
                          gradient: const [
                            Color(0xFFFF512F),
                            Color(0xFFF09819),
                          ],
                          glow: const Color(0xFFFF512F),
                          labelColor: const Color(0xFFFFD9CC),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _summaryCard(
                          label: 'Balance',
                          value: _summary?.currentBalance?.diamonds ?? 0,
                          icon: Icons.account_balance_wallet,
                          gradient: const [
                            Color(0xFF2193B2),
                            Color(0xFF6DD5ED),
                          ],
                          glow: const Color(0xFF6DD5ED),
                          labelColor: const Color(0xFFCDEEFA),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Summary cards row 2
                  Row(
                    children: [
                      Expanded(
                        child: _summaryCard(
                          label: 'Total Bets',
                          value: _summary?.totalBet ?? 0,
                          icon: Icons.casino,
                          gradient: const [
                            Color(0xFFF7971E),
                            Color(0xFFFFD200),
                          ],
                          glow: const Color(0xFFFFD200),
                          labelColor: const Color(0xFFFFEEB8),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _summaryCard(
                          label: 'Total Calls',
                          value: _summary?.totalCall ?? 0,
                          icon: Icons.phone_in_talk,
                          gradient: const [
                            Color(0xFF8E2DE2),
                            Color(0xFFD464FF),
                          ],
                          glow: const Color(0xFFD464FF),
                          labelColor: const Color(0xFFEAD0FF),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _summaryCard(
                          label: 'Diamonds',
                          value: _summary?.currentBalance?.coins ?? 0,
                          icon: Icons.diamond,
                          gradient: const [
                            Color(0xFFB993D6),
                            Color(0xFF8CA6DB),
                          ],
                          glow: const Color(0xFFB993D6),
                          labelColor: const Color(0xFFE8DEF5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  // ---- 3D summary card with glow + glassmorphism --------------------------
  Widget _summaryCard({
    required String label,
    required double value,
    required IconData icon,
    required List<Color> gradient,
    required Color glow,
    required Color labelColor,
  }) {
    return AnimatedScale(
      scale: _loading ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [gradient[0], gradient[1]],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            // Outer glow
            BoxShadow(
              color: glow.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            // Inner depth
            const BoxShadow(
              color: Color(0x22000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // 3D icon container
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.35),
                    Colors.white.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: glow.withValues(alpha: 0.6),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
                shadows: const [
                  Shadow(
                    color: Color(0x66000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _formatAmount(value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                shadows: [
                  Shadow(
                    color: Color(0x55000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Pill filter tabs with animated glow indicator ----------------------
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _glowPurple.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_tabLabels.length, (i) {
          final selected = i == _tabController.index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _tabController.animateTo(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  gradient:
                      selected
                          ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF7E3FF2), Color(0xFF5B2DD6)],
                          )
                          : null,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow:
                      selected
                          ? [
                            BoxShadow(
                              color: _glowPurple.withValues(alpha: 0.55),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                          : null,
                ),
                child: Text(
                  _tabLabels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : AppTheme.textSecondary,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ---- Search bar ---------------------------------------------------------
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search by title or description…',
            hintStyle: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 13,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: AppTheme.primary,
              size: 22,
            ),
            suffixIcon:
                _searchQuery.isNotEmpty
                    ? IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: AppTheme.textTertiary,
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                    : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  // ---- Body ---------------------------------------------------------------
  Widget _buildBody() {
    if (_loading) return _buildShimmerList();
    if (_loadError != null) {
      return _buildEmptyState(message: '$_loadError. Pull down to retry.');
    }
    final list = _filteredTransactions;
    if (_transactions.isEmpty) return _buildEmptyState();
    if (list.isEmpty) {
      return _buildEmptyState(message: 'No matches for "$_searchQuery"');
    }
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: list.length + (_loadingMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == list.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Preloader(strokeWidth: 2.5)),
            );
          }
          return _TransactionCard(
            item: list[i],
            onTap: () => _showDetailSheet(list[i]),
          );
        },
      ),
    );
  }

  // ---- Shimmer loading skeleton -------------------------------------------
  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: 6,
        itemBuilder:
            (_, __) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 92,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
      ),
    );
  }

  // ---- Empty state --------------------------------------------------------
  Widget _buildEmptyState({String message = 'No transactions found'}) {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 90),
          Center(
            child: Column(
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        _glowPurple.withValues(alpha: 0.18),
                        _glowPurple.withValues(alpha: 0),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    size: 56,
                    color: AppTheme.primary.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pull down to refresh',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Transaction detail bottom sheet ------------------------------------
  void _showDetailSheet(TransactionItem item) {
    HapticFeedback.lightImpact();
    final typeLower = (item.type ?? '').toLowerCase();
    final meta = _typeMeta(typeLower);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (ctx) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Grabber
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header with 3D icon + amount
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: meta.gradient,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: meta.glow.withValues(alpha: 0.5),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(meta.icon, color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        item.title ?? meta.defaultTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${meta.isCredit ? '+' : '-'}${_formatAmountValue(item.amount)} ${_currencyLabel(item.currency)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color:
                              meta.isCredit
                                  ? AppTheme.green
                                  : const Color(0xFFE53935),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Detail rows
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    children: [
                      _detailRow('Type', _capitalize(typeLower), meta.glow),
                      _detailRow('Description', item.description ?? '-', null),
                      _detailRow('Date', _formatDate(item.createdAt), null),
                      _detailRow(
                        'Balance After',
                        '${_formatAmountValue(item.balanceAfter)} ${_currencyLabel(item.currency)}',
                        null,
                      ),
                      if ((item.relatedUserName ?? '').isNotEmpty)
                        _detailRow('Related User', item.relatedUserName!, null),
                      if ((item.paymentGateway ?? '').isNotEmpty)
                        _detailRow(
                          'Payment Gateway',
                          item.paymentGateway!,
                          null,
                        ),
                      if ((item.category ?? '').isNotEmpty)
                        _detailRow('Category', item.category!, null),
                    ],
                  ),
                ),
                // Share button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _shareTransaction(item);
                      },
                      icon: const Icon(Icons.share_outlined, size: 20),
                      label: const Text(
                        'Share',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _detailRow(String label, String value, Color? accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: accent ?? AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _shareTransaction(TransactionItem item) {
    final typeLower = (item.type ?? '').toLowerCase();
    final meta = _typeMeta(typeLower);
    final text =
        StringBuffer()
          ..writeln('Belive — Transaction')
          ..writeln('Title: ${item.title ?? meta.defaultTitle}')
          ..writeln(
            'Amount: ${meta.isCredit ? "+" : "-"}${_formatAmountValue(item.amount)} ${_currencyLabel(item.currency)}',
          )
          ..writeln('Date: ${_formatDate(item.createdAt)}');
    if ((item.description ?? '').isNotEmpty)
      text.writeln('Note: ${item.description}');
    Share.share(text.toString());
  }

  // ---- Helpers ------------------------------------------------------------
  _TypeMeta _typeMeta(String typeLower) {
    switch (typeLower) {
      case 'credit':
        return const _TypeMeta(
          icon: Icons.savings,
          gradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
          glow: Color(0xFF38EF7D),
          isCredit: true,
          defaultTitle: 'Credit',
        );
      case 'debit':
        return const _TypeMeta(
          icon: Icons.local_fire_department,
          gradient: [Color(0xFFFF512F), Color(0xFFF09819)],
          glow: Color(0xFFFF512F),
          isCredit: false,
          defaultTitle: 'Debit',
        );
      case 'bet':
        return const _TypeMeta(
          icon: Icons.casino,
          gradient: [Color(0xFFF7971E), Color(0xFFFFD200)],
          glow: Color(0xFFFFD200),
          isCredit: false,
          defaultTitle: 'Bet',
        );
      case 'call':
        return const _TypeMeta(
          icon: Icons.phone_in_talk,
          gradient: [Color(0xFF8E2DE2), Color(0xFFD464FF)],
          glow: Color(0xFFD464FF),
          isCredit: false,
          defaultTitle: 'Call',
        );
      default:
        return const _TypeMeta(
          icon: Icons.receipt_long,
          gradient: [Color(0xFF7E3FF2), Color(0xFF5B2DD6)],
          glow: Color(0xFF7E3FF2),
          isCredit: false,
          defaultTitle: 'Transaction',
        );
    }
  }

  String _currencyLabel(String? c) {
    final s = (c ?? 'diamonds').toLowerCase();
    if (s == 'coin' || s == 'coins') return 'Diamonds';
    if (s == 'rcoin' || s == 'rcoins') return 'Beans';
    return 'Diamonds';
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String _formatAmount(double v) {
    if (v == v.roundToDouble()) return formatCount(v.round());
    return v.toStringAsFixed(2);
  }

  String _formatAmountValue(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(2);
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return raw;
    }
  }

  String _relativeTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return '';
    }
  }
}

// ---- Type metadata ---------------------------------------------------------
class _TypeMeta {
  const _TypeMeta({
    required this.icon,
    required this.gradient,
    required this.glow,
    required this.isCredit,
    required this.defaultTitle,
  });
  final IconData icon;
  final List<Color> gradient;
  final Color glow;
  final bool isCredit;
  final String defaultTitle;
}

// ---- Transaction item card -------------------------------------------------
class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.item, required this.onTap});
  final TransactionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typeLower = (item.type ?? '').toLowerCase();
    final state =
        context.findAncestorStateOfType<_TransactionHistoryScreenState>();
    final meta =
        state?._typeMeta(typeLower) ??
        const _TypeMeta(
          icon: Icons.receipt_long,
          gradient: [Color(0xFF7E3FF2), Color(0xFF5B2DD6)],
          glow: Color(0xFF7E3FF2),
          isCredit: false,
          defaultTitle: 'Transaction',
        );

    final currencyLabel = state?._currencyLabel(item.currency) ?? 'Diamonds';
    final amountPrefix = meta.isCredit ? '+' : '-';
    final amountColor =
        meta.isCredit ? AppTheme.green : const Color(0xFFE53935);
    final relativeTime = state?._relativeTime(item.createdAt) ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: meta.glow.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Glow accent strip
              Container(
                width: 5,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [meta.glow, meta.glow.withValues(alpha: 0.4)],
                  ),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [
                    BoxShadow(
                      color: meta.glow.withValues(alpha: 0.5),
                      blurRadius: 6,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                  child: Row(
                    children: [
                      // 3D icon container
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: meta.gradient,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: meta.glow.withValues(alpha: 0.45),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          meta.icon,
                          color: Colors.white,
                          size: 26,
                          shadows: const [
                            Shadow(
                              color: Color(0x55000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Title + description + date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title ?? meta.defaultTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _typeBadge(typeLower, meta.glow),
                              ],
                            ),
                            if ((item.description ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: AppTheme.textTertiary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  relativeTime,
                                  style: const TextStyle(
                                    color: AppTheme.textTertiary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Amount
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$amountPrefix${state?._formatAmountValue(item.amount) ?? item.amount}',
                            style: TextStyle(
                              color: amountColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              shadows: [
                                Shadow(
                                  color: amountColor.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currencyLabel,
                            style: const TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeBadge(String typeLower, Color color) {
    if (typeLower.isEmpty) return const SizedBox.shrink();
    final label = typeLower[0].toUpperCase() + typeLower.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
