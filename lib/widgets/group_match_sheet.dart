/// Group Room Matchmaker bottom sheet.
///
/// Shows matched hosts from the AI group matchmaker endpoint and lets the
/// host invite them to a multi-room session.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/group_match_model.dart';
import '../providers/ai_feature_manager.dart';
import '../services/dynamic_ai_features_service.dart';
import '../utils/log.dart';
import '../utils/media_utils.dart';

/// Show the group matchmaker sheet.
void showGroupMatchSheet(BuildContext context, String hostUserId) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1A1A2E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (_) => _GroupMatchSheet(hostUserId: hostUserId),
  );
}

class _GroupMatchSheet extends StatefulWidget {
  const _GroupMatchSheet({required this.hostUserId});
  final String hostUserId;

  @override
  State<_GroupMatchSheet> createState() => _GroupMatchSheetState();
}

class _GroupMatchSheetState extends State<_GroupMatchSheet> {
  static const String _tag = 'GroupMatch';
  bool _loading = true;
  GroupMatchResult? _result;
  String? _error;

  // Common interest tags the host can pick from.
  final _allInterests = ['Singing', 'Dance', 'Gaming', 'Comedy', 'Talk', 'Music'];
  final _selectedInterests = <String>{};

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ai = context.read<AIFeatureManager>();
      final res = await DynamicAIFeaturesService.instance.findGroupMatch(
        hostUserId: widget.hostUserId,
        ai: ai,
        interests: _selectedInterests.toList(),
      );
      if (mounted) {
        setState(() {
          _result = res;
          _loading = false;
        });
      }
    } catch (e, s) {
      Log.e(_tag, 'fetch matches failed', e, s);
      if (mounted) {
        setState(() {
          _error = 'Failed to find matches. Try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.group_work, color: Colors.cyan, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Group Room Match',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'AI matches you with similar hosts for a multi-room',
              style: TextStyle(color: Colors.cyan, fontSize: 12),
            ),
            const SizedBox(height: 12),
            // Interest tags
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allInterests.map((tag) {
                final selected = _selectedInterests.contains(tag);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedInterests.remove(tag);
                      } else {
                        _selectedInterests.add(tag);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? Colors.cyan : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: selected ? Border.all(color: Colors.cyan) : null,
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: selected ? Colors.black : Colors.white70,
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Refresh button
            if (!_loading)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _fetchMatches,
                  icon: const Icon(Icons.refresh, color: Colors.cyan, size: 18),
                  label: const Text('Refresh', style: TextStyle(color: Colors.cyan, fontSize: 13)),
                ),
              ),
            const SizedBox(height: 4),
            // Results
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.cyan));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      );
    }
    final hosts = _result?.matchedHosts ?? [];
    if (hosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, color: Colors.white30, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No matches found right now',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try selecting different interests',
              style: TextStyle(color: Colors.white30, fontSize: 12),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: hosts.length,
      itemBuilder: (ctx, i) => _buildHostTile(hosts[i]),
    );
  }

  Widget _buildHostTile(GroupMatchedHost host) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Avatar
          ClipOval(
            child: SizedBox(
              width: 48,
              height: 48,
              child: host.image != null && host.image!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: VideoUtil.getFullImageUrl(host.image!),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.white12),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.white12,
                        child: const Icon(Icons.person, color: Colors.white30),
                      ),
                    )
                  : Container(
                      color: Colors.white12,
                      child: const Icon(Icons.person, color: Colors.white30),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + tags
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      host.name ?? 'Host',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    if (host.isLive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: host.tags.map((t) => Chip(
                    label: Text(t, style: const TextStyle(fontSize: 10)),
                    labelStyle: const TextStyle(color: Colors.white70),
                    backgroundColor: Colors.cyan.withValues(alpha: 0.2),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )).toList(),
                ),
              ],
            ),
          ),
          // Match score
          if (host.matchScore > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${host.matchScore}',
                style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
