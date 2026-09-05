import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../constants/const.dart';
import '../../models/chat_root.dart';
import '../../models/chat_user_list_root.dart';
import '../../models/level_summary_models.dart';
import '../../models/reel_root.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

class HostLevelListScreen extends StatefulWidget {
  const HostLevelListScreen({super.key});

  @override
  State<HostLevelListScreen> createState() => _HostLevelListScreenState();
}

class _HostLevelListScreenState extends State<HostLevelListScreen> {
  static const String _tag = 'HostLevelList';
  final _levels = <HostLevelItem>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getHostLevels();
      if (res.status) {
        _levels.clear();
        _levels.addAll(res.hostLevel);
      }
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Host Levels'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        ),
      ),
      body:
          _loading
              ? const Center(child: Preloader())
              : _levels.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_border, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No host levels found',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _levels.length,
                  itemBuilder: (_, i) {
                    final lv = _levels[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primary.withValues(alpha: 0.08),
                            AppTheme.secondary.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.surfaceVariant),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        leading: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.purpleGradient,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child:
                              lv.image != null && lv.image!.isNotEmpty
                                  ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: lv.image!,
                                      fit: BoxFit.cover,
                                      errorWidget:
                                          (_, __, ___) => Center(
                                            child: Text(
                                              '${i + 1}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                    ),
                                  )
                                  : Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                        ),
                        title: Text(
                          lv.name ?? 'Host Level ${i + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            const Icon(
                              Icons.diamond,
                              size: 14,
                              color: Color(0xFFFFB800),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${lv.coin} diamonds',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, color: Colors.white, size: 14),
                              SizedBox(width: 2),
                              Text(
                                'Lv',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}

class TalentLevelScreen extends StatefulWidget {
  const TalentLevelScreen({super.key});

  @override
  State<TalentLevelScreen> createState() => _TalentLevelScreenState();
}

class _TalentLevelScreenState extends State<TalentLevelScreen> {
  static const String _tag = 'TalentLevel';
  final _levels = <LevelItem>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getLevels();
      if (res.status) {
        _levels.clear();
        _levels.addAll(res.level);
      }
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Talent Levels'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.purpleGradient),
        ),
      ),
      body:
          _loading
              ? const Center(child: Preloader())
              : _levels.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.emoji_events_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No talent levels found',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _levels.length,
                  itemBuilder: (_, i) {
                    final lv = _levels[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF9B6BFF).withValues(alpha: 0.08),
                            const Color(0xFF6A5AE0).withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.surfaceVariant),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        leading: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF9B6BFF), Color(0xFF6A5AE0)],
                            ),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF6A5AE0,
                                ).withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child:
                              lv.image != null && lv.image!.isNotEmpty
                                  ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: lv.image!,
                                      fit: BoxFit.cover,
                                      errorWidget:
                                          (_, __, ___) => Center(
                                            child: Text(
                                              '${i + 1}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                    ),
                                  )
                                  : Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                        ),
                        title: Text(
                          lv.name ?? 'Talent Level ${i + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            const Icon(
                              Icons.diamond,
                              size: 14,
                              color: Color(0xFF34C759),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${lv.coin} diamonds spent',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF9B6BFF), Color(0xFF6A5AE0)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.emoji_events,
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 2),
                              Text(
                                'Lv',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}

class WearMedalScreen extends StatelessWidget {
  const WearMedalScreen({super.key, required this.medals});

