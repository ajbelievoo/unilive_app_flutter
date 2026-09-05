import 'package:flutter/material.dart';

import '../../models/live_user_root.dart' as live_user;
import 'live_preview_screen.dart';

/// Scrollable wrapper around [LivePreviewScreen] that lets users swipe
/// vertically through multiple live stream previews without returning
/// to the home page (SS 11).
///
/// Each page is a [LivePreviewScreen]. When the user taps "Enter Live"
/// on any page, this pager pops with the selected [LiveUser].
class LivePreviewPager extends StatefulWidget {
  const LivePreviewPager({
    super.key,
    required this.users,
    required this.initialIndex,
  });

  final List<live_user.LiveUser> users;
  final int initialIndex;

  @override
  State<LivePreviewPager> createState() => _LivePreviewPagerState();
}

class _LivePreviewPagerState extends State<LivePreviewPager> {
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        itemCount: widget.users.length,
        itemBuilder: (_, i) {
          return LivePreviewScreen(
            key: ValueKey('preview_${widget.users[i].id}_${widget.users[i].liveUserId}'),
            user: widget.users[i],
          );
        },
      ),
    );
  }
}
