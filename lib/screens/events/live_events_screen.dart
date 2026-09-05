library belive.screens.events.live_events_screen;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../utils/log.dart';

/// Represents the type of a [LiveEvent].
enum LiveEventType {
  contest,
  talentShow,
  party,
  battle,
  festival;

  String get label => switch (this) {
    LiveEventType.contest => 'Contest',
    LiveEventType.talentShow => 'Talent Show',
    LiveEventType.party => 'Party',
    LiveEventType.battle => 'Battle',
    LiveEventType.festival => 'Festival',
  };
}

/// Represents the lifecycle status of a [LiveEvent].
enum LiveEventStatus {
  live,
  upcoming,
  ended;

  String get label => switch (this) {
    LiveEventStatus.live => 'LIVE',
    LiveEventStatus.upcoming => 'Upcoming',
    LiveEventStatus.ended => 'Ended',
  };
}

/// Model class describing a live event, contest, or talent show.
class LiveEvent {
  const LiveEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.bannerUrl,
    required this.startDate,
    required this.endDate,
    required this.type,
    required this.status,
    required this.participantCount,
    required this.prizePool,
  });

  final String id;
  final String title;
  final String description;
  final String bannerUrl;
  final DateTime startDate;
  final DateTime endDate;
  final LiveEventType type;
  final LiveEventStatus status;
  final int participantCount;
  final String prizePool;

  factory LiveEvent.fromJson(Map<String, dynamic> json) {
    return LiveEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      bannerUrl: json['bannerUrl'] as String? ?? '',
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      type: LiveEventType.values.byName(json['type'] as String? ?? 'contest'),
      status: LiveEventStatus.values.byName(
        json['status'] as String? ?? 'upcoming',
      ),
      participantCount: (json['participantCount'] as num?)?.toInt() ?? 0,
      prizePool: json['prizePool'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'description': description,
    'bannerUrl': bannerUrl,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'type': type.name,
    'status': status.name,
    'participantCount': participantCount,
    'prizePool': prizePool,
  };
}

const String _tag = 'LiveEventsScreen';

/// Screen that displays live events, contests, and talent shows.
///
/// Features a banner carousel for featured events, a list of active events
/// with join buttons, a list of upcoming events with register buttons, and a
/// "My Events" tab.
class LiveEventsScreen extends StatefulWidget {
  const LiveEventsScreen({super.key});

  @override
  State<LiveEventsScreen> createState() => _LiveEventsScreenState();
}

