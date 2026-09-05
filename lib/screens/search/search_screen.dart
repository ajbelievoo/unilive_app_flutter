/// Ported from native `SearchActivity.java`.
///
/// Phase 11: Room + User search with tabs. Search live rooms by name, host
/// or category, and users by name or ID. Tapping a live user/room joins the
/// live/audio room; tapping an offline user opens their profile.
library search;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/const.dart';
import '../../models/follow_models.dart';
import '../../models/live_user_root.dart' as live_user;
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/live_room_join_service.dart' as join_service;
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import '../../widgets/premium_ui.dart';
import '../../widgets/user_avatar.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  static const String _tag = 'Search';
  static const int _limit = 20;

  final _ctrl = TextEditingController();
  final _recent = <String>[];
  final _scrollController = ScrollController();
  late final TabController _tabController;

  // Tab 0 = Room, Tab 1 = Users.
  final _roomResults = <live_user.LiveUser>[];
  final _userResults = <FollowUser>[];

  bool _loading = false;
  bool _loadingMore = false;
  int _start = 0;
  bool _hasMore = true;
  String _lastQuery = '';

  /// Local follow-state overrides while the list is visible.
  final Map<String, bool> _followStates = {};

  static const List<String> _trending = [
    '#live',
    '#host',
    '#vip',
    '#dance',
    '#sing',
    '#new',
    '#hot',
    '#trending',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _ctrl.addListener(_onSearchChanged);
    _loadRecent();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _ctrl.removeListener(_onSearchChanged);
    _ctrl.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isRoomTab => _tabController.index == 0;

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    // When switching tabs, clear results and re-run the current query if any.
    final q = _ctrl.text.trim();
    _lastQuery = '';
    if (q.isNotEmpty) {
      _search();
    } else {
      _clearResults();
    }
  }

  Future<void> _loadRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(Const.searchHistory) ?? [];
      if (mounted) {
        setState(() => _recent
          ..clear()
          ..addAll(raw.reversed));
      }
    } catch (e, s) {
      Log.e(_tag, 'loadRecent failed', e, s);
    }
  }

  Future<void> _saveRecent(String q) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(Const.searchHistory) ?? [];
      list.remove(q);
      list.add(q);
      // Keep last 10.
      final trimmed = list.length > 10 ? list.sublist(list.length - 10) : list;
      await prefs.setStringList(Const.searchHistory, trimmed);
      _loadRecent();
    } catch (e, s) {
      Log.e(_tag, 'saveRecent failed', e, s);
    }
  }

  Future<void> _clearRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(Const.searchHistory);
      if (mounted) setState(() => _recent.clear());
    } catch (e, s) {
      Log.e(_tag, 'clearRecent failed', e, s);
    }
  }

  void _clearResults() {
    if (_isRoomTab) {
      _roomResults.clear();
    } else {
      _userResults.clear();
    }
    _start = 0;
    _hasMore = true;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore &&
        _currentResults.isNotEmpty) {
      _loadMore();
    }
  }

  List<dynamic> get _currentResults =>
      _isRoomTab ? _roomResults : _userResults;

  void _onSearchChanged() {
    final q = _ctrl.text.trim();
    if (q == _lastQuery) return;
    _lastQuery = q;
    if (q.isEmpty) {
      _clearResults();
      if (mounted) setState(() {});
      return;
    }
    _search();
  }

  void _setQuery(String q) {
    _ctrl.text = q;
    _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: q.length));
    _lastQuery = '';
    _search();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    _lastQuery = q;
    setState(() {
      _loading = true;
      _clearResults();
    });
    try {
      final session = context.read<SessionManager>();
      if (_isRoomTab) {
        final res = await ApiService.getLiveUsers(
          userId: session.userId,
          type: 'All',
          keyword: q,
          start: 0,
          limit: _limit,
        );
        _roomResults
          ..clear()
          ..addAll(res.users.where((u) => u.isHostExists && !u.isFake).toList());
        _start = _roomResults.length;
        _hasMore = res.users.length >= _limit;
      } else {
        final res = await ApiService.searchUsers(
          userId: session.userId,
          value: q,
          start: 0,
          limit: _limit,
        );
        _userResults
          ..clear()
          ..addAll(res.users);
        _start = _userResults.length;
        _hasMore = res.users.length >= _limit;
      }
      _saveRecent(q);
    } catch (e, s) {
      Log.e(_tag, 'search failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final session = context.read<SessionManager>();
      if (_isRoomTab) {
        final res = await ApiService.getLiveUsers(
          userId: session.userId,
          type: 'All',
          keyword: q,
          start: _start,
          limit: _limit,
        );
        _roomResults.addAll(
            res.users.where((u) => u.isHostExists && !u.isFake).toList());
        _start = _roomResults.length;
        _hasMore = res.users.length >= _limit;
      } else {
        final res = await ApiService.searchUsers(
          userId: session.userId,
          value: q,
          start: _start,
          limit: _limit,
        );
        _userResults.addAll(res.users);
        _start = _userResults.length;
        _hasMore = res.users.length >= _limit;
      }
    } catch (e, s) {
      Log.e(_tag, 'loadMore failed', e, s);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _joinRoom(live_user.LiveUser room) async {
    final liveUserId = room.liveUserId ?? room.userId ?? room.id;
    if (liveUserId == null || liveUserId.isEmpty) {
      Fluttertoast.showToast(msg: 'Invalid room');
      return;
    }
    await join_service.joinLiveRoom(
      context: context,
      liveUserId: liveUserId,
      liveStreamingId: room.liveStreamingId,
      isAudio: room.isAudio,
    );
  }

  Future<void> _onUserTap(FollowUser u) async {
    final userId = u.id;
    if (userId == null || userId.isEmpty) {
      Fluttertoast.showToast(msg: 'User not found');
      return;
    }

    // If the user is currently live, join their room.
    final isLive = u.liveType != 0;
    if (isLive) {
      final isAudio = u.liveType == 1;
      final joined = await join_service.joinLiveRoom(
        context: context,
        liveUserId: userId,
        isAudio: isAudio,
      );
      if (joined) return;
    }

    if (!mounted) return;
    context.pushNamed(AppRoutes.guestProfile, extra: {'userId': userId});
  }

  bool _isFollowing(FollowUser u) {
    return _followStates[u.id ?? ''] ?? u.isFollow;
  }

  Future<void> _toggleFollow(FollowUser u) async {
    final userId = u.id;
    if (userId == null || userId.isEmpty) return;

    final session = context.read<SessionManager>();
    if (userId == session.userId) {
      Fluttertoast.showToast(msg: 'You cannot follow yourself');
      return;
    }

    final current = _isFollowing(u);
    setState(() => _followStates[userId] = !current);

    try {
      final res = await ApiService.followUnfollow({
        'userId': session.userId,
        'toUserId': userId,
      });
      if (!res.status) {
        setState(() => _followStates[userId] = current);
        Fluttertoast.showToast(msg: res.message ?? 'Failed to update follow');
      }
    } catch (e, s) {
      Log.e(_tag, 'toggleFollow failed', e, s);
      setState(() => _followStates[userId] = current);
      Fluttertoast.showToast(msg: 'Failed to follow');
    }
  }

  List<TextSpan> _highlightSpans(String text, String query) {
    if (query.isEmpty || text.isEmpty) {
      return [TextSpan(text: text)];
    }
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx == -1) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + lowerQuery.length),
        style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.bold),
      ));
      start = idx + lowerQuery.length;
    }
    return spans;
  }

  String _levelNumber(FollowUser u) {
    final levelName = u.level?.name ?? u.hostLevel?.name ?? '';
    return levelName.replaceAll(RegExp(r'[^0-9]'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: const BackButton(color: Colors.white),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.darkGradient)),
        title: Padding(
          padding: const EdgeInsets.only(right: 16, top: 6, bottom: 6),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: _isRoomTab
                  ? 'Search room by name or ID'
                  : 'Search user by name or ID',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
              prefixIcon: const Icon(Icons.search, size: 20, color: Colors.white70),
              suffixIcon: _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: Colors.white70),
                      onPressed: () {
                        _ctrl.clear();
                        _clearResults();
                        if (mounted) setState(() {});
                      },
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildTabs(),
          const Divider(height: 1, color: Color(0xFFE8E8F0)),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.textSecondary,
        indicatorColor: AppTheme.primary,
        indicatorWeight: 3,
        labelStyle:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(text: 'Room'),
          Tab(text: 'Users'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: PremiumLoading());
    if (_ctrl.text.isEmpty) return _suggestions();
    if (_currentResults.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: _isRoomTab ? 'No rooms found' : 'No users found',
        subtitle: 'Try a different keyword',
      );
    }
    if (_isRoomTab) return _buildRoomList();
    return _buildUserList();
  }

  Widget _buildRoomList() {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _roomResults.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        indent: 76,
        color: Color(0xFFEEEEEE),
      ),
      itemBuilder: (_, i) {
        if (i >= _roomResults.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
                child: PremiumLoading(size: 24, strokeWidth: 2)),
          );
        }
        return _buildRoomTile(_roomResults[i]);
      },
    );
  }

  Widget _buildUserList() {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _userResults.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        indent: 76,
        color: Color(0xFFEEEEEE),
      ),
      itemBuilder: (_, i) {
        if (i >= _userResults.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
                child: PremiumLoading(size: 24, strokeWidth: 2)),
          );
        }
        return _buildUserTile(_userResults[i]);
      },
    );
  }

  Widget _buildRoomTile(live_user.LiveUser room) {
    final coverUrl = (room.roomImage != null && room.roomImage!.isNotEmpty)
        ? room.roomImage
        : room.image;
    final hostName = room.roomName != null && room.roomName!.isNotEmpty
        ? room.roomName
        : room.name;
    final viewers = room.view;
    final isAudio = room.isAudio;
    final countryCode = room.country;
    final countryFlagUrl = room.countryFlagImage;

    return ListTile(
      onTap: () => _joinRoom(room),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 56,
          height: 56,
          child: (coverUrl != null && coverUrl.isNotEmpty)
              ? CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: Colors.grey.shade200,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.person, color: Colors.grey),
                  ),
                )
              : Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.person, color: Colors.grey),
                ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              hostName ?? 'Live room',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: isAudio ? const Color(0xFF7E3FF2) : Colors.red,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAudio ? Icons.mic : Icons.videocam,
                  size: 10,
                  color: Colors.white,
                ),
                const SizedBox(width: 2),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (countryFlagUrl != null && countryFlagUrl.isNotEmpty) ...[
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: countryFlagUrl,
                width: 14,
                height: 14,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: 4),
          ] else if (countryCode != null && countryCode.length == 2) ...[
            Text(_countryFlagEmoji(countryCode),
                style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              '${room.name ?? 'Host'} • $viewers watching',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(FollowUser u) {
    final tags = u.tags.isNotEmpty
        ? u.tags
        : ((u.bio ?? '').isNotEmpty ? [u.bio!] : const <String>[]);
    final countryCode = u.country;
    final countryFlagUrl = u.countryFlagImage;
    final hasCountry = (countryFlagUrl != null && countryFlagUrl.isNotEmpty) ||
        (countryCode != null && countryCode.length == 2);
    final userIdText = u.uniqueId ?? u.username ?? '';
    final levelNum = _levelNumber(u);
    final isLive = u.liveType != 0;
    final isFollowing = _isFollowing(u);
    final showOnline = u.isOnline || isLive;

    return InkWell(
      onTap: () => _onUserTap(u),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(
                    imageUrl: u.image,
                    frameUrl: u.avatarFrameImage,
                    vipBadgeUrl: u.vipBadgeUrl,
                    size: 52,
                    isVIP: u.isVIP,
                    isVerified: u.isVerified,
                  ),
                  if (showOnline)
                    const Positioned(
                      bottom: 0,
                      right: 0,
                      child: _OnlineDot(),
                    ),
                  if (levelNum.isNotEmpty)
                    Positioned(
                      bottom: -2,
                      left: 0,
                      right: 0,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF34C759),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            'Lv$levelNum',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            children: _highlightSpans(
                              u.name ?? '',
                              _lastQuery,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (u.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified,
                            size: 16, color: Colors.blue),
                      ],
                      if (u.isVIP) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.star,
                            size: 16, color: Color(0xFFFFA000)),
                      ],
                      if (isLive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: u.liveType == 1
                                ? const Color(0xFF7E3FF2)
                                : Colors.red,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (userIdText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFFE0E0E0), width: 0.8),
                        ),
                        child: Text(
                          'ID: $userIdText',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  if (tags.isNotEmpty || hasCountry)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: SizedBox(
                        height: 20,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount:
                              tags.length + (hasCountry ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(width: 4),
                          itemBuilder: (_, i) {
                            if (hasCountry && i == 0) {
                              return _buildCountryChip(
                                  countryCode, countryFlagUrl);
                            }
                            final tagIndex = hasCountry ? i - 1 : i;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                tags[tagIndex],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildFollowButton(u, isFollowing),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryChip(String? countryCode, String? countryFlagUrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (countryFlagUrl != null && countryFlagUrl.isNotEmpty) ...[
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: countryFlagUrl,
                width: 12,
                height: 12,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ] else if (countryCode != null && countryCode.length == 2) ...[
            Text(_countryFlagEmoji(countryCode),
                style: const TextStyle(fontSize: 11)),
          ],
          if (countryCode != null && countryCode.isNotEmpty) ...[
            const SizedBox(width: 3),
            Text(
              countryCode.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFollowButton(FollowUser u, bool isFollowing) {
    final session = context.read<SessionManager>();
    if ((u.id ?? '') == session.userId) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _toggleFollow(u),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isFollowing
              ? const Color(0xFFFFB800).withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(color: const Color(0xFFFFB800), width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          isFollowing ? 'Following' : 'Follow',
          style: const TextStyle(
            color: Color(0xFFFFB800),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _suggestions() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_recent.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              GestureDetector(
                onTap: _clearRecent,
                child: const Text('Clear all',
                    style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recent
                .map((q) => _chip(q, Icons.history, AppTheme.purpleGradient,
                    () => _setQuery(q)))
                .toList(),
          ),
          const SizedBox(height: 24),
        ],
        const Text('Trending',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _trending
              .map((q) => _chip(q, Icons.local_fire_department,
                  AppTheme.pinkGradient, () => _setQuery(q)))
              .toList(),
        ),
      ],
    );
  }

  Widget _chip(String label, IconData icon, Gradient gradient, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  String _countryFlagEmoji(String code) {
    if (code.length != 2) return '';
    final c = code.toUpperCase();
    return String.fromCharCode(c.codeUnitAt(0) + 0x1F1E6 - 0x41) +
        String.fromCharCode(c.codeUnitAt(1) + 0x1F1E6 - 0x41);
  }
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: Colors.green,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
