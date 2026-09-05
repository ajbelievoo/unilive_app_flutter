import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/follow_models.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../utils/log.dart';
import '../../widgets/user_avatar.dart';
import 'package:belive/widgets/preloader.dart';

/// Ported from native `FollowrsListActivity.java`.
///
/// Shows either the following list (type=1), followers list (type=2),
/// or friends list (type=3) for a given user.
class FollowersListScreen extends StatefulWidget {
  const FollowersListScreen({super.key, required this.userId, required this.type});

  /// 1 = following, 2 = followers, 3 = friends
  final int type;
  final String userId;

  @override
  State<FollowersListScreen> createState() => _FollowersListScreenState();
}

class _FollowersListScreenState extends State<FollowersListScreen> {
  static const String _tag = 'FollowersList';
  final _users = <FollowUser>[];
  bool _loading = true;
  bool _loadingMore = false;
  int _start = 0;
  static const int _limit = 20;
  bool _hasMore = true;
  final _scrollController = ScrollController();

  String get _title {
    if (widget.type == 1) return 'Following';
    if (widget.type == 3) return 'Friends';
    return 'Followers';
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = widget.type == 1
          ? await ApiService.followingList(userId: widget.userId, start: 0, limit: _limit)
          : widget.type == 3
              ? await ApiService.friendsList(userId: widget.userId, start: 0, limit: _limit)
              : await ApiService.followerList(userId: widget.userId, start: 0, limit: _limit);
      _users
        ..clear()
        ..addAll(res.users);
      _start = _users.length;
      _hasMore = res.users.length >= _limit;
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final res = widget.type == 1
          ? await ApiService.followingList(userId: widget.userId, start: _start, limit: _limit)
          : widget.type == 3
              ? await ApiService.friendsList(userId: widget.userId, start: _start, limit: _limit)
              : await ApiService.followerList(userId: widget.userId, start: _start, limit: _limit);
      _users.addAll(res.users);
      _start = _users.length;
      _hasMore = res.users.length >= _limit;
    } catch (e, s) {
      Log.e(_tag, 'loadMore failed', e, s);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: Preloader());
    if (_users.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('No ${_title.toLowerCase()} yet', style: TextStyle(color: Colors.grey.shade600)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scrollController,
        itemCount: _users.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
        itemBuilder: (_, i) {
          if (i >= _users.length) {
            return const Padding(padding: EdgeInsets.all(16), child: Center(child: Preloader(strokeWidth: 2)));
          }
          final u = _users[i];
          return ListTile(
            onTap: () => context.pushNamed(AppRoutes.guestProfile, extra: {'userId': u.id}),
            leading: UserAvatar(imageUrl: u.image, frameUrl: u.avatarFrameImage, size: 48, isVIP: u.isVIP, isVerified: u.isVerified),
            title: Row(children: [
              Flexible(child: Text(u.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (u.isVIP) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.star, size: 14, color: Color(0xFFFFA000))),
            ]),
            subtitle: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                if (u.level != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (u.level!.image?.isNotEmpty == true) ...[
                        CachedNetworkImage(
                          imageUrl: u.level!.image!,
                          width: 16,
                          height: 16,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        u.level!.name ?? '',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                if (u.country?.isNotEmpty == true)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (u.countryFlagImage?.isNotEmpty == true) ...[
                        CachedNetworkImage(
                          imageUrl: u.countryFlagImage!,
                          width: 14,
                          height: 14,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        u.country!,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.chat_bubble_outline, size: 22),
              onPressed: () => context.pushNamed(AppRoutes.chatDetail, extra: {'otherUserId': u.id}),
              tooltip: 'Chat',
            ),
          );
        },
      ),
    );
  }
}
