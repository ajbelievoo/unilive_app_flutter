import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import 'posts_feed_screen.dart';
import 'reels_screen.dart';

/// Ported from native `FeedFragmentMain.java`.
///
/// Hosts Posts feed and Reels via a TabBar with create FAB.
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Feed'),
          bottom: const TabBar(tabs: [Tab(text: 'Posts'), Tab(text: 'Videos')]),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            final controller = DefaultTabController.of(context);
            final index = controller.animation?.value.round() ?? controller.index;
            if (index == 0) {
              context.pushNamed(AppRoutes.createPost);
            } else {
              context.pushNamed(AppRoutes.createReel);
            }
          },
          backgroundColor: AppTheme.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: const TabBarView(
          children: [
            PostsFeedScreen(type: 1),
            ReelsScreen(),
          ],
        ),
      ),
    );
  }
}
