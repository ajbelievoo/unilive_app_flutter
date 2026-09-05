import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/const.dart';
import '../../models/chat_root.dart';
import '../../models/follow_models.dart';
import '../../models/assigned_tag.dart';
import '../../models/guest_profile_root.dart';
import '../../models/json_annotation_helper.dart';
import '../../models/live_stream_root.dart';
import '../../models/audio_room_root.dart';
import '../../routes/app_routes.dart';
import '../call/call_screen.dart' show startCall;
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../services/socket_service.dart';
import '../../services/deep_link_service.dart';
import '../../utils/format_utils.dart';
import '../../utils/log.dart';
import '../../utils/media_utils.dart';
import '../../widgets/profile_badge_row.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/gift_bottom_sheet.dart';
import '../../widgets/mic_wave_widget.dart';
import '../../models/post_root.dart';
import 'package:belive/widgets/preloader.dart';

/// Premium guest profile matching the native screenshot.
/// Green gradient header, medal slots, stats card, wallet, and grid menu.
class GuestProfileScreen extends StatefulWidget {
  const GuestProfileScreen({super.key, this.userId, this.username});

  final String? userId;
  final String? username;

  @override
  State<GuestProfileScreen> createState() => _GuestProfileScreenState();
}

class _GuestProfileScreenState extends State<GuestProfileScreen>
    with SingleTickerProviderStateMixin {
  static const String _tag = 'GuestProfile';
  GuestUser? _user;
  bool _loading = true;
  bool _followLoading = false;
  bool _isFollow = false;
  bool _isLiked = false;
  bool _isLive = false;
  LiveUser? _liveUser;
  late TabController _tabCtrl;
  Future<FollowersRoot>? _friendsFuture;
  String? _chatTopic;
  bool _sentVisitMessage = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final session = context.read<SessionManager>();
    try {
      GuestProfileRoot res;
      if (widget.userId != null && widget.userId!.isNotEmpty) {
        res = await ApiService.getGuestProfile(widget.userId!);
      } else if (widget.username != null && widget.username!.isNotEmpty) {
        res = await ApiService.getGuestProfileByUsername(widget.username!);
      } else {
        if (mounted) setState(() => _loading = false);
        return;
      }
      if (res.status && res.user != null) {
        _user = res.user;
        // If the profile payload already says the user is in a live room,
        // show the LIVE indicator + Room button immediately while we fetch
        // the full room details.
        if (_user!.isInLiveRoom && _user!.liveRoom != null) {
          setState(() {
            _isLive = true;
            _liveUser = _buildLiveUserFromGuestLiveRoom(_user!.liveRoom!);
          });
        }
        // Profile API doesn't return isFollow/isLiked — check both separately
        final profileId = _user!.id ?? widget.userId ?? '';
        if (profileId.isNotEmpty) {
          // Fetch friends for this profile so the count and list are accurate.
          _friendsFuture = ApiService.friendsList(
            userId: profileId,
            start: 0,
            limit: 20,
          );
          _friendsFuture!
              .then((friendsRes) {
                if (mounted && friendsRes.users.isNotEmpty) {
                  setState(
                    () =>
                        _user = _user!.copyWith(
                          friends: friendsRes.users.length,
                        ),
                  );
                }
              })
              .catchError((e) {
                Log.e(_tag, 'friendsList count failed', e);
              });
          // Check follow status via followers list
          ApiService.checkFollowStatus(session.userId, profileId)
              .then((isFollowing) {
                if (mounted) setState(() => _isFollow = isFollowing);
              })
              .catchError((e) {
                Log.e(_tag, 'checkFollowStatus failed', e);
              });
          // Check like status from local storage (no API to check like status)
          _loadLikeStatus(session.userId, profileId);
          // Record profile visit (native: POST /user/visitProfile)
          ApiService.visitProfile(
            userId: session.userId,
            profileUserId: profileId,
          ).ignore();
          // Check if user is currently live (native: GET /liveUser/getLive)
          ApiService.getGuestUserLive(profileId)
              .then((liveRes) {
                if (liveRes.status && liveRes.user != null && mounted) {
                  setState(() {
                    _isLive = true;
                    _liveUser = liveRes.user;
                  });
                }
              })
              .catchError((e) {
                Log.e(_tag, 'getGuestUserLive failed', e);
                return null;
              })
              .then((_) {
                // Fallback: if the profile already told us the user is in a live room
                // but /liveUser/getLive didn't return a full room object, try
                // /liveStream with the liveStreamingId from the liveRoom snapshot.
                if (_isLive || _user == null) return;
                final liveRoom = _user!.liveRoom;
                final liveStreamingId = liveRoom?.liveStreamingId;
                if (liveRoom?.isLive == true &&
                    liveStreamingId?.isNotEmpty == true) {
                  ApiService.getLiveStream(liveStreamingId!)
                      .then((liveRes) {
                        if (liveRes.status && liveRes.user != null && mounted) {
                          setState(() {
                            _isLive = true;
                            _liveUser = liveRes.user;
                          });
                        }
                      })
                      .catchError((e) {
                        Log.e(_tag, 'getLiveStream fallback failed', e);
                        return null;
                      });
                }
                return null;
              });
        }
      }
    } catch (e, s) {
      Log.e(_tag, 'loadProfile failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  LiveUser _buildLiveUserFromGuestLiveRoom(GuestLiveRoom room) {
    return LiveUser(
      id: room.liveStreamingId,
      userId: room.liveUserId,
      name: room.roomName,
      roomName: room.roomName,
      roomImage: room.roomImage,
      isAudio: room.isAudio,
      liveType: room.isAudio ? 'audio' : 'video',
    );
  }

  void _joinLiveRoom() {
    final live = _liveUser;
    if (live == null) return;
    if (live.channel?.isNotEmpty != true || live.token?.isNotEmpty != true) {
      // We only have a snapshot; try to fetch the full room details before joining.
      final liveStreamingId = live.id ?? _user?.liveRoom?.liveStreamingId ?? '';
      if (liveStreamingId.isEmpty) {
        Fluttertoast.showToast(msg: 'Room details not available');
        return;
      }
      setState(() => _loading = true);
      ApiService.getLiveStream(liveStreamingId)
          .then((liveRes) {
            if (mounted) setState(() => _loading = false);
            if (liveRes.status && liveRes.user != null && mounted) {
              setState(() => _liveUser = liveRes.user);
              _pushToRoom(liveRes.user!);
            } else {
              Fluttertoast.showToast(msg: 'Room not available');
            }
          })
          .catchError((e) {
            if (mounted) setState(() => _loading = false);
            Log.e(_tag, 'getLiveStream in _joinLiveRoom failed', e);
            Fluttertoast.showToast(msg: 'Could not join room');
            return null;
          });
      return;
    }
    _pushToRoom(live);
  }

  void _pushToRoom(LiveUser live) {
    if (live.isAudio) {
      var room = AudioRoomUser.fromJson(live.toJson());
      // Fallback to the profile we are visiting if the join API didn't
      // return the host's display name / unique id.
      final hostName = room.name ?? _user?.name ?? room.roomName;
      final hostImage = room.image ?? _user?.image ?? room.roomImage;
      room = room.copyWith(
        name: hostName,
        image: hostImage,
        uniqueId: room.uniqueId ?? _user?.uniqueId,
      );
      context.pushNamed(
        AppRoutes.audioRoom,
        extra: {'roomUser': room, 'isHost': false},
      );
    } else {
      context.pushNamed(
        AppRoutes.liveRoom,
        extra: {'liveUser': live, 'isHost': false},
      );
    }
  }

  Future<void> _toggleFollow() async {
    if (_user == null) return;
    setState(() => _followLoading = true);
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.followUnfollow({
        'fromUserId': session.userId,
        'toUserId': _user!.id,
      });
      if (res.status) {
        // API returns isFollow in response — use it for accurate state
        final isFollow = res.data?['isFollow'] == true;
        setState(() => _isFollow = isFollow);
        Fluttertoast.showToast(msg: _isFollow ? 'Followed' : 'Unfollowed');
      }
    } catch (e, s) {
      Log.e(_tag, 'toggleFollow failed', e, s);
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  /// Load like status from local storage (no API exists to check like status).
  Future<void> _loadLikeStatus(String myUserId, String profileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'like_$myUserId';
      final likedIds = prefs.getStringList(key) ?? [];
      if (mounted) setState(() => _isLiked = likedIds.contains(profileId));
    } catch (e) {
      Log.e(_tag, 'loadLikeStatus failed', e);
    }
  }

  /// Save like status to local storage.
  Future<void> _saveLikeStatus(
    String myUserId,
    String profileId,
    bool liked,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'like_$myUserId';
      final likedIds = <String>{...prefs.getStringList(key) ?? []};
      if (liked) {
        likedIds.add(profileId);
      } else {
        likedIds.remove(profileId);
      }
      await prefs.setStringList(key, likedIds.toList());
    } catch (e) {
      Log.e(_tag, 'saveLikeStatus failed', e);
    }
  }

  Future<void> _toggleProfileLike() async {
    if (_user?.id == null) return;
    final session = context.read<SessionManager>();
    try {
      final res = await ApiService.likeUnlikeUser(
        senderId: session.userId,
        receiverId: _user!.id!,
      );
      if (res.status) {
        // API returns isLiked and likeCount in response — use them for accurate state
        final isLiked = res.data?['isLiked'] == true;
        final rawCount = res.data?['likeCount'];
        final newCount =
            rawCount is num
                ? rawCount.toInt()
                : (isLiked
                    ? _user!.likeCount + 1
                    : (_user!.likeCount > 0 ? _user!.likeCount - 1 : 0));
        setState(() {
          _isLiked = isLiked;
          _user = _user!.copyWith(likeCount: newCount);
        });
        // Persist like status locally so it survives refresh
        _saveLikeStatus(session.userId, _user!.id!, isLiked);
        Fluttertoast.showToast(msg: _isLiked ? 'Liked' : 'Unliked');
      }
    } catch (e) {
      Log.e(_tag, 'profileLike failed', e);
      Fluttertoast.showToast(msg: 'Failed');
    }
  }

  Future<void> _openGifts() async {
    if (_user?.id == null) return;
    final session = context.read<SessionManager>();
    final myUserId = session.userId;
    final receiverId = _user!.id!;
    if (myUserId == receiverId) {
      Fluttertoast.showToast(msg: "You can't gift yourself");
      return;
    }

    // Ensure the gift lands in the receiver's inbox (1-1 chat topic).
    if (_chatTopic == null || _chatTopic!.isEmpty) {
      try {
        final ChatTopicRoot topicRes = await ApiService.createChatTopic(
          myUserId: myUserId,
          otherUserId: receiverId,
        );
        if (topicRes.status && topicRes.topic?.isNotEmpty == true) {
          _chatTopic = topicRes.topic;
        } else {
          Fluttertoast.showToast(msg: 'Could not open chat for gift.');
          return;
        }
      } catch (e) {
        Log.e(_tag, 'createChatTopic failed', e);
        Fluttertoast.showToast(msg: 'Could not open chat for gift.');
        return;
      }
    }

    // Send a "profile visited" text message once in this session so the
    // receiver sees in their inbox that the gift came from a profile visit.
    if (_chatTopic != null && !_sentVisitMessage) {
      _sentVisitMessage = true;
      final now = DateTime.now().toUtc().toIso8601String();
      SocketService.instance.emit(Const.eventChat, {
        'senderId': myUserId,
        'receiverId': receiverId,
        'messageType': 'message',
        'topic': _chatTopic,
        'message': 'Visited your profile',
        'time': now,
        'status': 'sent',
      });
    }

    if (!mounted) return;
    GiftBottomSheet.show(
      context,
      receiverId: receiverId,
      type: 'chat',
      topic: _chatTopic,
      initialReceiverId: receiverId,
    );
  }

  /// Resolve VIP badge URL with same priority as native GuestActivity:
  /// 1. vipDetails.tagUrl  2. vipDetails.levelBadgeUrl  3. user.vipBadgeUrl
  String _resolveVipBadgeUrl(GuestUser u) {
    final vd = u.vipDetails;
    if (vd != null) {
      if (vd.tagUrl?.isNotEmpty == true) return vd.tagUrl!;
      if (vd.levelBadgeUrl?.isNotEmpty == true) return vd.levelBadgeUrl!;
    }
    if (u.vipBadgeUrl?.isNotEmpty == true) return u.vipBadgeUrl!;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Scaffold(body: Center(child: Preloader()))
        : _user == null
        ? Scaffold(body: _buildError())
        : _buildContent();
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'Could not load profile',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadProfile, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final u = _user!;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5FB),
      extendBodyBehindAppBar: true,
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        edgeOffset: 20,
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                _buildHeader(u),
                const SizedBox(height: 16),
                _buildStatsCard(u),
                const SizedBox(height: 16),
                _buildCPSection(u),
                const SizedBox(height: 16),
                _buildFriendsSection(u),
                const SizedBox(height: 16),
                _buildTabsSection(u),
                const SizedBox(height: 20),
              ],
            ),
            if (_isLive && _liveUser != null)
              Positioned(
                bottom: 80,
                left: 16,
                right: 16,
                child: _buildLiveBanner(_liveUser!),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildLiveBanner(LiveUser live) {
    return GestureDetector(
      onTap: _joinLiveRoom,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7E3FF2), Color(0xFF9C27B0)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7E3FF2).withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.topLeft,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: live.userImage ?? live.image ?? '',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget:
                        (_, __, ___) =>
                            const Icon(Icons.person, color: Colors.white),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    live.isAudio ? 'Chilling in Audio Room' : 'Live Now!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    live.roomName ?? 'Tap to join',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'JOIN',
                style: TextStyle(
                  color: Color(0xFF7E3FF2),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(GuestUser u) {
    // Prefer uploaded cover, then VIP profile background (if VIP).
    final bgUrl = VideoUtil.getFullImageUrl(
      u.coverImage?.isNotEmpty == true
          ? u.coverImage
          : (u.isVIP ? u.profileBackgroundImage : null),
    );
    final hasBg = bgUrl.isNotEmpty;
    return Stack(
      alignment: Alignment.topLeft,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
          decoration: BoxDecoration(
            image:
                hasBg
                    ? DecorationImage(
                      image: SafeImageProvider(bgUrl),
                      fit: BoxFit.cover,
                    )
                    : null,
            gradient:
                hasBg
                    ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    )
                    : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF7B61FF),
                        Color(0xFF6A5AE0),
                        Color(0xFF4F8DFD),
                      ],
                    ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(32),
            ),
          ),
          child: Stack(
            alignment: Alignment.topLeft,
            children: [
              // Decorative glow circles
              Positioned(
                top: -40,
                right: -30,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
              Positioned(
                top: 80,
                left: -50,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.pinkAccent.withValues(alpha: 0.12),
                  ),
                ),
              ),
              // Live wave rings
              if (_isLive) ...[
                const Positioned(
                  top: 60,
                  right: 60,
                  child: Opacity(
                    opacity: 0.5,
                    child: SeatPulseWave(size: 120, color: Color(0xFF00E5FF)),
                  ),
                ),
                const Positioned(
                  bottom: 20,
                  left: 30,
                  child: Opacity(
                    opacity: 0.5,
                    child: SeatPulseWave(size: 120, color: Color(0xFF00E676)),
                  ),
                ),
              ],
              SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 8),
                    _buildProfileRow(u),
                    const SizedBox(height: 18),
                    _buildMedalSlots(u),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          if (_isLive)
            GestureDetector(
              onTap: _joinLiveRoom,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.equalizer, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Room',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              final name = _user?.name ?? _user?.username ?? 'Belive User';
              final userId = _user?.id ?? '';
              final link = DeepLinkService.instance.generateProfileShareLink(
                userId: userId,
                name: name,
              );
              Share.share(
                'Check out $name on Belive!\n$link',
                subject: 'Belive - $name',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () => _showOptions(context, _user!),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(GuestUser u) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Glowing avatar with gradient ring (matches own profile)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFD700),
                  Color(0xFFFF6B9D),
                  Color(0xFF7B61FF),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B61FF).withValues(alpha: 0.5),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: GestureDetector(
              onTap: () => _showAvatarPopup(u),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Color(0xFF6A5AE0),
                  shape: BoxShape.circle,
                ),
                child: UserAvatar(
                  imageUrl: u.image,
                  frameUrl: u.avatarFrameImage,
                  size: 84,
                  isVIP: u.isVIP,
                  isVerified: u.isVerified,
                  vipBadgeUrl: _resolveVipBadgeUrl(u),
                  familyFrameUrl: u.familyImage,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // NAME — bold (smaller font for better fit)
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        u.name ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      u.gender == 'Female'
                          ? Icons.female_rounded
                          : Icons.male_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    // VIP badge image (native: vipDetails.tagUrl > vipBadgeUrl > levelBadgeUrl > user.vipBadgeUrl)
                    if (_resolveVipBadgeUrl(u).isNotEmpty) ...[
                      const SizedBox(width: 6),
                      CachedNetworkImage(
                        imageUrl: _resolveVipBadgeUrl(u),
                        width: 22,
                        height: 22,
                        fit: BoxFit.contain,
                        errorWidget:
                            (_, __, ___) => const Icon(
                              Icons.verified_rounded,
                              color: Color(0xFFFFD700),
                              size: 16,
                            ),
                      ),
                    ] else if (u.isVIP) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFFFFD700),
                        size: 16,
                      ),
                    ],
                    if (_isLive) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _joinLiveRoom,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                // ID + location on same row
                Row(
                  children: [
                    Text(
                      'ID: ${u.uniqueId ?? ''}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: u.uniqueId ?? ''),
                        );
                        Fluttertoast.showToast(msg: 'ID copied');
                      },
                      child: Icon(
                        Icons.copy_rounded,
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.location_on_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 14,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        u.country ?? 'India',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Rating stars
                Row(
                  children: [
                    ...List.generate(
                      5,
                      (i) => Padding(
                        padding: const EdgeInsets.only(right: 1),
                        child: Icon(
                          i < u.averageRating.round()
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: const Color(0xFFFFD700),
                          size: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${u.averageRating.toStringAsFixed(1)} (${u.totalRatings})',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Online/offline status — green dot + "Online" / "Offline"
                _buildOnlineStatus(u),
                // Manual profile tags (admin-assigned) — chips
                if (u.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildTagChips(u.tags),
                ],
                const SizedBox(height: 10),
                ProfileBadgeRow.fromGuestUser(
                  u,
                  isDark: true,
                  onFamilyTap: () {
                    final fid = u.familyId ?? '';
                    if (fid.isNotEmpty) {
                      context.pushNamed(
                        AppRoutes.familyDetail,
                        extra: {'familyId': fid},
                      );
                    } else {
                      context.pushNamed(AppRoutes.family);
                    }
                  },
                ),
              ],
            ),
          ),
          // Like & Gift buttons (circular, matching own profile)
          Column(
            children: [
              GestureDetector(
                onTap: _toggleProfileLike,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: Colors.pinkAccent,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${u.likeCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  _openGifts();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const ImageIcon(const AssetImage("assets/gift/official_gift.png"), color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Online/offline status indicator — green dot + "Online" or "Offline".
  Widget _buildOnlineStatus(GuestUser u) {
    final isOnline = u.isOnline || _isLive;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOnline ? const Color(0xFF34C759) : Colors.white38,
            boxShadow: isOnline
                ? [
                    BoxShadow(
                      color: const Color(0xFF34C759).withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          isOnline ? 'Online' : 'Offline',
          style: TextStyle(
            color: isOnline
                ? const Color(0xFF34C759)
                : Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Manual profile tags — admin-assigned chips (Admin, BD, Agency Owner, etc.)
  Widget _buildTagChips(List<AssignedTag> tags) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: tags.where((t) => t.name?.isNotEmpty == true).map((t) {
        final name = t.name!;
        final color = _tagColor(name);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_tagIcon(name), color: Colors.white, size: 11),
              const SizedBox(width: 3),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _tagColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('admin')) return const Color(0xFFFF3B30);
    if (lower.contains('bd')) return const Color(0xFF4F8DFD);
    if (lower.contains('agency')) return const Color(0xFF6A5AE0);
    if (lower.contains('seller')) return const Color(0xFFFFB800);
    if (lower.contains('host')) return const Color(0xFFFF6B9D);
    if (lower.contains('moderator') || lower.contains('mod')) return const Color(0xFF34C759);
    return const Color(0xFF8E8E93);
  }

  IconData _tagIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('admin')) return Icons.shield_rounded;
    if (lower.contains('bd')) return Icons.headset_mic_rounded;
    if (lower.contains('agency')) return Icons.business_rounded;
    if (lower.contains('seller')) return Icons.diamond_rounded;
    if (lower.contains('host')) return Icons.mic_rounded;
    if (lower.contains('moderator') || lower.contains('mod')) return Icons.gavel_rounded;
    return Icons.label_rounded;
  }

  Widget _buildMedalSlots(GuestUser u) {
    // Medal box should only show medals, not the user level tag.
    final medals = <String>[];
    if (u.vipBadgeUrl?.isNotEmpty == true) medals.add(u.vipBadgeUrl!);
    if (u.hostLevel?.image?.isNotEmpty == true) medals.add(u.hostLevel!.image!);
    for (final url in u.medals) {
      if (url.isNotEmpty && !medals.contains(url)) medals.add(url);
    }
    for (final url in u.achievements) {
      if (url.isNotEmpty && !medals.contains(url)) medals.add(url);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(8, (i) {
          final hasMedal = i < medals.length;
          return Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child:
                hasMedal
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: CachedNetworkImage(
                        imageUrl: medals[i],
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(Icons.shield, size: 16, color: Colors.white24),
                      ),
                    )
                    : null, // Empty slot — no icon, just empty
          );
        }),
      ),
    );
  }

  Widget _buildStatsCard(GuestUser u) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A5AE0).withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _statItem(
              u.followers,
              'Followers',
              Icons.group_rounded,
              const Color(0xFF7B61FF),
              () => context.pushNamed(
                AppRoutes.followersList,
                extra: {'type': 2, 'userId': u.id},
              ),
            ),
            _statDivider(),
            _statItem(
              u.following,
              'Following',
              Icons.person_add_rounded,
              const Color(0xFF4F8DFD),
              () => context.pushNamed(
                AppRoutes.followersList,
                extra: {'type': 1, 'userId': u.id},
              ),
            ),
            _statDivider(),
            _statItem(
              u.friends,
              'Friends',
              Icons.handshake_rounded,
              const Color(0xFF34C759),
              () => context.pushNamed(
                AppRoutes.followersList,
                extra: {'type': 3, 'userId': u.id},
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statDivider() =>
      Container(height: 28, width: 1, color: const Color(0xFFE8E8F0));

  Widget _statItem(
    int count,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 6),
            Text(
              formatCount(count),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9A9AB0),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// CP (Couple) section — shows the guest user's CP partner if they have one.
  Widget _buildCPSection(GuestUser u) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FutureBuilder(
        future: ApiService.getMyCP(u.id ?? ''),
        builder: (context, snap) {
          final cp = snap.data;
          final hasCP = cp?.status == true && cp!.data.isNotEmpty;
          final cpItem = hasCP ? cp.data.first : null;
          // Determine partner — the guest user is one side, partner is the other
          final partner = cpItem?.partner;
          final partnerName = partner?.name ?? 'Partner';
          final partnerImage = partner?.image ?? '';
          final cpLevel = cpItem?.level ?? 1;
          final bondPoints = cpItem?.intimacy ?? 0;

          return GestureDetector(
            onTap:
                hasCP
                    ? () => context.pushNamed(
                      AppRoutes.cpDetail,
                      extra: {'cpId': cpItem!.id},
                    )
                    : () => context.pushNamed(AppRoutes.cp),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF6B9D), Color(0xFF7B61FF)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B9D).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'CP Couple',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      if (hasCP)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Lv $cpLevel',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Partner avatar
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child:
                              partnerImage.isNotEmpty
                                  ? CachedNetworkImage(
                                    imageUrl: partnerImage,
                                    fit: BoxFit.cover,
                                    errorWidget:
                                        (_, __, ___) => Container(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          child: const Icon(
                                            Icons.person,
                                            color: Colors.white,
                                          ),
                                        ),
                                  )
                                  : Container(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    ),
                                  ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasCP ? partnerName : 'Not in a CP',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (hasCP) ...[
                              const SizedBox(height: 4),
                              // Bond progress bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (bondPoints % 1000) / 1000,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.2,
                                  ),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                  minHeight: 4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$bondPoints bond points',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 10,
                                ),
                              ),
                            ] else
                              Text(
                                'Tap to find your couple',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white70,
                        size: 24,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Friends section — shows a horizontal list of friends with a "view all" button.
  Widget _buildFriendsSection(GuestUser u) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A5AE0).withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF34C759), Color(0xFF30D158)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.handshake_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Friends',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap:
                      () => context.pushNamed(
                        AppRoutes.followersList,
                        extra: {'type': 3, 'userId': u.id},
                      ),
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF6A5AE0).withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF6A5AE0),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Friend avatars row — fetch from followers list
            FutureBuilder<FollowersRoot>(
              future:
                  _friendsFuture ??
                  ApiService.friendsList(
                    userId: u.id ?? '',
                    start: 0,
                    limit: 10,
                  ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 60,
                    child: Center(
                      child: Preloader(
                        strokeWidth: 2,
                        color: Color(0xFF6A5AE0),
                      ),
                    ),
                  );
                }
                final friends = snap.data?.users ?? [];
                if (friends.isEmpty) {
                  return SizedBox(
                    height: 60,
                    child: Center(
                      child: Text(
                        'No friends yet',
                        style: TextStyle(
                          color: const Color(0xFF9A9AB0).withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }
                return SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: friends.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final f = friends[i];
                      return GestureDetector(
                        onTap:
                            () => context.pushNamed(
                              AppRoutes.guestProfile,
                              extra: {'userId': f.id},
                            ),
                        child: Column(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(
                                    0xFF6A5AE0,
                                  ).withValues(alpha: 0.2),
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child:
                                    (f.image?.isNotEmpty == true)
                                        ? CachedNetworkImage(
                                          imageUrl: f.image!,
                                          fit: BoxFit.cover,
                                          errorWidget:
                                              (_, __, ___) => Container(
                                                color: const Color(0xFFF1F1FA),
                                                child: const Icon(
                                                  Icons.person,
                                                  color: Color(0xFF9A9AB0),
                                                  size: 20,
                                                ),
                                              ),
                                        )
                                        : Container(
                                          color: const Color(0xFFF1F1FA),
                                          child: const Icon(
                                            Icons.person,
                                            color: Color(0xFF9A9AB0),
                                            size: 20,
                                          ),
                                        ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              f.name ?? 'User',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF9A9AB0),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabsSection(GuestUser u) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A5AE0).withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            TabBar(
              controller: _tabCtrl,
              labelColor: const Color(0xFF6A5AE0),
              unselectedLabelColor: const Color(0xFF9A9AB0),
              indicatorColor: const Color(0xFF6A5AE0),
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 3,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tabs: const [
                Tab(text: 'About'),
                Tab(text: 'Honor'),
                Tab(text: 'Posts'),
              ],
            ),
            SizedBox(
              height: 420,
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildAboutTab(u),
                  _HonorTab(userId: u.id, user: u),
                  _PostsTab(userId: u.id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutTab(GuestUser u) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _infoRow(Icons.info_outline_rounded, u.bio ?? 'No bio set'),
        const SizedBox(height: 12),
        _infoRow(Icons.calendar_today_rounded, u.birthDate ?? 'Not set'),
        const SizedBox(height: 12),
        _infoRow(Icons.location_on_outlined, u.country ?? 'India'),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6A5AE0), size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient:
                      _isFollow
                          ? null
                          : const LinearGradient(
                            colors: [Color(0xFF7E3FF2), Color(0xFF5B2DD6)],
                          ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow:
                      !_isFollow
                          ? [
                            BoxShadow(
                              color: const Color(
                                0xFF7E3FF2,
                              ).withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ]
                          : null,
                ),
                child: ElevatedButton(
                  onPressed: _followLoading ? null : _toggleFollow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: _isFollow ? Colors.black87 : Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child:
                      _followLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Preloader(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : Text(_isFollow ? 'Unfollow' : '+ Follow'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.green),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (_user?.id != null) {
                      context.pushNamed(
                        AppRoutes.chatDetail,
                        extra: {
                          'otherUserId': _user!.id,
                          'otherUserName': _user!.name ?? 'User',
                        },
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                    color: Colors.green,
                  ),
                  label: const Text(
                    'Message',
                    style: TextStyle(color: Colors.green),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _callButton(
              Icons.videocam,
              Colors.purple,
              () => startCall(
                context,
                otherUserId: _user?.id ?? widget.userId ?? '',
                isAudioCall: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _callButton(IconData icon, Color color, VoidCallback onTap) {
    // Call rate: customCallRate takes priority, fallback to hostLevel.coin
    final callRate =
        _user?.customCallRate?.toInt() ?? (_user?.hostLevel?.coin.toInt() ?? 0);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: IconButton(
              onPressed: onTap,
              icon: Icon(icon, color: color),
              style: IconButton.styleFrom(backgroundColor: Colors.transparent),
            ),
          ),
          if (callRate > 0) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.diamond, size: 10, color: Colors.amber.shade600),
                const SizedBox(width: 2),
                Text(
                  '$callRate',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Avatar popup — tap avatar to view full image or enter live room.
  /// Ported from native `showAvatarPopup()`.
  void _showAvatarPopup(GuestUser u) {
    final imageUrl = u.image ?? '';
    final options = <Widget>[
      ListTile(
        leading: const Icon(Icons.zoom_out_map, color: Color(0xFF6A5AE0)),
        title: const Text('View Profile Picture'),
        onTap: () {
          Navigator.pop(context);
          if (imageUrl.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => _FullScreenImageScreen(
                      imageUrl: imageUrl,
                      name: u.name ?? 'Profile',
                    ),
              ),
            );
          }
        },
      ),
    ];
    if (_isLive && _liveUser != null) {
      options.add(
        ListTile(
          leading: const Icon(Icons.live_tv, color: Colors.red),
          title: const Text('Enter Live Room'),
          onTap: () {
            Navigator.pop(context);
            _joinLiveRoom();
          },
        ),
      );
    }
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: options),
          ),
    );
  }

  void _showOptions(BuildContext context, GuestUser u) {
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.red),
                  title: const Text('Block'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      final session = context.read<SessionManager>();
                      await ApiService.blockOrUnblockUser(
                        session.userId,
                        u.id ?? '',
                      );
                      Fluttertoast.showToast(msg: 'User blocked');
                    } catch (e) {
                      Fluttertoast.showToast(msg: 'Failed');
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.star_rate, color: Colors.amber),
                  title: const Text('Rate Host'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showRatingDialog(u);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.report_gmailerrorred,
                    color: Colors.orange,
                  ),
                  title: const Text('Report'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showReportDialog(u);
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _showReportDialog(GuestUser u) {
    final reasonCtrl = TextEditingController();
    final reasons = [
      'Harassment',
      'Spam',
      'Fake Account',
      'Inappropriate Content',
      'Other',
    ];
    String selectedReason = reasons[0];
    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (_, setState) => AlertDialog(
                  title: const Text('Report User'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...reasons.map(
                        (r) => RadioListTile<String>(
                          title: Text(r),
                          groupValue: selectedReason,
                          value: r,
                          onChanged:
                              (v) =>
                                  setState(() => selectedReason = v as String),
                        ),
                      ),
                      TextField(
                        controller: reasonCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Additional details (optional)',
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          final session = context.read<SessionManager>();
                          await ApiService.createComplaint(
                            userId: session.userId,
                            contactDetails: '',
                            issue: 'Report $selectedReason: ${reasonCtrl.text}',
                            proofImage: null,
                          );
                          Fluttertoast.showToast(msg: 'Reported');
                        } catch (e) {
                          Fluttertoast.showToast(msg: 'Failed');
                        }
                      },
                      child: const Text('Submit'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showRatingDialog(GuestUser u) async {
    int rating = u.userRating > 0 ? u.userRating : 5;
    double existingAvg = u.averageRating;
    int existingTotal = u.totalRatings;

    // Fetch fresh rating data
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.getHostRating(
        userId: session.userId,
        hostId: u.id ?? '',
      );
      if (res.status) {
        existingAvg = res.averageRating;
        existingTotal = res.totalRatings;
        if (res.userRating > 0) rating = res.userRating;
      }
    } catch (e) {
      Log.e(_tag, 'getHostRating failed', e);
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (_, setState) => AlertDialog(
                  title: const Text('Rate Host'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'How was your experience with ${u.name ?? 'this host'}?',
                      ),
                      if (existingTotal > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ...List.generate(
                              5,
                              (i) => Icon(
                                i < existingAvg.round()
                                    ? Icons.star
                                    : Icons.star_border,
                                color: const Color(0xFFFFD700),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${existingAvg.toStringAsFixed(1)} ($existingTotal)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          5,
                          (i) => IconButton(
                            icon: Icon(
                              i < rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 36,
                            ),
                            onPressed: () => setState(() => rating = i + 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          final session = context.read<SessionManager>();
                          await ApiService.submitHostRating(
                            userId: session.userId,
                            hostId: u.id ?? '',
                            rating: rating,
                          );
                          Fluttertoast.showToast(msg: 'Rating submitted');
                        } catch (e) {
                          Fluttertoast.showToast(
                            msg: 'Failed to submit rating',
                          );
                        }
                      },
                      child: const Text('Submit'),
                    ),
                  ],
                ),
          ),
    );
  }
}

class _HonorTab extends StatefulWidget {
  const _HonorTab({this.userId, this.user});
  final String? userId;
  final GuestUser? user;

  @override
  State<_HonorTab> createState() => _HonorTabState();
}

class _HonorTabState extends State<_HonorTab>
    with SingleTickerProviderStateMixin {
  static const String _tag = 'GuestHonorTab';
  late TabController _subTabCtrl;
  bool _loadingReceived = true;
  bool _loadingSent = true;
  List<_GiftSummary> _receivedGifts = [];
  List<_GiftSummary> _sentGifts = [];
  List<Map<String, dynamic>> _rawReceived = [];
  List<Map<String, dynamic>> _rawSent = [];

  @override
  void initState() {
    super.initState();
    _subTabCtrl = TabController(length: 2, vsync: this);
    _loadReceived();
    _loadSent();
  }

  @override
  void dispose() {
    _subTabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReceived() async {
    final userId = widget.userId;
    if (userId == null || userId.isEmpty) {
      if (mounted) setState(() => _loadingReceived = false);
      return;
    }
    try {
      final res = await ApiService.getReceivedGifts(userId, skip: 0, limit: 50);
      _rawReceived = _extractRawList(res);
      _receivedGifts = _summarize(_rawReceived);
    } catch (e) {
      Log.e(_tag, 'load received failed', e);
    } finally {
      if (mounted) setState(() => _loadingReceived = false);
    }
  }

  Future<void> _loadSent() async {
    final userId = widget.userId;
    if (userId == null || userId.isEmpty) {
      if (mounted) setState(() => _loadingSent = false);
      return;
    }
    try {
      final res = await ApiService.getSentGifts(userId, skip: 0, limit: 50);
      _rawSent = _extractRawList(res);
      _sentGifts = _summarize(_rawSent);
    } catch (e) {
      Log.e(_tag, 'load sent failed', e);
    } finally {
      if (mounted) setState(() => _loadingSent = false);
    }
  }

  List<Map<String, dynamic>> _extractRawList(Map<String, dynamic> res) {
    final raw = res['gift'] ?? res['data'] ?? res['history'];
    if (raw is! List) return [];
    final out = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        out.add(item);
      } else if (item is Map) {
        out.add(Map<String, dynamic>.from(item));
      }
    }
    return out;
  }

  List<_GiftSummary> _summarize(List<Map<String, dynamic>> raw) {
    final byId = <String, _GiftSummary>{};
    for (final item in raw) {
      final id =
          item['_id']?.toString() ??
          item['giftId']?.toString() ??
          item['gift']?['_id']?.toString() ??
          item['id']?.toString() ??
          '';
      final rawImage =
          item['image']?.toString() ??
          item['giftImage']?.toString() ??
          item['gift']?['image']?.toString() ??
          '';
      final image = VideoUtil.getFullImageUrl(rawImage);
      final name =
          item['name']?.toString() ??
          item['giftName']?.toString() ??
          item['gift']?['name']?.toString() ??
          'Gift';
      final count = parseInt(item['count'] ?? item['quantity'], 1);
      final key = id.isNotEmpty ? id : image;
      if (key.isEmpty) continue;
      final existing = byId[key];
      if (existing != null) {
        existing.count += count;
      } else {
        byId[key] = _GiftSummary(
          id: id,
          name: name,
          image: image,
          count: count,
        );
      }
    }
    final list = byId.values.toList();
    list.sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-tab bar: Received | Sent
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F1FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _subTabCtrl,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [Color(0xFF7B61FF), Color(0xFF4F8DFD)],
              ),
            ),
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF6B6B80),
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            padding: const EdgeInsets.all(3),
            tabs: const [Tab(text: 'Gifts Received'), Tab(text: 'Gifts Sent')],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _subTabCtrl,
            children: [
              _buildGiftGrid(
                _receivedGifts,
                _loadingReceived,
                'No gifts received yet',
                isReceived: true,
              ),
              _buildGiftGrid(
                _sentGifts,
                _loadingSent,
                'No gifts sent yet',
                isReceived: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openGiftDetail(_GiftSummary gift, {required bool isReceived}) {
    final raw = isReceived ? _rawReceived : _rawSent;
    final senders = _filterSendersForGift(raw, gift, isReceived: isReceived);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => _GuestGiftDetailScreen(
              gift: gift,
              senders: senders,
              isReceived: isReceived,
            ),
      ),
    );
  }

  List<_GuestGiftSender> _filterSendersForGift(
    List<Map<String, dynamic>> raw,
    _GiftSummary gift, {
    required bool isReceived,
  }) {
    final byUser = <String, _GuestGiftSender>{};
    for (final item in raw) {
      final gid =
          item['_id']?.toString() ??
          item['giftId']?.toString() ??
          item['gift']?['_id']?.toString() ??
          item['id']?.toString() ??
          '';
      final rawGimg =
          item['image']?.toString() ??
          item['giftImage']?.toString() ??
          item['gift']?['image']?.toString() ??
          '';
      final gimg = VideoUtil.getFullImageUrl(rawGimg);
      final matches =
          (gid.isNotEmpty && gid == gift.id) ||
          (gimg.isNotEmpty && gimg == gift.image);
      if (!matches) continue;

      final otherKey = isReceived ? 'sender' : 'receiver';
      final name =
          item['${otherKey}Name']?.toString() ??
          item[otherKey]?['name']?.toString() ??
          item['user']?['name']?.toString() ??
          item['userName']?.toString() ??
          item['name']?.toString() ??
          'User';
      final rawOtherImage =
          item['${otherKey}Image']?.toString() ??
          item[otherKey]?['image']?.toString() ??
          item['user']?['image']?.toString() ??
          item['userImage']?.toString() ??
          '';
      final image = VideoUtil.getFullImageUrl(rawOtherImage);
      final userId =
          item['${otherKey}Id']?.toString() ??
          item[otherKey]?['_id']?.toString() ??
          item[otherKey]?['id']?.toString() ??
          item['userId']?.toString() ??
          item['user']?['_id']?.toString() ??
          '';
      final count = parseInt(item['count'] ?? item['quantity'], 1);
      final key = userId.isNotEmpty ? userId : name;
      final existing = byUser[key];
      if (existing != null) {
        existing.count += count;
      } else {
        byUser[key] = _GuestGiftSender(
          name: name,
          image: image,
          count: count,
          userId: userId,
        );
      }
    }
    final list = byUser.values.toList();
    list.sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  Widget _buildGiftGrid(
    List<_GiftSummary> gifts,
    bool loading,
    String emptyMsg, {
    required bool isReceived,
  }) {
    if (loading) {
      return const Center(
        child: Preloader(strokeWidth: 2, color: Color(0xFF6A5AE0)),
      );
    }
    if (gifts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ImageIcon(const AssetImage("assets/gift/official_gift.png"), color: const Color(0xFF6A5AE0).withValues(alpha: 0.25), size: 44),
            const SizedBox(height: 8),
            Text(
              emptyMsg,
              style: const TextStyle(color: Color(0xFF9A9AB0), fontSize: 12),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: gifts.length,
      itemBuilder: (_, i) {
        final g = gifts[i];
        return GestureDetector(
          onTap: () => _openGiftDetail(g, isReceived: isReceived),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.topLeft,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF6A5AE0).withValues(alpha: 0.1),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: VideoUtil.getFullImageUrl(g.image),
                          fit: BoxFit.contain,
                          placeholder:
                              (_, __) => const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: Preloader(
                                    strokeWidth: 1.5,
                                    color: Color(0xFF6A5AE0),
                                  ),
                                ),
                              ),
                          errorWidget:
                              (_, __, ___) => const ImageIcon(const AssetImage("assets/gift/official_gift.png"), color: Color(0xFF9A9AB0)),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7B61FF), Color(0xFF4F8DFD)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${g.count}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                g.name,
                style: const TextStyle(fontSize: 10, color: Color(0xFF9A9AB0)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GiftSummary {
  _GiftSummary({
    required this.id,
    required this.name,
    required this.image,
    required this.count,
  });
  final String id;
  final String name;
  final String image;
  int count;
}

class _GuestGiftSender {
  String name;
  final String image;
  int count;
  final String userId;
  _GuestGiftSender({
    required this.name,
    required this.image,
    required this.count,
    required this.userId,
  });
}

class _FullScreenImageScreen extends StatelessWidget {
  const _FullScreenImageScreen({required this.imageUrl, required this.name});
  final String imageUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(name),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder:
                  (_, __) =>
                      const Center(child: Preloader(color: Colors.white)),
              errorWidget:
                  (_, __, ___) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 64,
                      color: Colors.white54,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gift detail screen for guest profile — shows who sent/received this gift.
class _GuestGiftDetailScreen extends StatelessWidget {
  const _GuestGiftDetailScreen({
    required this.gift,
    required this.senders,
    required this.isReceived,
  });
  final _GiftSummary gift;
  final List<_GuestGiftSender> senders;
  final bool isReceived;

  @override
  Widget build(BuildContext context) {
    final title = isReceived ? 'Received From' : 'Sent To';
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5FB),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF6A5AE0),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Gift header card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B61FF), Color(0xFF4F8DFD)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6A5AE0).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      imageUrl: VideoUtil.getFullImageUrl(gift.image),
                      fit: BoxFit.contain,
                      errorWidget:
                          (_, __, ___) => const ImageIcon(const AssetImage("assets/gift/official_gift.png"), color: Color(0xFF6A5AE0)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gift.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Total: ${gift.count}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                senders.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_search_rounded,
                            size: 48,
                            color: const Color(
                              0xFF6A5AE0,
                            ).withValues(alpha: 0.25),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isReceived
                                ? 'No sender details available'
                                : 'No receiver details available',
                            style: const TextStyle(
                              color: Color(0xFF9A9AB0),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: senders.length,
                      itemBuilder:
                          (_, i) => _guestSenderCard(senders[i], i + 1),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _guestSenderCard(_GuestGiftSender sender, int rank) {
    Color rankColor;
    IconData rankIcon;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700);
      rankIcon = Icons.emoji_events_rounded;
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0);
      rankIcon = Icons.emoji_events_rounded;
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32);
      rankIcon = Icons.emoji_events_rounded;
    } else {
      rankColor = const Color(0xFF6A5AE0);
      rankIcon = Icons.label_important_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A5AE0).withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [rankColor, rankColor.withValues(alpha: 0.7)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(rankIcon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF6A5AE0).withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: ClipOval(
              child:
                  sender.image.isNotEmpty
                      ? CachedNetworkImage(
                        imageUrl: VideoUtil.getFullImageUrl(sender.image),
                        fit: BoxFit.cover,
                        errorWidget:
                            (_, __, ___) => Container(
                              color: const Color(0xFFF1F1FA),
                              child: const Icon(
                                Icons.person,
                                color: Color(0xFF9A9AB0),
                                size: 22,
                              ),
                            ),
                      )
                      : Container(
                        color: const Color(0xFFF1F1FA),
                        child: const Icon(
                          Icons.person,
                          color: Color(0xFF9A9AB0),
                          size: 22,
                        ),
                      ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              sender.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B61FF), Color(0xFF4F8DFD)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'x${sender.count}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostsTab extends StatefulWidget {
  const _PostsTab({this.userId});
  final String? userId;

  @override
  State<_PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<_PostsTab> {
  bool _loading = true;
  final _posts = <dynamic>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.userId == null || widget.userId!.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final res = await ApiService.getUserPosts(
        userId: widget.userId!,
        limit: 30,
      );
      _posts.addAll(res.post);
    } catch (e) {
      Log.e('PostsTab', 'load failed', e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: Preloader(strokeWidth: 2));
    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('No posts yet', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _posts.length,
      itemBuilder: (_, i) {
        final post = _posts[i];
        String image = '';
        if (post is Map) {
          image =
              post['image']?.toString() ?? post['postImage']?.toString() ?? '';
        } else if (post is PostItem) {
          image = post.post ?? '';
        }
        return GestureDetector(
          onTap: () {
            if (image.isNotEmpty) {
              context.pushNamed(AppRoutes.imagePreview, extra: {'url': image});
            }
          },
          child: CachedNetworkImage(
            imageUrl: image,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: Colors.grey.shade100),
            errorWidget:
                (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image, color: Colors.grey),
                ),
          ),
        );
      },
    );
  }
}