  final List<Map<String, dynamic>> medals;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Medals'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        ),
      ),
      body:
          medals.isEmpty
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.military_tech_outlined,
                      size: 72,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No medals earned yet',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Complete tasks to earn medals',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              )
              : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: medals.length,
                itemBuilder: (_, i) {
                  final medal = medals[i];
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, medal),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primary.withValues(alpha: 0.1),
                            AppTheme.secondary.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.purpleGradient,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: ClipOval(
                              child:
                                  medal['image'] != null &&
                                          (medal['image'] as String).isNotEmpty
                                      ? CachedNetworkImage(
                                        imageUrl: medal['image'],
                                        fit: BoxFit.cover,
                                        errorWidget:
                                            (_, __, ___) => const Icon(
                                              Icons.military_tech,
                                              color: Colors.white,
                                              size: 30,
                                            ),
                                      )
                                      : const Icon(
                                        Icons.military_tech,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            medal['name'] ?? 'Medal',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Wear',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

class ChatImageFullScreen extends StatelessWidget {
  const ChatImageFullScreen({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () => Share.share(imageUrl),
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Share',
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.topLeft,
        fit: StackFit.expand,
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder:
                    (_, __) =>
                        const Center(child: Preloader(color: Colors.white)),
                errorWidget:
                    (_, __, ___) => const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 72,
                          color: Colors.white54,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _actionButton(
                    Icons.share,
                    'Share',
                    () => Share.share(imageUrl),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class ForwardUserListScreen extends StatefulWidget {
  const ForwardUserListScreen({super.key, this.forwardItem});

  final ChatItem? forwardItem;

  @override
  State<ForwardUserListScreen> createState() => _ForwardUserListScreenState();
}

class _ForwardUserListScreenState extends State<ForwardUserListScreen> {
  final _users = <ChatUserItem>[];
  final _filtered = <ChatUserItem>[];
  final _searchCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = context.read<SessionManager>();
    try {
      final res = await ApiService.chatList(userId: session.userId, limit: 100);
      setState(() {
        _users.addAll(res.chatList);
        _filtered.addAll(res.chatList);
        _loading = false;
      });
    } catch (e) {
      Log.e('ForwardUserList', 'load failed', e);
      setState(() => _loading = false);
    }
  }

  void _onSearch(String q) {
    setState(() {
      _filtered.clear();
      if (q.isEmpty) {
        _filtered.addAll(_users);
      } else {
        _filtered.addAll(
          _users.where(
            (u) => (u.name ?? '').toLowerCase().contains(q.toLowerCase()),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forward to...'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          Expanded(
            child:
                _loading
                    ? const Center(child: Preloader())
                    : _filtered.isEmpty
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No contacts found',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final u = _filtered[i];
                        return ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.purpleGradient,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child:
                                u.image != null && u.image!.isNotEmpty
                                    ? ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: u.image!,
                                        fit: BoxFit.cover,
                                        errorWidget:
                                            (_, __, ___) => const Icon(
                                              Icons.person,
                                              color: Colors.white,
                                            ),
                                      ),
                                    )
                                    : const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    ),
                          ),
                          title: Text(
                            u.name ?? 'User',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onTap: () => _forwardTo(u),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  void _forwardTo(ChatUserItem user) {
    if (widget.forwardItem == null) return;
    context.pushReplacementNamed(
      AppRoutes.chatDetail,
      extra: {
        'otherUserId': user.userId,
        'otherUserName': user.name,
        'forwardItem': widget.forwardItem,
      },
    );
  }
}

class MusicFolderScreen extends StatelessWidget {
  const MusicFolderScreen({super.key, required this.folders});

  final List<Map<String, dynamic>> folders;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Music Folders')),
      body: ListView.builder(
        itemCount: folders.length,
        itemBuilder: (_, i) {
          final f = folders[i];
          return ListTile(
            leading: const Icon(Icons.folder, color: AppTheme.primary),
            title: Text(f['name'] as String? ?? 'Folder'),
            subtitle: Text('${f['count'] ?? 0} songs'),
            onTap: () => Navigator.pop(context, f),
          );
        },
      ),
    );
  }
}

class AudioListScreen extends StatelessWidget {
  const AudioListScreen({super.key, required this.songs});

  final List<Map<String, dynamic>> songs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Songs')),
      body: ListView.builder(
        itemCount: songs.length,
        itemBuilder: (_, i) {
          final s = songs[i];
          return ListTile(
            leading: const Icon(Icons.music_note, color: AppTheme.primary),
            title: Text(s['title'] as String? ?? 'Song'),
            subtitle: Text(s['artist'] as String? ?? ''),
            onTap: () => Navigator.pop(context, s),
          );
        },
      ),
    );
  }
}

class LocationChooseScreen extends StatefulWidget {
  const LocationChooseScreen({super.key});

  @override
  State<LocationChooseScreen> createState() => _LocationChooseScreenState();
}

class _LocationChooseScreenState extends State<LocationChooseScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search location...',
            border: InputBorder.none,
          ),
          onChanged: _onSearch,
        ),
      ),
      body: ListView.builder(
        itemCount: _results.length,
        itemBuilder: (_, i) {
          final r = _results[i];
          return ListTile(
            leading: const Icon(Icons.location_on, color: AppTheme.primary),
            title: Text(r['label'] as String? ?? r['name'] as String? ?? ''),
            subtitle: Text(r['region'] as String? ?? ''),
            onTap: () => Navigator.pop(context, r),
          );
        },
      ),
    );
  }

  void _onSearch(String query) async {
    if (query.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    try {
      final results = await ApiService.searchLocations(
        query,
        Const.POSITION_STACK_KEY,
      );
      if (mounted) setState(() => _results = results);
    } catch (e) {
      Log.e('LocationChoose', 'search failed', e);
    }
  }
}

