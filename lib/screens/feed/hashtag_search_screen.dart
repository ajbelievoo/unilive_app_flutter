import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/level_summary_models.dart' show HashtagItem;
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

/// Search hashtags for reels/posts.
/// Native: GET /hashtag?value=
class HashtagSearchScreen extends StatefulWidget {
  const HashtagSearchScreen({super.key});

  @override
  State<HashtagSearchScreen> createState() => _HashtagSearchScreenState();
}

class _HashtagSearchScreenState extends State<HashtagSearchScreen> {
  static const String _tag = 'HashtagSearch';
  final _ctrl = TextEditingController();
  final _results = <HashtagItem>[];
  bool _searching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _ctrl.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _hasSearched = true;
    });
    try {
      final res = await ApiService.searchHashtag(query);
      _results
        ..clear()
        ..addAll(res.data);
    } catch (e, s) {
      Log.e(_tag, 'search failed', e, s);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            hintText: 'Search hashtags...',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() {
                        _results.clear();
                        _hasSearched = false;
                      });
                    },
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      body: _searching
          ? const Center(child: Preloader())
          : _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tag, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        _hasSearched ? 'No hashtags found' : 'Search for hashtags',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final tag = _results[i];
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF7E3FF2), Color(0xFF5B2DD6)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.tag, color: Colors.white, size: 20),
                      ),
                      title: Text('#${tag.hashtag}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${tag.count} posts'),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {
                        context.pushNamed(AppRoutes.feedGrid, extra: {
                          'hashtag': tag.hashtag,
                        });
                      },
                    );
                  },
                ),
    );
  }
}
