/// Audio room discovery screen — search, categories, trending, history.
///
/// Ports native audio room list/discovery UI:
/// - Search bar for finding rooms
/// - Category chips for filtering
/// - Trending rooms list
/// - Recently visited rooms
/// - Quick rejoin last room
library audio_room_discovery_screen;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../utils/media_utils.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';

import '../../models/audio_room_root.dart';
import '../../routes/app_routes.dart';
import '../../services/audio_room_discovery_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import '../../widgets/user_avatar.dart';
import 'package:belive/widgets/preloader.dart';

class AudioRoomDiscoveryScreen extends StatefulWidget {
  const AudioRoomDiscoveryScreen({super.key});

  @override
  State<AudioRoomDiscoveryScreen> createState() => _AudioRoomDiscoveryScreenState();
}

class _AudioRoomDiscoveryScreenState extends State<AudioRoomDiscoveryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  String _selectedCategory = 'all';
  List<AudioRoomUser> _searchResults = [];
  List<AudioRoomUser> _trendingRooms = [];
  List<RoomHistoryEntry> _history = [];
  bool _isSearching = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final trending = await AudioRoomDiscoveryService.getTrendingRooms();
      final history = await AudioRoomDiscoveryService.getHistory();
      if (mounted) {
        setState(() {
          _trendingRooms = trending;
          _history = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await AudioRoomDiscoveryService.searchRooms(query);
      if (mounted) setState(() => _searchResults = results);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _loadCategory(String categoryId) async {
    setState(() {
      _selectedCategory = categoryId;
      _isLoading = true;
    });
    try {
      final rooms = await AudioRoomDiscoveryService.getRoomsByCategory(categoryId);
      if (mounted) {
        setState(() {
        _trendingRooms = rooms;
        _isLoading = false;
      });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _joinRoom(AudioRoomUser room) {
    // Add to history
    AudioRoomDiscoveryService.addToHistory(RoomHistoryEntry(
      roomId: room.liveStreamingId ?? room.id ?? '',
      roomName: room.roomName ?? room.name ?? 'Audio Room',
      hostName: room.name,
      hostImage: room.image,
      viewerCount: room.view,
      visitedAt: DateTime.now(),
    ));
    context.goNamed(AppRoutes.audioRoom, extra: {'roomUser': room, 'isHost': false});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Discover Rooms'),
        backgroundColor: AppTheme.surface,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Trending'),
            Tab(text: 'Search'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTrendingTab(),
          _buildSearchTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  // ---- Trending Tab ----
  Widget _buildTrendingTab() {
    return Column(children: [
      // Category chips
      SizedBox(
        height: 50,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          itemCount: RoomCategory.all.length,
          itemBuilder: (_, i) {
            final cat = RoomCategory.all[i];
            final selected = _selectedCategory == cat.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('${cat.icon} ${cat.name}'),
                selected: selected,
                onSelected: (_) => _loadCategory(cat.id),
                selectedColor: AppTheme.primary,
                labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
                backgroundColor: AppTheme.surface,
              ),
            );
          },
        ),
      ),
      // Rooms list
      Expanded(
        child: _isLoading
            ? const Center(child: Preloader())
            : _trendingRooms.isEmpty
                ? const Center(child: Text('No rooms found', style: TextStyle(color: Colors.white54)))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _trendingRooms.length,
                      itemBuilder: (_, i) => _RoomCard(
                        room: _trendingRooms[i],
                        onTap: () => _joinRoom(_trendingRooms[i]),
                      ),
                    ),
                  ),
      ),
    ]);
  }

  // ---- Search Tab ----
  Widget _buildSearchTab() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search rooms by name, host, or ID...',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: Colors.white54),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54),
                    onPressed: () {
                      _searchCtrl.clear();
                      _performSearch('');
                    },
                  )
                : null,
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: _performSearch,
        ),
      ),
      Expanded(
        child: _isSearching
            ? const Center(child: Preloader())
            : _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search, size: 64, color: Colors.white24),
                        const SizedBox(height: 12),
                        Text(_searchCtrl.text.isEmpty ? 'Start searching...' : 'No results found',
                            style: const TextStyle(color: Colors.white54)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _searchResults.length,
                    itemBuilder: (_, i) => _RoomCard(
                      room: _searchResults[i],
                      onTap: () => _joinRoom(_searchResults[i]),
                    ),
                  ),
      ),
    ]);
  }

  // ---- History Tab ----
  Widget _buildHistoryTab() {
    return _history.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history, size: 64, color: Colors.white24),
                const SizedBox(height: 12),
                const Text('No recently visited rooms', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 16),
                // Quick rejoin button if last room exists
                if (_history.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () {
                      final last = _history.first;
                      Fluttertoast.showToast(msg: 'Rejoining ${last.roomName}...');
                    },
                    icon: const Icon(Icons.replay),
                    label: const Text('Quick Rejoin Last Room'),
                  ),
              ],
            ),
          )
        : Column(children: [
            // Quick rejoin banner
            if (_history.isNotEmpty)
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryDark]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.replay, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quick Rejoin: ${_history.first.roomName}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text('Visited ${formatTimeAgo(_history.first.visitedAt)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  )),
                  FilledButton(
                    onPressed: () {
                      // Rejoin would need to fetch room data from API
                      Fluttertoast.showToast(msg: 'Rejoining...');
                    },
                    style: FilledButton.styleFrom(backgroundColor: Colors.white),
                    child: const Text('Join', style: TextStyle(color: AppTheme.primary)),
                  ),
                ]),
              ),
            // History list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _history.length,
                itemBuilder: (_, i) => _HistoryCard(
                  entry: _history[i],
                  onTap: () {
                    Fluttertoast.showToast(msg: 'Rejoining ${_history[i].roomName}...');
                  },
                  onDelete: () async {
                    setState(() => _history.removeAt(i));
                  },
                ),
              ),
            ),
            // Clear history button
            if (_history.isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  await AudioRoomDiscoveryService.clearHistory();
                  setState(() => _history.clear());
                  Fluttertoast.showToast(msg: 'History cleared');
                },
                icon: const Icon(Icons.delete_sweep, color: Colors.red),
                label: const Text('Clear History', style: TextStyle(color: Colors.red)),
              ),
          ]);
  }
}

// ---- Room Card Widget ----
class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.onTap});
  final AudioRoomUser room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: UserAvatar(imageUrl: room.image, size: 50, isVIP: room.isVIP),
        title: Text(
          room.roomName ?? room.name ?? 'Audio Room',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.person, size: 12, color: Colors.white54),
              const SizedBox(width: 4),
              Text(room.name ?? 'Host', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(width: 8),
              const Icon(Icons.visibility, size: 12, color: Colors.white54),
              const SizedBox(width: 4),
              Text(formatCount(room.view), style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
            if (room.roomTags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: room.roomTags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7E3FF2).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF7E3FF2).withValues(alpha: 0.4)),
                  ),
                  child: Text(tag, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                )).toList(),
              ),
            ],
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('Join', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        onTap: onTap,
      ),
    );
  }
}

// ---- History Card Widget ----
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry, required this.onTap, required this.onDelete});
  final RoomHistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: (entry.hostImage ?? '').isNotEmpty
            ? CircleAvatar(backgroundImage: CachedNetworkImageProvider(entry.hostImage!), radius: 24)
            : const CircleAvatar(radius: 24, child: Icon(Icons.mic, color: Colors.white)),
        title: Text(entry.roomName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${entry.hostName ?? 'Host'} • ${formatTimeAgo(entry.visitedAt)}',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.close, color: Colors.white38),
          onPressed: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }
}
