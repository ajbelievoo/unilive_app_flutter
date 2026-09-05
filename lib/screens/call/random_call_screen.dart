/// Phase 8 implementation: Random call / random match feature.
///
/// Features:
/// - 4 free daily random call cards (for level 1+ hosts/users)
/// - Cards reset daily (stored in SharedPreferences)
/// - Gender filter and audio/video toggle
/// - Socket-based random matching
library random_call;
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/pk_call_models.dart';
import '../../models/user_root.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../utils/log.dart';
import '../call/call_screen.dart';
import 'call_request_screen.dart';
import 'package:belive/widgets/preloader.dart';

class RandomCallScreen extends StatefulWidget {
  const RandomCallScreen({super.key});

  @override
  State<RandomCallScreen> createState() => _RandomCallScreenState();
}

class _RandomCallScreenState extends State<RandomCallScreen> {
  static const String _tag = 'RandomCall';
  static const int _maxFreeCards = 4;
  static const String _prefKey = 'randomCallFreeCards';
  static const String _prefDateKey = 'randomCallFreeCardsDate';

  int _genderFilter = 0;
  int _countryFilter = 0; // 0=any, 1=same country, 2=global
  bool _searching = false;
  bool _audioOnly = false;

  int _freeCards = 0;
  bool _loadingCards = true;

  @override
  void initState() {
    super.initState();
    _loadFreeCards();
    _listenSocketEvents();
  }

  @override
  void dispose() {
    if (_searching) _cancelSearch();
    super.dispose();
  }

