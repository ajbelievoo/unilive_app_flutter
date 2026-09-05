import 'json_annotation_helper.dart';

class RoomGiftTotalRoot {
  const RoomGiftTotalRoot({this.status = false, this.message, this.data});

  final bool status;
  final String? message;
  final RoomGiftTotal? data;

  factory RoomGiftTotalRoot.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] ?? json['result'];
    return RoomGiftTotalRoot(
      status: parseBool(json['status'] ?? json['success']),
      message: parseString(json['message']),
      data:
          raw is Map
              ? RoomGiftTotal.fromJson(Map<String, dynamic>.from(raw))
              : json.containsKey('totalCoins')
              ? RoomGiftTotal.fromJson(json)
              : null,
    );
  }
}

class RoomGiftTotal {
  const RoomGiftTotal({
    this.totalCoins = 0,
    this.windowStartedAt,
    this.expiresAt,
  });

  final int totalCoins;
  final DateTime? windowStartedAt;
  final DateTime? expiresAt;

  factory RoomGiftTotal.fromJson(Map<String, dynamic> json) => RoomGiftTotal(
    totalCoins: parseInt(json['totalCoins'] ?? json['totalCoin']),
    windowStartedAt: DateTime.tryParse(
      parseString(json['windowStartedAt']) ?? '',
    ),
    expiresAt: DateTime.tryParse(parseString(json['expiresAt']) ?? ''),
  );
}

class LiveRoomAnalytics {
  const LiveRoomAnalytics({
    this.viewerCount = 0,
    this.peakViewerCount = 0,
    this.receivedCoins = 0,
    this.durationSeconds = 0,
    this.watchMinutes = 0,
  });

  final int viewerCount;
  final int peakViewerCount;
  final int receivedCoins;
  final int durationSeconds;
  final int watchMinutes;

  factory LiveRoomAnalytics.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] ?? json['analytics'] ?? json;
    final map = raw is Map ? Map<String, dynamic>.from(raw) : json;
    return LiveRoomAnalytics(
      viewerCount: parseInt(
        map['viewerCount'] ?? map['viewers'] ?? map['currentViewers'],
      ),
      peakViewerCount: parseInt(
        map['peakViewerCount'] ?? map['peakViewers'] ?? map['maxViewers'],
      ),
      receivedCoins: parseInt(
        map['receivedCoins'] ?? map['coins'] ?? map['totalCoins'],
      ),
      durationSeconds: parseInt(
        map['durationSeconds'] ?? map['duration'] ?? map['liveSeconds'],
      ),
      watchMinutes: parseInt(
        map['watchMinutes'] ?? map['watchTimeMinutes'] ?? map['totalMinutes'],
      ),
    );
  }
}

class RoomPollOption {
  const RoomPollOption({
    required this.id,
    required this.text,
    this.voteCount = 0,
  });

  final String id;
  final String text;
  final int voteCount;

  factory RoomPollOption.fromJson(dynamic json, int index) {
    if (json is! Map) {
      return RoomPollOption(id: '$index', text: json?.toString() ?? '');
    }
    final map = Map<String, dynamic>.from(json);
    return RoomPollOption(
      id: parseString(map['id'] ?? map['_id'] ?? map['optionId']) ?? '$index',
      text: parseString(map['text'] ?? map['label'] ?? map['option']) ?? '',
      voteCount:
          map['votes'] is List
              ? (map['votes'] as List).length
              : parseInt(map['voteCount'] ?? map['count'] ?? map['votes']),
    );
  }
}

class RoomPoll {
  const RoomPoll({
    required this.pollId,
    required this.liveStreamingId,
    required this.question,
    required this.options,
    this.startedAt,
    this.endsAt,
    this.hasVoted = false,
    this.selectedOptionId,
    this.ended = false,
  });

  final String pollId;
  final String liveStreamingId;
  final String question;
  final List<RoomPollOption> options;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final bool hasVoted;
  final String? selectedOptionId;
  final bool ended;

  int get totalVotes =>
      options.fold(0, (sum, option) => sum + option.voteCount);

  factory RoomPoll.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] ?? json['poll'] ?? json;
    final map = raw is Map ? Map<String, dynamic>.from(raw) : json;
    final rawOptions = map['options'] ?? map['choices'];
    final options = <RoomPollOption>[];
    if (rawOptions is List) {
      for (var i = 0; i < rawOptions.length; i++) {
        options.add(RoomPollOption.fromJson(rawOptions[i], i));
      }
    }
    return RoomPoll(
      pollId: parseString(map['pollId'] ?? map['_id'] ?? map['id']) ?? '',
      liveStreamingId:
          parseString(
            map['liveStreamingId'] ?? map['roomId'] ?? map['liveId'],
          ) ??
          '',
      question: parseString(map['question'] ?? map['title']) ?? '',
      options: options,
      startedAt: DateTime.tryParse(
        parseString(map['startedAt'] ?? map['startAt'] ?? map['startTime']) ??
            '',
      ),
      endsAt: DateTime.tryParse(
        parseString(map['endsAt'] ?? map['endAt'] ?? map['endTime']) ?? '',
      ),
      hasVoted: parseBool(map['hasVoted'] ?? map['voted']),
      selectedOptionId: parseString(
        map['selectedOptionId'] ?? map['votedOptionId'],
      ),
      ended:
          parseBool(map['ended'] ?? map['isEnded']) ||
          parseString(map['status'])?.toLowerCase() == 'ended',
    );
  }

  RoomPoll copyWith({bool? hasVoted, String? selectedOptionId, bool? ended}) =>
      RoomPoll(
        pollId: pollId,
        liveStreamingId: liveStreamingId,
        question: question,
        options: options,
        startedAt: startedAt,
        endsAt: endsAt,
        hasVoted: hasVoted ?? this.hasVoted,
        selectedOptionId: selectedOptionId ?? this.selectedOptionId,
        ended: ended ?? this.ended,
      );
}
