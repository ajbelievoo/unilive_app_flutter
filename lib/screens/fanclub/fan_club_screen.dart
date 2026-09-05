library belive.screens.fanclub.fan_club_screen;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../utils/media_utils.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../utils/log.dart';

/// Represents a single benefit or privilege granted to fan club members.
class FanClubBenefit {
  const FanClubBenefit({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.minLevel,
  });

  final String id;
  final String title;
  final String description;

  /// Name of a Material icon to display (e.g. "star", "shield").
  final String iconName;

  /// Minimum fan club level required to unlock this benefit.
  final int minLevel;

  factory FanClubBenefit.fromJson(Map<String, dynamic> json) {
    return FanClubBenefit(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      iconName: json['iconName'] as String? ?? 'star',
      minLevel: (json['minLevel'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'description': description,
    'iconName': iconName,
    'minLevel': minLevel,
  };
}

/// Represents a fan club member and their contribution rank.
class FanClubMember {
  const FanClubMember({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.contribution,
    required this.rank,
    required this.level,
  });

  final String id;
  final String name;
  final String avatarUrl;
  final int contribution;
  final int rank;
  final int level;

  factory FanClubMember.fromJson(Map<String, dynamic> json) {
    return FanClubMember(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String? ?? '',
      contribution: (json['contribution'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'avatarUrl': avatarUrl,
    'contribution': contribution,
    'rank': rank,
    'level': level,
  };
}

/// Model class describing a fan club.
class FanClub {
  const FanClub({
    required this.id,
    required this.name,
    required this.hostUserId,
    required this.hostName,
    required this.hostAvatarUrl,
    required this.level,
    required this.memberCount,
    required this.totalContribution,
    required this.benefits,
    required this.members,
    required this.coverUrl,
  });

  final String id;
  final String name;
  final String hostUserId;
  final String hostName;
  final String hostAvatarUrl;
  final String coverUrl;
  final int level;
  final int memberCount;
  final int totalContribution;
  final List<FanClubBenefit> benefits;
  final List<FanClubMember> members;

  factory FanClub.fromJson(Map<String, dynamic> json) {
    return FanClub(
      id: json['id'] as String,
      name: json['name'] as String,
      hostUserId: json['hostUserId'] as String,
      hostName: json['hostName'] as String? ?? '',
      hostAvatarUrl: json['hostAvatarUrl'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      level: (json['level'] as num?)?.toInt() ?? 1,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      totalContribution: (json['totalContribution'] as num?)?.toInt() ?? 0,
      benefits:
          (json['benefits'] as List<dynamic>? ?? <dynamic>[])
              .map(
                (dynamic e) =>
                    FanClubBenefit.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
      members:
          (json['members'] as List<dynamic>? ?? <dynamic>[])
              .map(
                (dynamic e) =>
                    FanClubMember.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'hostUserId': hostUserId,
    'hostName': hostName,
    'hostAvatarUrl': hostAvatarUrl,
    'coverUrl': coverUrl,
    'level': level,
    'memberCount': memberCount,
    'totalContribution': totalContribution,
    'benefits': benefits.map((FanClubBenefit b) => b.toJson()).toList(),
    'members': members.map((FanClubMember m) => m.toJson()).toList(),
  };
}

const String _tag = 'FanClubScreen';

/// Screen that displays the fan club system for a host.
///
/// Shows a header with club name, level, and member count, a list of
/// benefits/privileges, a ranked member list with contribution values, and
/// join/support buttons.
class FanClubScreen extends StatefulWidget {
  const FanClubScreen({
    super.key,
    this.fanClubId,
    this.hostUserId = '',
    this.isMember = false,
  });

  final String? fanClubId;
  final String hostUserId;
  final bool isMember;

  @override
  State<FanClubScreen> createState() => _FanClubScreenState();
}

class _FanClubScreenState extends State<FanClubScreen> {
  late bool _isMember;
  bool _loading = false;
  FanClub? _remoteClub;

  @override
  void initState() {
    super.initState();
    _isMember = widget.isMember;
    Log.d(_tag, 'FanClubScreen: init fanClubId=${widget.fanClubId}');
    _fetchFanClub();
  }

  Future<void> _fetchFanClub() async {
    if (widget.hostUserId.isEmpty) return;
    if (mounted) setState(() => _loading = true);
    try {
      final data = await ApiService.getFanClub(hostUserId: widget.hostUserId);
      if (data != null && mounted) {
        setState(() {
          _remoteClub = FanClub.fromJson(data);
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      Log.e(_tag, 'fetchFanClub failed', e);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinClub() async {
    final session = context.read<SessionManager>();
    final res = await ApiService.joinFanClub(
      hostUserId: widget.hostUserId,
      userId: session.userId,
    );
    if (res.status) {
      setState(() => _isMember = true);
      _fetchFanClub();
    } else {
      Fluttertoast.showToast(msg: res.message ?? 'Failed to join');
    }
  }

  // ---- Sample data ---------------------------------------------------------

  static const FanClub _sampleClub = FanClub(
    id: 'fc1',
    name: 'Starlight Squad',
    hostUserId: 'u100',
    hostName: 'Aurora',
    hostAvatarUrl: 'https://picsum.photos/seed/host/200/200',
    coverUrl: 'https://picsum.photos/seed/cover/800/300',
    level: 12,
    memberCount: 8420,
    totalContribution: 1250000,
    benefits: <FanClubBenefit>[
      FanClubBenefit(
        id: 'b1',
        title: 'Exclusive Badge',
        description: 'Show off a unique fan badge next to your name.',
        iconName: 'military_tech',
        minLevel: 1,
      ),
      FanClubBenefit(
        id: 'b2',
        title: 'Priority Chat',
        description: 'Your messages get highlighted in the host\'s room.',
        iconName: 'chat',
        minLevel: 3,
      ),
      FanClubBenefit(
        id: 'b3',
        title: 'Exclusive Emotes',
        description: 'Unlock custom emotes only available to club members.',
        iconName: 'emoji_emotions',
        minLevel: 5,
      ),
      FanClubBenefit(
        id: 'b4',
        title: 'Meet & Greet',
        description: 'Get invited to private video sessions with the host.',
        iconName: 'groups',
        minLevel: 10,
      ),
    ],
    members: <FanClubMember>[
      FanClubMember(
        id: 'm1',
        name: 'TopFan01',
        avatarUrl: 'https://picsum.photos/seed/m1/100/100',
        contribution: 320000,
        rank: 1,
        level: 15,
      ),
      FanClubMember(
        id: 'm2',
        name: 'SuperSupporter',
        avatarUrl: 'https://picsum.photos/seed/m2/100/100',
        contribution: 210000,
        rank: 2,
        level: 13,
      ),
      FanClubMember(
        id: 'm3',
        name: 'LoyalViewer',
        avatarUrl: 'https://picsum.photos/seed/m3/100/100',
        contribution: 150000,
        rank: 3,
        level: 11,
      ),
      FanClubMember(
        id: 'm4',
        name: 'GiftGiver',
        avatarUrl: 'https://picsum.photos/seed/m4/100/100',
        contribution: 95000,
        rank: 4,
        level: 9,
      ),
      FanClubMember(
        id: 'm5',
        name: 'FanForLife',
        avatarUrl: 'https://picsum.photos/seed/m5/100/100',
        contribution: 60000,
        rank: 5,
        level: 7,
      ),
    ],
  );

  // ---- Handlers ------------------------------------------------------------

  Future<void> _onJoinPressed() async {
    Log.d(_tag, 'FanClubScreen: join pressed');
    setState(() => _loading = true);
    try {
      // TODO: Replace with real API call to join the fan club.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        setState(() {
          _isMember = true;
          _loading = false;
        });
        _showSnackBar('Welcome to ${_sampleClub.name}!');
      }
    } catch (e, st) {
      Log.e(_tag, 'FanClubScreen: join failed', e, st);
      if (mounted) {
        setState(() => _loading = false);
        _showSnackBar('Failed to join. Please try again.');
      }
    }
  }

  void _onSupportPressed() {
    Log.d(_tag, 'FanClubScreen: support pressed');
    context.push('/fanclub/${_sampleClub.id}/support');
  }

  void _onViewHostProfile() {
    Log.d(_tag, 'FanClubScreen: view host ${_sampleClub.hostUserId}');
    context.push('/profile/${_sampleClub.hostUserId}');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // ---- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    const FanClub club = _sampleClub;

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                club.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              background: Stack(
                alignment: Alignment.topLeft,
                fit: StackFit.expand,
                children: <Widget>[
                  CachedNetworkImage(
                    imageUrl: club.coverUrl,
                    fit: BoxFit.cover,
                    placeholder:
                        (BuildContext context, String url) => Container(
                          color: colorScheme.surfaceContainerHighest,
                        ),
                    errorWidget:
                        (BuildContext context, String url, Object error) =>
                            Container(
                              color: colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.broken_image,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                ),
                                size: 40,
                              ),
                            ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _FanClubHeader(
              club: club,
              isMember: _isMember,
              loading: _loading,
              onJoin: _onJoinPressed,
              onSupport: _onSupportPressed,
              onViewHost: _onViewHostProfile,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ),
          SliverToBoxAdapter(
            child: _BenefitsSection(
              club: club,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ),
          SliverToBoxAdapter(
            child: _MembersSection(
              club: club,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ---- Header ----------------------------------------------------------------

class _FanClubHeader extends StatelessWidget {
  const _FanClubHeader({
    required this.club,
    required this.isMember,
    required this.loading,
    required this.onJoin,
    required this.onSupport,
    required this.onViewHost,
    required this.colorScheme,
    required this.textTheme,
  });

  final FanClub club;
  final bool isMember;
  final bool loading;
  final VoidCallback onJoin;
  final VoidCallback onSupport;
  final VoidCallback onViewHost;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              GestureDetector(
                onTap: onViewHost,
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  backgroundImage:
                      club.hostAvatarUrl.isNotEmpty
                          ? CachedNetworkImageProvider(club.hostAvatarUrl)
                          : null,
                  child:
                      club.hostAvatarUrl.isEmpty
                          ? Icon(Icons.person, color: colorScheme.primary)
                          : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      club.hostName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Host',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              _LevelBadge(level: club.level, colorScheme: colorScheme),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              _StatChip(
                icon: Icons.people,
                label: 'Members',
                value: _formatCount(club.memberCount),
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const SizedBox(width: 12),
              _StatChip(
                icon: Icons.favorite,
                label: 'Contribution',
                value: _formatCount(club.totalContribution),
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child:
                    isMember
                        ? FilledButton.icon(
                          onPressed: loading ? null : onSupport,
                          icon: const Icon(Icons.favorite, size: 18),
                          label: const Text('Support'),
                        )
                        : FilledButton(
                          onPressed: loading ? null : onJoin,
                          child:
                              loading
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Text('Join Fan Club'),
                        ),
              ),
              if (isMember) const SizedBox(width: 12),
              if (isMember)
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSupport,
                    child: const Text('Send Gift'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level, required this.colorScheme});

  final int level;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[colorScheme.primary, colorScheme.tertiary],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.military_tech, color: colorScheme.onPrimary, size: 16),
          const SizedBox(width: 4),
          Text(
            'Lv.$level',
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.colorScheme,
    required this.textTheme,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    value,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    label,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Benefits section ------------------------------------------------------

class _BenefitsSection extends StatelessWidget {
  const _BenefitsSection({
    required this.club,
    required this.colorScheme,
    required this.textTheme,
  });

  final FanClub club;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Benefits & Privileges',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final FanClubBenefit benefit in club.benefits)
            _BenefitTile(
              benefit: benefit,
              currentLevel: club.level,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
        ],
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({
    required this.benefit,
    required this.currentLevel,
    required this.colorScheme,
    required this.textTheme,
  });

  final FanClubBenefit benefit;
  final int currentLevel;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final bool unlocked = currentLevel >= benefit.minLevel;
    final IconData icon = _iconForName(benefit.iconName);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
                  unlocked
                      ? colorScheme.primary.withValues(alpha: 0.12)
                      : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color:
                  unlocked
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.4),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        benefit.title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color:
                              unlocked
                                  ? textTheme.titleSmall?.color
                                  : colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!unlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Lv.${benefit.minLevel}+',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  benefit.description,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          if (unlocked)
            Icon(Icons.check_circle, color: colorScheme.primary, size: 20),
        ],
      ),
    );
  }

  IconData _iconForName(String name) {
    switch (name) {
      case 'military_tech':
        return Icons.military_tech;
      case 'chat':
        return Icons.chat;
      case 'emoji_emotions':
        return Icons.emoji_emotions;
      case 'groups':
        return Icons.groups;
      case 'star':
        return Icons.star;
      case 'shield':
        return Icons.shield;
      case 'diamond':
        return Icons.diamond;
      default:
        return Icons.star;
    }
  }
}

// ---- Members section -------------------------------------------------------

class _MembersSection extends StatelessWidget {
  const _MembersSection({
    required this.club,
    required this.colorScheme,
    required this.textTheme,
  });

  final FanClub club;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Top Members',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  Log.d(_tag, 'FanClubScreen: view all members');
                  context.push('/fanclub/${club.id}/members');
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final FanClubMember member in club.members)
            _MemberTile(
              member: member,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.colorScheme,
    required this.textTheme,
  });

  final FanClubMember member;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 28,
            child: _RankBadge(rank: member.rank, colorScheme: colorScheme),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.surfaceContainerHighest,
            backgroundImage:
                member.avatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(member.avatarUrl)
                    : null,
            child:
                member.avatarUrl.isEmpty
                    ? Icon(Icons.person, color: colorScheme.primary, size: 18)
                    : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Lv.${member.level}',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                _formatContribution(member.contribution),
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
              Text(
                'contribution',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatContribution(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, required this.colorScheme});

  final int rank;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (rank) {
      1 => const Color(0xFFFFD700), // gold
      2 => const Color(0xFFC0C0C0), // silver
      3 => const Color(0xFFCD7F32), // bronze
      _ => colorScheme.onSurface.withValues(alpha: 0.4),
    };

    if (rank <= 3) {
      return Icon(Icons.emoji_events, color: color, size: 22);
    }
    return Text(
      '#$rank',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: colorScheme.onSurface.withValues(alpha: 0.6),
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }
}