  Future<void> _loadFreeCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toString().substring(0, 10);
      final savedDate = prefs.getString(_prefDateKey) ?? '';
      if (savedDate != today) {
        // New day — reset cards
        await prefs.setInt(_prefKey, _maxFreeCards);
        await prefs.setString(_prefDateKey, today);
        _freeCards = _maxFreeCards;
      } else {
        _freeCards = prefs.getInt(_prefKey) ?? _maxFreeCards;
      }
    } catch (e) {
      _freeCards = _maxFreeCards;
    }
    if (mounted) setState(() => _loadingCards = false);
  }

  Future<void> _useFreeCard() async {
    if (_freeCards <= 0) return;
    setState(() => _freeCards--);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, _freeCards);
  }

  void _listenSocketEvents() {
    // Legacy socket match handler — kept as a no-op fallback. The current
    // implementation matches the caller with an online video-call host from
    // the existing host-pool API, which works even when the backend
    // random-call socket events are not ready.
  }

  String _genderLabel() {
    switch (_genderFilter) {
      case 1:
        return 'Male';
      case 2:
        return 'Female';
      default:
        return 'Both';
    }
  }

  int _rateFor() {
    final setting = context.read<SessionManager>().getSetting();
    if (setting == null) return 0;
    return setting.randomCallPrice;
  }

  /// Load candidate users from multiple online pools.
  ///
  /// 1. Video-call hosts (opted-in, has rate).
  /// 2. All live users (`/liveUser?type=All`).
  /// 3. Random PK match as a last resort.
  Future<List<Map<String, dynamic>>> _loadCandidates(User user) async {
    final candidates = <Map<String, dynamic>>[];

    // 1. Preferred: hosts who opted into video calls.
    try {
      final hosts = await ApiService.getVideoCallHosts(
        userId: user.id,
        limit: 100,
      );
      if (hosts.isNotEmpty) {
        Log.d(_tag, 'videoCallHosts returned ${hosts.length}');
        candidates.addAll(hosts);
      }
    } catch (e, s) {
      Log.e(_tag, 'getVideoCallHosts failed', e, s);
    }
    if (candidates.isNotEmpty) return candidates;

    // 2. Fallback: any live streamer / online user from the live list.
    try {
      final userId = user.id ?? '';
      if (userId.isNotEmpty) {
        final res = await ApiService.getLiveUsers(userId: userId, type: 'All', country: 'All', limit: 100);
        if (res.status && res.users.isNotEmpty) {
          Log.d(_tag, 'getLiveUsers returned ${res.users.length}');
          candidates.addAll(
            res.users.where((u) => !u.isFake).map((u) => <String, dynamic>{
              '_id': u.userId,
              'id': u.id,
              'name': u.name,
              'image': u.image,
              'country': u.country,
              // gender / callRate not present in live list; will be derived later.
            }),
          );
        }
      }
    } catch (e, s) {
      Log.e(_tag, 'getLiveUsers failed', e, s);
    }
    if (candidates.isNotEmpty) return candidates;

    // 3. Last fallback: the random-PK match endpoint returns one online user.
    try {
      final userId = user.id ?? '';
      if (userId.isNotEmpty) {
        final res = await ApiService.getRandomPkMatch(userId);
        if (res.status && res.users.isNotEmpty) {
          final u = res.users.first;
          if (!u.isFake) {
            candidates.add(<String, dynamic>{
              '_id': u.userId,
              'id': u.id,
              'name': u.name,
              'image': u.image,
              'country': u.country,
            });
          }
        }
      }
    } catch (e, s) {
      Log.e(_tag, 'getRandomPkMatch failed', e, s);
    }

    return candidates;
  }

  /// Apply gender / region filters. Unknown fields (e.g. from the live-user
  /// fallback) are included so we don't exclude every candidate when the
  /// backend doesn't send full host metadata.
  List<Map<String, dynamic>> _filterHosts(List<Map<String, dynamic>> hosts, User user) {
    final myId = user.id ?? '';
    final myCountry = user.country ?? '';
    final myGender = (user.gender ?? 'male').toLowerCase();

    return hosts.where((h) {
      final hostId = (h['_id'] ?? h['id'])?.toString() ?? '';
      if (hostId.isEmpty || hostId == myId) return false;
      if (h['isOnline'] == false) return false;

      final hostGender = (h['gender']?.toString() ?? '').toLowerCase();

      // Gender filter: 0=Both, 1=Male, 2=Female.
      // Only filter when the host's gender is known.
      if (hostGender.isNotEmpty) {
        if (_genderFilter == 1 && hostGender != 'male') return false;
        if (_genderFilter == 2 && hostGender != 'female') return false;
      }

      // Region filter: 0=Global, 1=My Country, 2=Same Gender.
      if (_countryFilter == 1) {
        final hostCountry = h['country']?.toString() ?? '';
        if (hostCountry.isNotEmpty && hostCountry != myCountry) return false;
      }
      if (_countryFilter == 2) {
        if (hostGender.isNotEmpty && hostGender != myGender) return false;
      }

      return true;
    }).toList();
  }

  String _callTypeFor(Map<String, dynamic> host, User user) {
    final raw = host['gender']?.toString() ?? '';
    if (raw.isNotEmpty) {
      final lower = raw.toLowerCase();
      return '${lower[0].toUpperCase()}${lower.substring(1)}';
    }
    if (_genderFilter == 1) return 'Male';
    if (_genderFilter == 2) return 'Female';
    final userGender = (user.gender ?? 'Male').toLowerCase();
    if (userGender.isEmpty) return 'Male';
    return '${userGender[0].toUpperCase()}${userGender.substring(1)}';
  }

  Future<void> _restoreFreeCard() async {
    setState(() => _freeCards++);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, _freeCards);
  }

  Future<void> _startSearch() async {
    final session = context.read<SessionManager>();
    final user = session.getUser();
    if (user == null) {
      Fluttertoast.showToast(msg: 'Please login first');
      return;
    }

    final rate = _rateFor();
    final hasFreeCard = _freeCards > 0;

    // For a free card we don't enforce a pre-balance check here; the first
    // 60 seconds are free. For paid calls we require at least one minute of
    // the default rate.
    if (!hasFreeCard && rate > 0 && user.coin < rate) {
      Fluttertoast.showToast(msg: 'Insufficient diamonds. Need $rate');
      return;
    }

    setState(() => _searching = true);
    Log.d(_tag, 'search started gender=$_genderLabel country=$_countryFilter audio=$_audioOnly rate=${hasFreeCard ? 0 : rate} freeCard=$hasFreeCard');

    try {
      final candidates = await _loadCandidates(user);
      if (!mounted) return;

      if (!_searching) {
        Log.d(_tag, 'search cancelled while loading candidates');
        return;
      }

      final eligible = _filterHosts(candidates, user);
      if (eligible.isEmpty) {
        Fluttertoast.showToast(msg: 'No online users right now. Try again later.');
        setState(() => _searching = false);
        return;
      }

      final host = eligible[Random().nextInt(eligible.length)];
      final hostId = (host['_id'] ?? host['id'])?.toString() ?? '';
      final hostName = host['name']?.toString() ?? 'Random User';
      final hostImage = host['image']?.toString();
      final hostGender = _callTypeFor(host, user);
      final rawRate = host['callRate'] ?? host['effectiveRate'];
      final hostRate = rawRate is num ? rawRate.toInt() : _rateFor();

      if (hostId.isEmpty) {
        Fluttertoast.showToast(msg: 'No valid match found');
        setState(() => _searching = false);
        return;
      }

      // Consume a free card now. It will be restored if the call is declined
      // or fails before connecting.
      if (hasFreeCard) await _useFreeCard();

      if (!mounted) return;
      if (!_searching) {
        if (hasFreeCard) await _restoreFreeCard();
        return;
      }

      final result = await Navigator.push<IncomingCallData?>(
        context,
        MaterialPageRoute(
          builder: (_) => CallRequestScreen(
            userId2: hostId,
            userName: hostName,
            userImage: hostImage,
            isAudioCall: _audioOnly,
            callRate: hostRate,
            callType: hostGender,
            freeTrialSeconds: hasFreeCard ? 60 : 0,
          ),
        ),
      );

      if (!mounted) return;

      if (result == null) {
        // Declined, cancelled, or API failed.
        if (hasFreeCard) await _restoreFreeCard();
        setState(() => _searching = false);
        return;
      }

      // Call accepted. Free cards give 60 seconds free, then billing at the
      // host rate begins. Non-free cards use the backend's freeTrialSeconds.
      final callData = IncomingCallData(
        callRoomId: result.callRoomId,
        token: result.token,
        channel: result.channel,
        userId2: result.userId2,
        user2Name: result.user2Name,
        user2Image: result.user2Image,
        callByMe: true,
        isAudioCall: _audioOnly,
        isRandomCall: true,
        isFreeCall: result.isFreeCall,
        callRate: result.callRate,
        freeTrialSeconds: hasFreeCard ? 60 : result.freeTrialSeconds,
      );

      setState(() => _searching = false);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveCallScreen(data: callData, isAudioCall: _audioOnly, callByMe: true),
        ),
      );
    } catch (e, s) {
      Log.e(_tag, 'random call match failed', e, s);
      Fluttertoast.showToast(msg: 'Could not start random call');
      if (mounted) setState(() => _searching = false);
    }
  }

  void _cancelSearch() {
    setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
    final rate = _rateFor();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/call/background.webp'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: Text(
                          'Random Call',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                // Scrollable content
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Animated search indicator.
                              SizedBox(
                                height: 200,
                                width: 200,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (_searching) ...[
                                      _ripple(220, Colors.purple.withValues(alpha: 0.1)),
                                      _ripple(180, Colors.purple.withValues(alpha: 0.2)),
                                      _ripple(140, Colors.purple.withValues(alpha: 0.3)),
                                    ],
                                    ClipOval(
                                      child: Image.asset(
                                        'assets/call/globle_conection.webp',
                                        width: 200,
                                        height: 200,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    if (_searching)
                                      const Preloader(color: Colors.white),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _searching ? 'Searching for partner...' : 'Find a random partner',
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searching
                                    ? 'Looking for ${_genderLabel()} ${_audioOnly ? "(audio)" : "(video)"}'
                                    : 'Connect with random ${_genderLabel().toLowerCase()} users',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                              ),
                              const SizedBox(height: 32),
                              // Free cards display
                              if (!_loadingCards && !_searching) ...[
                                _FreeCardsWidget(
                                  freeCards: _freeCards,
                                  maxCards: _maxFreeCards,
                                ),
                                const SizedBox(height: 16),
                              ],
                              // Gender filter.
                              if (!_searching) ...[
                                _segmentedControl(
                                  label: 'Gender',
                                  options: const ['Both', 'Male', 'Female'],
                                  value: _genderFilter,
                                  onChanged: (v) => setState(() => _genderFilter = v),
                                ),
                                const SizedBox(height: 16),
                                // Country filter.
                                _segmentedControl(
                                  label: 'Region',
                                  options: const ['Global', 'My Country', 'Same Gender'],
                                  value: _countryFilter,
                                  onChanged: (v) => setState(() => _countryFilter = v),
                                ),
                                const SizedBox(height: 16),
                                // Call type.
                                _segmentedControl(
                                  label: 'Call Type',
                                  options: const ['Video', 'Audio'],
                                  value: _audioOnly ? 1 : 0,
                                  onChanged: (v) => setState(() => _audioOnly = v == 1),
                                ),
                                const SizedBox(height: 16),
                                if (_freeCards == 0 && rate > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      const Icon(Icons.diamond, color: Colors.amber, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Rate: $rate diamonds / call',
                                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w600),
                                      ),
                                    ]),
                                  ),
                                const SizedBox(height: 24),
                              ],
                              // Action button.
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: FilledButton.icon(
                                  onPressed: _searching ? _cancelSearch : _startSearch,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _searching ? Colors.red : const Color(0xFF7E3FF2),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                  ),
                                  icon: Icon(_searching ? Icons.close : Icons.shuffle),
                                  label: Text(_searching ? 'Cancel' : (_freeCards > 0 ? 'Start Free Call ($_freeCards left)' : 'Start Random Call')),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ripple(double size, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      builder: (_, v, child) => Container(
        width: size * v,
        height: size * v,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }

  Widget _segmentedControl({
    required String label,
    required List<String> options,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: List.generate(options.length, (i) {
          final selected = i == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF7E3FF2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  options[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        })),
      ),
    ]);
  }
}

/// Displays the 4 free daily random call cards as visual indicators.
class _FreeCardsWidget extends StatelessWidget {
  final int freeCards;
  final int maxCards;
  const _FreeCardsWidget({required this.freeCards, required this.maxCards});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const ImageIcon(const AssetImage("assets/gift/official_gift.png"), color: Color(0xFFFFD54F), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Free Call Cards',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ]),
              Text(
                '$freeCards / $maxCards',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(maxCards, (i) {
              final used = i >= freeCards;
              return Container(
                width: 56,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: used ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/call/free_card.webp',
                        fit: BoxFit.cover,
                        opacity: used ? const AlwaysStoppedAnimation<double>(0.35) : null,
                      ),
                      if (used)
                        const Center(
                          child: Icon(Icons.check, color: Colors.white70, size: 24),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            'Resets daily at midnight',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
