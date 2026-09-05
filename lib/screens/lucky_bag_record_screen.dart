/// Lucky Bag Record screen.
///
/// Shows the history of lucky bags sent and received by the current user.
library lucky_bag_record_screen;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../services/lucky_bag_history_service.dart';
import '../services/session_manager.dart';
import '../theme/app_theme.dart';
import '../utils/log.dart';
import '../utils/media_utils.dart';
import 'package:belive/widgets/preloader.dart';

class LuckyBagRecordScreen extends StatefulWidget {
  const LuckyBagRecordScreen({super.key, this.liveStreamingId});

  final String? liveStreamingId;

  @override
  State<LuckyBagRecordScreen> createState() => _LuckyBagRecordScreenState();
}

class _LuckyBagRecordScreenState extends State<LuckyBagRecordScreen> {
  static const String _tag = 'LuckyBagRecord';

  bool _loading = true;
  int _selectedTab = 0;
  List<LuckyBagHistoryEntry> _records = [];

  String get _myUserId => SessionManager.instance?.userId ?? '';

  List<LuckyBagHistoryEntry> get _visibleRecords {
    return switch (_selectedTab) {
      1 =>
        _records
            .where((item) => item.isClaim && item.userId == _myUserId)
            .toList(),
      2 =>
        _records
            .where((item) => !item.isClaim && item.userId == _myUserId)
            .toList(),
      _ => _records.where((item) => item.isClaim).toList(),
    };
  }

  int get _myReceived => _records
      .where((item) => item.isClaim && item.userId == _myUserId)
      .fold(0, (total, item) => total + item.coins);

  int get _totalLooted => _records
      .where((item) => item.isClaim)
      .fold(0, (total, item) => total + item.coins);

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    try {
      try {
        final response = await ApiService.getLuckyBagHistory(
          liveStreamingId: widget.liveStreamingId,
          userId: widget.liveStreamingId?.isNotEmpty == true ? null : _myUserId,
        );
        if (response.status) {
          final remote = _extractList(response.data ?? const {});
          await LuckyBagHistoryService.instance.mergeRemote(remote);
        }
      } catch (e) {
        Log.w(_tag, 'remote history unavailable: $e');
      }
      final records = await LuckyBagHistoryService.instance.getEntries(
        liveStreamingId: widget.liveStreamingId,
      );
      if (mounted) setState(() => _records = records);
    } catch (e, s) {
      Log.e(_tag, 'load failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic> payload) {
    for (final key in const [
      'history',
      'records',
      'claims',
      'luckyBagHistory',
      'data',
      'result',
    ]) {
      final value = payload[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      if (value is Map) {
        final nested = _extractList(Map<String, dynamic>.from(value));
        if (nested.isNotEmpty) return nested;
      }
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.surface : AppTheme.lightSurface;
    final text = isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Lucky Bag History',
          style: TextStyle(color: text, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body:
          _loading
              ? const Center(child: Preloader())
              : RefreshIndicator(
                onRefresh: _loadRecords,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                  children: [
                    _summaryCard(),
                    const SizedBox(height: 14),
                    _tabs(),
                    const SizedBox(height: 10),
                    if (_visibleRecords.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Center(child: Text('No Lucky Bag records yet')),
                      )
                    else
                      ..._visibleRecords.map((item) => _RecordTile(item: item)),
                  ],
                ),
              ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF071A38), Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF40C4FF).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Image.asset('assets/lucky/lucky_bag.png', width: 72, height: 72),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Lucky Bag rewards',
                  style: TextStyle(color: Colors.white70),
                ),
                Text(
                  '$_myReceived diamonds',
                  style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Room total looted: $_totalLooted',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    const labels = ['All looters', 'I received', 'I sent'];
    return Row(
      children: List.generate(labels.length, (index) {
        final selected = _selectedTab == index;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 6),
            child: ChoiceChip(
              selected: selected,
              onSelected: (_) => setState(() => _selectedTab = index),
              label: SizedBox(
                width: double.infinity,
                child: Text(labels[index], textAlign: TextAlign.center),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.item});

  final LuckyBagHistoryEntry item;

  @override
  Widget build(BuildContext context) {
    final title =
        item.isClaim
            ? '${item.name.isEmpty ? 'User' : item.name} looted ${item.coins} diamonds'
            : '${item.name.isEmpty ? 'User' : item.name} sent ${item.coins} diamonds';
    final subtitle =
        item.isClaim ? 'Lucky Bag claimed' : '${item.bagCount} bags created';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            item.image.isNotEmpty
                ? CircleAvatar(backgroundImage: SafeImageProvider(item.image))
                : const CircleAvatar(child: Icon(Icons.person)),
            Positioned(
              right: -5,
              bottom: -4,
              child: Image.asset(
                'assets/lucky/lucky_bag.png',
                width: 24,
                height: 24,
              ),
            ),
          ],
        ),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '$subtitle • ${DateFormat('dd MMM, hh:mm a').format(item.createdAt.toLocal())}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing:
            item.isClaim
                ? Text(
                  '+${item.coins}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w800,
                  ),
                )
                : Image.asset(
                  'assets/lucky/ic_lucky.png',
                  width: 30,
                  height: 30,
                ),
      ),
    );
  }
}