class _LiveEventsScreenState extends State<LiveEventsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final PageController _bannerController = PageController();
  int _bannerIndex = 0;

  List<LiveEvent> _activeEvents = [];
  List<LiveEvent> _upcomingEvents = [];
  List<LiveEvent> _myEvents = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Log.d(_tag, 'LiveEventsScreen: initState');
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final activeList = await ApiService.getLiveEvents(status: 'active');
      final upcomingList = await ApiService.getLiveEvents(status: 'upcoming');
      if (mounted) {
        setState(() {
          _activeEvents = activeList.map((j) => LiveEvent.fromJson(j)).toList();
          _upcomingEvents =
              upcomingList.map((j) => LiveEvent.fromJson(j)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      Log.e(_tag, 'fetchEvents failed', e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  // ---- Sample data ---------------------------------------------------------

  static final List<LiveEvent> _featuredEvents = <LiveEvent>[
    LiveEvent(
      id: 'e1',
      title: 'Global Talent Show 2025',
      description: 'The biggest talent show of the year. Show your skills!',
      bannerUrl: 'https://picsum.photos/seed/event1/800/400',
      startDate: DateTime(2025, 12, 1),
      endDate: DateTime(2025, 12, 15),
      type: LiveEventType.talentShow,
      status: LiveEventStatus.live,
      participantCount: 12450,
      prizePool: '\$50,000',
    ),
    LiveEvent(
      id: 'e2',
      title: 'Summer Singing Contest',
      description: 'Sing your heart out and win amazing prizes.',
      bannerUrl: 'https://picsum.photos/seed/event2/800/400',
      startDate: DateTime(2025, 12, 10),
      endDate: DateTime(2025, 12, 20),
      type: LiveEventType.contest,
      status: LiveEventStatus.upcoming,
      participantCount: 3200,
      prizePool: '\$20,000',
    ),
    LiveEvent(
      id: 'e3',
      title: 'New Year Festival',
      description: 'Ring in the new year with live performances.',
      bannerUrl: 'https://picsum.photos/seed/event3/800/400',
      startDate: DateTime(2025, 12, 31),
      endDate: DateTime(2026, 1, 1),
      type: LiveEventType.festival,
      status: LiveEventStatus.upcoming,
      participantCount: 800,
      prizePool: '\$10,000',
    ),
  ];

  static final List<LiveEvent> _sampleActiveEvents = <LiveEvent>[
    LiveEvent(
      id: 'e1',
      title: 'Global Talent Show 2025',
      description: 'Live now. Join the audience and vote for your favorites.',
      bannerUrl: 'https://picsum.photos/seed/event1/800/400',
      startDate: DateTime(2025, 12, 1),
      endDate: DateTime(2025, 12, 15),
      type: LiveEventType.talentShow,
      status: LiveEventStatus.live,
      participantCount: 12450,
      prizePool: '\$50,000',
    ),
    LiveEvent(
      id: 'e4',
      title: 'Dance Battle Finals',
      description: 'The top dancers compete head to head.',
      bannerUrl: 'https://picsum.photos/seed/event4/800/400',
      startDate: DateTime(2025, 11, 28),
      endDate: DateTime(2025, 12, 5),
      type: LiveEventType.battle,
      status: LiveEventStatus.live,
      participantCount: 5600,
      prizePool: '\$15,000',
    ),
  ];

  static final List<LiveEvent> _sampleUpcomingEvents = <LiveEvent>[
    LiveEvent(
      id: 'e2',
      title: 'Summer Singing Contest',
      description: 'Register now to secure your spot.',
      bannerUrl: 'https://picsum.photos/seed/event2/800/400',
      startDate: DateTime(2025, 12, 10),
      endDate: DateTime(2025, 12, 20),
      type: LiveEventType.contest,
      status: LiveEventStatus.upcoming,
      participantCount: 3200,
      prizePool: '\$20,000',
    ),
    LiveEvent(
      id: 'e3',
      title: 'New Year Festival',
      description: 'Reserve your front-row virtual seat.',
      bannerUrl: 'https://picsum.photos/seed/event3/800/400',
      startDate: DateTime(2025, 12, 31),
      endDate: DateTime(2026, 1, 1),
      type: LiveEventType.festival,
      status: LiveEventStatus.upcoming,
      participantCount: 800,
      prizePool: '\$10,000',
    ),
  ];

  static final List<LiveEvent> _sampleMyEvents = <LiveEvent>[
    LiveEvent(
      id: 'e5',
      title: 'My First Performance',
      description: 'You registered as a participant.',
      bannerUrl: 'https://picsum.photos/seed/event5/800/400',
      startDate: DateTime(2025, 12, 8),
      endDate: DateTime(2025, 12, 9),
      type: LiveEventType.talentShow,
      status: LiveEventStatus.upcoming,
      participantCount: 120,
      prizePool: '\$1,000',
    ),
  ];

  // ---- Handlers ------------------------------------------------------------

  void _onJoinEvent(LiveEvent event) {
    Log.d(_tag, 'LiveEventsScreen: join event ${event.id}');
    context.push('/liveRoom?liveStreamingId=${event.id}');
  }

  Future<void> _onRegisterEvent(LiveEvent event) async {
    Log.d(_tag, 'LiveEventsScreen: register event ${event.id}');
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.registerForLiveEvent(
        eventId: event.id,
        userId: session.userId,
      );
      if (res.status) {
        Fluttertoast.showToast(msg: 'Registered successfully!');
        _fetchEvents();
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Registration failed');
      }
    } catch (e) {
      Log.e(_tag, 'register failed', e);
      Fluttertoast.showToast(msg: 'Registration failed');
    }
  }

  void _onBannerTap(LiveEvent event) {
    Log.d(_tag, 'LiveEventsScreen: banner tap ${event.id}');
    context.push('/events/${event.id}');
  }

  // ---- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Events'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Tab>[
            Tab(text: 'Discover'),
            Tab(text: 'Upcoming'),
            Tab(text: 'My Events'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _DiscoverTab(
            bannerController: _bannerController,
            bannerIndex: _bannerIndex,
            onBannerChanged: (int index) {
              setState(() => _bannerIndex = index);
            },
            onBannerTap: _onBannerTap,
            featuredEvents: _featuredEvents,
            activeEvents:
                _activeEvents.isNotEmpty ? _activeEvents : _sampleActiveEvents,
            onJoin: _onJoinEvent,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          _UpcomingTab(
            events:
                _upcomingEvents.isNotEmpty
                    ? _upcomingEvents
                    : _sampleUpcomingEvents,
            onRegister: _onRegisterEvent,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          _MyEventsTab(
            events: _myEvents.isNotEmpty ? _myEvents : _sampleMyEvents,
            onJoin: _onJoinEvent,
            onRegister: _onRegisterEvent,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
        ],
      ),
    );
  }
}

// ---- Discover tab ----------------------------------------------------------

class _DiscoverTab extends StatelessWidget {
  const _DiscoverTab({
    required this.bannerController,
    required this.bannerIndex,
    required this.onBannerChanged,
    required this.onBannerTap,
    required this.featuredEvents,
    required this.activeEvents,
    required this.onJoin,
    required this.colorScheme,
    required this.textTheme,
  });

  final PageController bannerController;
  final int bannerIndex;
  final ValueChanged<int> onBannerChanged;
  final ValueChanged<LiveEvent> onBannerTap;
  final List<LiveEvent> featuredEvents;
  final List<LiveEvent> activeEvents;
  final ValueChanged<LiveEvent> onJoin;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: <Widget>[
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: bannerController,
            itemCount: featuredEvents.length,
            onPageChanged: onBannerChanged,
            itemBuilder: (BuildContext context, int index) {
              return _BannerCard(
                event: featuredEvents[index],
                onTap: () => onBannerTap(featuredEvents[index]),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(featuredEvents.length, (int index) {
            return Container(
              width: index == bannerIndex ? 20 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color:
                    index == bannerIndex
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Active Now',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        for (final LiveEvent event in activeEvents)
          _EventListItem(
            event: event,
            actionLabel: 'Join',
            onAction: () => onJoin(event),
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.event, required this.onTap});

  final LiveEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: colorScheme.surfaceContainerHighest,
        ),
        child: Stack(
          alignment: Alignment.topLeft,
          fit: StackFit.expand,
          children: <Widget>[
            CachedNetworkImage(
              imageUrl: event.bannerUrl,
              fit: BoxFit.cover,
              placeholder:
                  (BuildContext context, String url) =>
                      Container(color: colorScheme.surfaceContainerHighest),
              errorWidget:
                  (BuildContext context, String url, Object error) => Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
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
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (event.status == LiveEventStatus.live) const _LiveBadge(),
                  const SizedBox(height: 6),
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${event.type.label} - Prize: ${event.prizePool}',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
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

// ---- Upcoming tab ----------------------------------------------------------

class _UpcomingTab extends StatelessWidget {
  const _UpcomingTab({
    required this.events,
    required this.onRegister,
    required this.colorScheme,
    required this.textTheme,
  });

  final List<LiveEvent> events;
  final ValueChanged<LiveEvent> onRegister;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return _EmptyState(
        message: 'No upcoming events yet. Check back soon!',
        textTheme: textTheme,
        colorScheme: colorScheme,
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: <Widget>[
        for (final LiveEvent event in events)
          _EventListItem(
            event: event,
            actionLabel: 'Register',
            onAction: () => onRegister(event),
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
      ],
    );
  }
}

// ---- My Events tab ---------------------------------------------------------

class _MyEventsTab extends StatelessWidget {
  const _MyEventsTab({
    required this.events,
    required this.onJoin,
    required this.onRegister,
    required this.colorScheme,
    required this.textTheme,
  });

  final List<LiveEvent> events;
  final ValueChanged<LiveEvent> onJoin;
  final ValueChanged<LiveEvent> onRegister;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return _EmptyState(
        message: 'You have not joined any events yet.',
        textTheme: textTheme,
        colorScheme: colorScheme,
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: <Widget>[
        for (final LiveEvent event in events)
          _EventListItem(
            event: event,
            actionLabel:
                event.status == LiveEventStatus.live ? 'Join' : 'Register',
            onAction: () {
              if (event.status == LiveEventStatus.live) {
                onJoin(event);
              } else {
                onRegister(event);
              }
            },
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
      ],
    );
  }
}

// ---- Shared widgets --------------------------------------------------------

class _EventListItem extends StatelessWidget {
  const _EventListItem({
    required this.event,
    required this.actionLabel,
    required this.onAction,
    required this.colorScheme,
    required this.textTheme,
  });

  final LiveEvent event;
  final String actionLabel;
  final VoidCallback onAction;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 96,
              height: 96,
              child: CachedNetworkImage(
                imageUrl: event.bannerUrl,
                fit: BoxFit.cover,
                placeholder:
                    (BuildContext context, String url) =>
                        Container(color: colorScheme.surfaceContainerHighest),
                errorWidget:
                    (BuildContext context, String url, Object error) =>
                        Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.broken_image,
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (event.status == LiveEventStatus.live)
                      const _LiveBadge()
                    else
                      _StatusChip(label: event.type.label),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  event.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.people,
                      size: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${event.participantCount}',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.emoji_events,
                      size: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        event.prizePool,
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.primary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    required this.textTheme,
    required this.colorScheme,
  });

  final String message;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.event_busy,
              size: 48,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