class DynamicAvatarScreen extends StatelessWidget {
  const DynamicAvatarScreen({super.key, required this.avatars});

  final List<Map<String, dynamic>> avatars;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dynamic Avatars')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: avatars.length,
        itemBuilder: (_, i) {
          final a = avatars[i];
          return GestureDetector(
            onTap: () => Navigator.pop(context, a),
            child: Card(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.network(
                    a['image'] ?? '',
                    width: 80,
                    height: 80,
                    errorBuilder:
                        (_, __, ___) => const Icon(Icons.face, size: 80),
                  ),
                  const SizedBox(height: 8),
                  Text(a['name'] ?? 'Avatar'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class BanAccountScreen extends StatelessWidget {
  const BanAccountScreen({
    super.key,
    required this.onBan,
    required this.onUnban,
  });

  final VoidCallback onBan;
  final VoidCallback onUnban;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ban Management')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gavel, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'VIP Ban / Unban Account',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  onBan();
                  Navigator.pop(context);
                },
                child: const Text('Ban Account'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  onUnban();
                  Navigator.pop(context);
                },
                child: const Text('Unban Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LuckyIdScreen extends StatefulWidget {
  const LuckyIdScreen({super.key});

  @override
  State<LuckyIdScreen> createState() => _LuckyIdScreenState();
}

class _LuckyIdScreenState extends State<LuckyIdScreen> {
  final _idController = TextEditingController();
  bool _checking = false;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _checkAvailability() async {
    final id = _idController.text.trim();
    if (id.isEmpty) {
      Fluttertoast.showToast(msg: 'Enter a Lucky ID');
      return;
    }
    setState(() => _checking = true);
    try {
      final res = await ApiService.getGuestProfileByUsername(id);
      if (mounted) {
        if (res.user != null) {
          Fluttertoast.showToast(msg: 'This ID is already taken');
        } else {
          Fluttertoast.showToast(msg: 'ID available! Proceeding...');
          _purchaseLuckyId(id);
        }
      }
    } catch (e) {
      Log.e('LuckyId', 'check failed', e);
      Fluttertoast.showToast(msg: 'ID available! Proceeding...');
      _purchaseLuckyId(id);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _purchaseLuckyId(String id) async {
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.updateUser(
        fields: {'userId': session.userId, 'luckyId': id},
      );
      if (res.status) {
        Fluttertoast.showToast(msg: 'Lucky ID set successfully!');
        if (mounted) Navigator.pop(context);
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Failed to set Lucky ID');
      }
    } catch (e) {
      Log.e('LuckyId', 'purchase failed', e);
      Fluttertoast.showToast(msg: 'Failed to set Lucky ID');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lucky ID')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.casino, size: 64, color: AppTheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Choose Your Lucky ID',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Set a unique lucky ID for your profile. This can attract more followers!',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _idController,
              decoration: InputDecoration(
                labelText: 'Enter Lucky ID',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _checking ? null : _checkAvailability,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _checking
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: Preloader(strokeWidth: 2, color: Colors.white),
                        )
                        : const Text('Check & Set Lucky ID'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileVideoGridScreen extends StatefulWidget {
  const ProfileVideoGridScreen({super.key, required this.userId});

  final String userId;

  @override
  State<ProfileVideoGridScreen> createState() => _ProfileVideoGridScreenState();
}

class _ProfileVideoGridScreenState extends State<ProfileVideoGridScreen> {
  final _reels = <ReelItem>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.getReels(
        userId: widget.userId,
        type: 'user',
        start: 0,
        limit: 50,
      );
      if (mounted) {
        setState(() {
          _reels.addAll(res.video);
          _loading = false;
        });
      }
    } catch (e) {
      Log.e('ProfileVideos', 'load failed', e);
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Videos')),
      body:
          _loading
              ? const Center(child: Preloader())
              : _reels.isEmpty
              ? Center(
                child: Text(
                  'No videos yet',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              )
              : GridView.builder(
                padding: const EdgeInsets.all(4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                  childAspectRatio: 0.75,
                ),
                itemCount: _reels.length,
                itemBuilder: (_, i) {
                  final reel = _reels[i];
                  final thumb = reel.thumbnail ?? reel.video ?? '';
                  return GestureDetector(
                    onTap: () {
                      context.pushNamed(
                        AppRoutes.feedGrid,
                        extra: {'startIndex': i, 'reels': _reels},
                      );
                    },
                    child: Stack(
                      alignment: Alignment.topLeft,
                      fit: StackFit.expand,
                      children: [
                        if (thumb.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: thumb,
                            fit: BoxFit.cover,
                            errorWidget:
                                (_, __, ___) =>
                                    Container(color: Colors.grey.shade300),
                          )
                        else
                          Container(color: Colors.grey.shade300),
                        const Positioned(
                          bottom: 4,
                          left: 4,
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}

class FakeChatScreen extends StatelessWidget {
  const FakeChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo Chat'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.orange,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  'DEMO MODE — for testing only',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _fakeMessage('Hello! Welcome to Belive', true),
                _fakeMessage('Hi there! Nice to meet you', false),
                _fakeMessage('How are you doing today?', true),
                _fakeMessage('I am doing great, thanks for asking!', false),
                _fakeMessage('Check out the live streaming feature!', true),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Demo chat mode - for testing only',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fakeMessage(String text, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primary : Colors.grey.shade200,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(color: isMe ? Colors.white : Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FakeWatchLiveScreen extends StatelessWidget {
  const FakeWatchLiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Demo Live', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        alignment: Alignment.topLeft,
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.purple, Colors.black],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'DEMO MODE — for testing only',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.live_tv,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Demo Host',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Demo Live - for testing only',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _sendFakeGift(context),
                  icon: const ImageIcon(const AssetImage("assets/gift/official_gift.png")),
                  label: const Text('Send Test Gift'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendFakeGift(BuildContext context) async {
    try {
      final session = context.read<SessionManager>();
      await ApiService.sendChatGift(
        senderUserId: session.userId,
        coin: 10,
        receiverUserId: 'fake_host',
        type: 'live',
        giftId: 'test_gift',
        count: 1,
      );
      Fluttertoast.showToast(msg: 'Test gift sent to fake host');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed: $e');
    }
  }
}

class FakePkLiveScreen extends StatelessWidget {
  const FakePkLiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Demo PK Battle',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.orange,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  'DEMO MODE — for testing only',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple, Colors.black],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.purple,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Host A',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '1,234',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(width: 2, color: Colors.white24),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue, Colors.black],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Host B',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '987',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 40),
            child: Text(
              'Demo PK - for testing only',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
